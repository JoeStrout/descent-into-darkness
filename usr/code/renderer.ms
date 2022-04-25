// 3D-ish rendering of walls, decorationss, and entities,
// using stretched sprites.

// The loaded level consists of a 2D grid of type Cell.  Each cell
// represents one square area of the level, with up to four walls,
// and any number of decorations and entities.  The walls usually
// block vision (though they may not, if they represent a doorway
// or window or whatever), and this is used to limit how many cells
// are rendered on each frame.

// Coordinate system:
// We'll work mainly in 2D, with map points represented as [x,y].
// (We'll call the vertical dimension Z, often omitted/ignored.)
// 1 unit is the width (and height) of a Cell.  Where
// z matters at all, the floor is normally at 0 and a standard
// ceiling is at 1, though these may be played with a bit for
// a higher/lower ceiling, etc.

import "miscUtil"
import "qa"
import "mathUtil"
import "listUtil"
ensureImport "cell"
ensureImport "wall"
ensureImport "decorations"

Decoration = decorations.Decoration


//===============================================================
// CAMERA/RENDERER DEFINITION
//===============================================================

// Camera: defines the current view point and angle, as well
// as parameters like field of view (fov) and distance limit.
// There is only one camera; this is a global object.
camera = {}
// camera.pos: position of the camera.  Note the z position;
// when this is < 0.5 the ceiling feels high, because the camera
// is less than half the way to the ceiling.  When it is close
// to 1, then the ceiling feels low and cramped.
camera.pos = [2.5, 5.5, 0.6]

// the forward direction, in degrees (-180 to 180) and radians
camera.angle = 45
camera.angleRad = camera.angle * degToRad
// cosine and sine of that angle, since we use these a lot
camera.cosAng = cos(camera.angleRad)
camera.sinAng = sin(camera.angleRad)
// half the horizontal field of view, in degrees (0 to 90) and radians
camera.halfFov = 22.5
camera.halfFovRad = camera.halfFov * degToRad

camera.setAngle = function(degrees)
	self.angle = (degrees + 180) % 360 - 180
	if self.angle < -180 then self.angle = self.angle + 360
	self.angleRad = self.angle * degToRad
	self.cosAng = cos(self.angleRad)
	self.sinAng = sin(self.angleRad)
	if gfx.width > 960 then
		gfx.scrollX = (3840 - 960/45 * self.angle) % gfx.width
	end if
end function	
camera.turn = function(degreesCCW)
	self.setAngle self.angle + degreesCCW
end function
camera.moveForward = function(dist)
	self.pos[0] = self.pos[0] + self.cosAng * dist
	self.pos[1] = self.pos[1] + self.sinAng * dist
end function
camera.moveRight = function(dist)
	self.pos[0] = self.pos[0] + self.sinAng * dist
	self.pos[1] = self.pos[1] - self.cosAng * dist
end function
camera.forwardVec = function
	result = [self.cosAng, self.sinAng, 0]
	// OK, how to get the pitch angle?  We don't *actually* pitch the
	// camera; we just scroll the screen up and down to create that
	// illusion.  So we need some kind of fudge factor here.  For now:
	result[2] = 0.3 * display(4).scrollY / 160
	normalize(result)
	return result
end function

// Calculate the angle (in radians) of the given point, 
// relative to the camera's forward direction.
camera.relativeAngle = function(point)
	ang = (atan(point[1] - self.pos[1], point[0] - self.pos[0]) - 
	   self.angleRad + pi) % twoPi - pi
	if ang < -pi then ang = ang + twoPi
	return ang
end function

// Calculate the screen X position (column) for any camera-relative angle.
camera.screenX = function(camAngRadians)
	return 480 - tan(camAngRadians)*1158  // (1158 ~= 480 / tan(halfFovRad))
end function

// Find the distance of the projected point to the camera.  No, actually,
// find the *projected* distance of the point to the camera *plane*.
// This eliminates the fisheye effect, and is more efficient too.  Neat!
camera.distance = function(point)
	// here is ordinary straight-line distance:
	//return mathUtil.distance(point, self.pos)
	
	// And here is the projected distance
	return (point[0] - self.pos[0]) * self.cosAng +
	       (point[1] - self.pos[1]) * self.sinAng
end function

//---------------------------------------------------------------
// Renderer: holds all the data needed for rendering the scene.
Renderer = {}

Renderer.light = [0.4, 0.6, -1]	// direction of the light
normalize Renderer.light

// Find the color tint (between black and white) that should be applied
// to a surface containing the given three points.
Renderer.tintForSurface = function(ptA, ptB, ptC)
	// Start by finding the normal to the surface.
	normal = crossProduct(ptB.minus(ptA), ptC.minus(ptA))
	normalize normal
	return self.tintForNormal(normal)
end function

// Find the color tint (between black and white) that should be applied
// to a surface with the given normal vector.
Renderer.tintForNormal = function(normal)
	cosAng = normal.dot(self.light)
	if normal[2] < 0 then return color.lerp("#000000", "#666666", abs(cosAng))
	return color.lerp("#666666", "#FFFFFF", abs(cosAng))
end function

// Darken the given tint based on the distance (given as 1/distance)
// from the camera.  Return the new (probably darker) tint.
Renderer.darkenForDistance = function(nearbyTint, invD)
	if invD > 1 then return nearbyTint
	return color.lerp(nearbyTint, "#000000", (1 - invD)^5)
end function

Renderer.cell = null		// a 2D array of Cell

// Our depth buf, after some code evolution, is now really just a set of
// flags indicating whether there is some opaque wall (or whatever) drawn
// in each column of the screen.  It's literally just 960 boolean values;
// as we now analyze the scene in front-to-back order anyway, we don't
// need to keep track of WHAT is drawing in each column, but only whether
// something is there, so we can occlude things further back.
// ToDo: consider whether keeping a set of "occluded intervals" would
// be faster than writing all these boolean values.
Renderer.depthBuf = [false] * 960

Renderer.analyze = function	
	self.depthBuf = [false]*960		// ToDo: check whether a loop to clear would be faster
	
	// Clear all the "toDo" flags.
	for set in self.cell
		for c in set
			c.toDo = false
		end for
	end for
	
	// Start with the cell containing the camera.  Push that onto a
	// list of cells to consider, and then if any of its edges are
	// visible and non-opaque, push the neighboring cells, and so
	// on until we have nothing more to do.  IMPORTANT: do this in
	// breadth-first order, so that we are inherently working in
	// near-to-far order (and so we don't waste time expanding stuff
	// in the distance which is covered by something closer).
	camCell = self.cell[camera.pos[0]][camera.pos[1]]
	toDo = []
	toDo.push camCell
	// As we go, build an ordered list of cells that actually need to render.
	self.cellsToRender = []
	while toDo
		// pull the next to-do item off the front of our list (breadth first)
		cell = toDo.pull
//		print "Considering " + cell.col + ", " + cell.row
		isFirstCell = (cell == camCell)
		// if it's not in view, bail out
		cell.calcAngles
		if not cell.visible and not isFirstCell then continue
		// have the cell write its walls (and maybe even decorations, if it wants)
		// to the depth buffer; note whether it actually succeeded in writing any
		didAppear = cell.writeToDepthBuffer(self.depthBuf)
		// ...if it did not, then the cell is not visible after all, so bail
//		if cell.row==5 and cell.col==5 then print "Cell 5,5 didAppear="+didAppear
		if not didAppear and not isFirstCell then continue
		// otherwise, note that this cell needs to render, and
		// put the neighboring visible cells on our to-do list
		self.cellsToRender.push cell
		cell.pushVisibleNeighbors self.cell, toDo
	end while
end function

// Helper method to stretch a sprite into position provided that
// it is a vertical surface, like a wall, with the given corners
// in 3D world space.
Renderer.stretchVerticalSprite = function(sprite, corners)
	// ToDo (after we've got it working for Wall, and neatened up a bit)
end function

Renderer.render = function
	// Assume that Renderer.analyze has already been called.
	// So, all we have to do is render the cells which need to render.
	// They are ordered with the closest cells at the front, so we'll
	// iterate over this backwards, putting the furthest cells first
	// in the sprite list.
	spriteList = []
	if self.cellsToRender then
		for i in range(self.cellsToRender.len - 1)
			self.cellsToRender[i].render spriteList
		end for
	end if
	display(4).sprites = spriteList
end function

//===============================================================
// Utility methods
//===============================================================
//
// Make some helper methods to generate sets of walls in Renderer.cell.

makeLongWall = function(leftmost, rightmost, dir)
	cells = Renderer.cell
	if leftmost[0] == rightmost[0] then
		x = leftmost[0]
		// vertical wall at x
		if leftmost[1] < rightmost[1] then
			for y in range(leftmost[1], rightmost[1]-1)
				cells[x][y].addWall dir
			end for
		else
			for y in range(rightmost[1], leftmost[1]-1)
				cells[x][y].addWall dir
			end for
		end if
	else if leftmost[1] == rightmost[1] then
		y = leftmost[1]
		// horizontal wall at y
		if leftmost[0] < rightmost[0] then
			for x in range(leftmost[0], rightmost[0]-1)
				cells[x][y].addWall dir
			end for
		else
			for x in range(rightmost[0], leftmost[0]-1)
				cells[x][y].addWall dir
			end for
		end if
	else
		qa.fail "walls must differ in only one dimension"
	end if
end function

// Make a box with the walls facing inward (e.g., for
// the outer walls of the map)
makeInwardBox = function(left, bottom, width, height)
	top = bottom + height
	right = left + width
	makeLongWall [left,bottom], [left,top], dirW
	makeLongWall [left,top-1], [right,top-1], dirN
	makeLongWall [right-1,top], [right-1,bottom], dirE
	makeLongWall [right,bottom], [left,bottom], dirS
end function

// Make a box with the walls facing outward (a column or obstacle).
makeOutwardBox = function(left, bottom, width, height)
	top = bottom + height
	right = left + width
	makeLongWall [left-1,top], [left-1,bottom], dirE
	makeLongWall [right,top], [left,top], dirS
	makeLongWall [right,bottom], [right,top], dirW
	makeLongWall [left,bottom-1], [right,bottom-1], dirN
end function


rerender = function
	camera.pos[0] = mathUtil.clamp(camera.pos[0], 0.25, Renderer.cell.len-0.25)
	camera.pos[1] = mathUtil.clamp(camera.pos[1], 0.25, Renderer.cell[0].len-0.25)
	Renderer.analyze
	yield
	display(2).clear color.clear; display(2).scrollY = display(4).scrollY
	Renderer.render
end function

makeDemoMap = function
	// First let's define the map.
	Renderer.cell = Cell.make2dArray(11, 11)
	makeInwardBox(0, 0, 10, 10)
	makeOutwardBox(2, 3, 3, 2)
	makeOutwardBox(7, 6, 2, 2)
	makeOutwardBox(5, 8, 1, 1)
	
	// Let's also add some free-standing walls...
	Renderer.cell[2][9].addWall dirE
	Renderer.cell[3][9].addWall dirW

	Renderer.cell[2][0].addWall dirE
	Renderer.cell[3][0].addWall dirW

	Renderer.cell[0][4].addWall dirN
	Renderer.cell[0][5].addWall dirS

	Renderer.cell[9][4].addWall dirN
	Renderer.cell[9][5].addWall dirS

	
	Cell.fixCorners Renderer.cell
	
	//	// And throw in a Wumpus.
	//	wumpus = new Entity
	//	wumpus.image = findImage("pics/Wumpus.png")
	//	wumpus.pos = [6.5, 3.5, 0.5]
	//	Renderer.entities.push wumpus
	
	// And some decorations
	Decoration.make "floorCobble1.png", Renderer.cell[6][3], 0.25 + 0.5*rnd
	Decoration.make "floorCobble2.png", Renderer.cell[4][2], 0.25 + 0.5*rnd
	Decoration.make "floorCobble3.png", Renderer.cell[7][6], 0.25 + 0.5*rnd
end function

demo = function(makeMap=false)
	if makeMap then makeDemoMap
	clear

	gfx.fillRect 0, 0, 960, 320, color.silver	// floor
	gfx.fillRect 0, 320, 960, 320, color.gray	// ceiling
	
	rerender
	//exit
	
	fpsStartTime = time
	fpsFrameCount = 0
	while true
		needRender = true
		alt = key.pressed("left alt") or key.pressed("right alt")
		if key.pressed("escape") then
			break
		else if key.pressed("left") then
			if alt then camera.moveRight -0.1 else camera.turn 4
		else if key.pressed("right") then
			if alt then camera.moveRight 0.1 else camera.turn -4
		else if key.pressed("up") then
			camera.moveForward 0.1
		else if key.pressed("down") then
			camera.moveForward -0.1
		else
			needRender = false
		end if
		if needRender then rerender else yield
		fpsFrameCount = fpsFrameCount + 1
		if fpsFrameCount > 10 then
			fps = fpsFrameCount / (time - fpsStartTime)
			text.row = 25; text.column = 58; print "FPS:" + round(fps, 2)
			fpsStartTime = time
			fpsFrameCount = 0
		end if
	end while
	
	key.clear
end function

if locals == globals then demo true
