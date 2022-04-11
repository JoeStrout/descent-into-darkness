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
ensureImport "wall"
ensureImport "decorations"

Wall = wall.Wall
Decoration = decorations.Decoration

//===============================================================
// WORLD (LEVEL) DEFINITION
//===============================================================

// Cell class: represents one cell of the map.
Cell = {}
// Each cell knows its own row and column.
Cell.col = null
Cell.row = null
// Cell.walls: the walls of this cell.  May be null where there is no wall.
Cell.walls = null  // [N, S, E, W]
// Cell.decorations: a list of Decoration objects in this cell.
// A decoration is any object that knows how to render itself.
Cell.decorations = null
// Cell.entities: a list of entities that are at least partially in this cell.
// Entities are like decorations, except that they generally move around and
// may span more than one cell.
Cell.entities = null
// Positions of our four corners on the floor, in order: SW, SE, NE, NW
Cell.cornerPos = null
// Rendering data.
Cell.angles = null		// cam-relative angle of each corner, in floor-draw order
Cell.minAngle = 0		// minimum camera-relative angle among our corners
Cell.maxAngle = 0		// maximum cam-relative angle
Cell.visible = false	// whether it is within the camera's view 

// Initialize a cell.
Cell.init = function(col, row)
	self.col = col
	self.row = row
	self.walls = [null]*4
	self.decorations = []
	self.entities = []
	self.cornerPos = [[col,row,0], [col+1,row,0], [col+1,row+1,0], [col,row+1,0]]
	self.angles = [0]*4
end function

// Convenience method to add a wall to a cell.
// Note that the wall so added is inset a bit, and will not join neatly
// to form a corner with a neighboring wall (but see Cell.fixCorners).
Cell.addWall = function(dir, wallClass=null)
	if wallClass == null then wallClass = wall.Wall
	w = new wallClass
	h = 0.05  // inset of wall from edge of cell
	if dir == dirS then
		w.init [self.col+1, self.row+h], [self.col, self.row+h], self
	else if dir == dirW then
		w.init [self.col+h, self.row], [self.col+h, self.row+1], self
	else if dir == dirN then
		w.init [self.col, self.row+1-h], [self.col+1, self.row+1-h], self
	else
		w.init [self.col+1-h, self.row+1], [self.col+1-h, self.row], self
	end if

	self.walls[dir] = w
end function

// Method to call on a 2d array of cells, to go through and fix up all
// the corners so that the walls join neatly.
Cell.fixCorners = function(cells)
	maxRow = cells.len - 1
	maxCol = cells[0].len - 1
	for col in cells.indexes
		for row in cells[col].indexes
			w = cells[col][row].walls
			
			// first, fix inner corners (easy)
			if w[dirN] and w[dirE] then
				w[dirN].p[1][0] = w[dirE].p[0][0]
				w[dirE].p[0][1] = w[dirN].p[1][1]
			end if
			if w[dirE] and w[dirS] then
				w[dirE].p[1][1] = w[dirS].p[0][1]
				w[dirS].p[0][0] = w[dirE].p[1][0]
			end if
			if w[dirS] and w[dirW] then
				w[dirS].p[1][0] = w[dirW].p[0][0]
				w[dirW].p[0][1] = w[dirS].p[1][1]
			end if
			if w[dirW] and w[dirN] then
				w[dirW].p[1][1] = w[dirN].p[0][1]
				w[dirN].p[0][0] = w[dirW].p[1][0]
			end if
			
			// then, fix outer corners (trickier)
			for wallDir in range(0,3)
				if not w[wallDir] then continue
				dir2 = (wallDir+1) % 4
				x2 = col + dirDx[wallDir] - dirDx[dir2]
				y2 = row + dirDy[wallDir] - dirDy[dir2]
				if x2 < 0 or x2 > maxCol or y2 < 0 or y2 > maxRow then continue
				w2 = cells[x2][y2].walls
				if not w2[dir2] then continue
				if w[(wallDir+3)%4] then continue
				if cells[x2][y2].walls[(wallDir+2)%4] then continue
				if wallDir == dirN then
					w[wallDir].p[1][0] = w2[dirW].p[0][0]
					w2[dirW].p[0][1] = w[dirN].p[1][1]
				else if wallDir == dirE then
					w[dirE].p[1][1] = w2[dirN].p[0][1]
					w2[dirN].p[0][0] = w[dirE].p[1][0]
				else if wallDir == dirS then
					w[dirS].p[1][0] = w2[dirE].p[0][0]
					w2[dirE].p[0][1] = w[dirS].p[1][1]
				else
					w[dirW].p[1][1] = w2[dirS].p[0][1]
					w2[dirS].p[0][0] = w[dirW].p[1][0]
				end if
			end for
						
			// finally, cap any freestanding walls
			if w[dirE] and col < maxCol and cells[col+1][row].walls[dirW]then
				// vertical (N/S) wall
				if not w[dirS] and row > 0 and
				  not cells[col+1][row-1].walls[dirN] and
				  not cells[col][row-1].walls[dirE] then
					// Create the cap as a freestanding wall,
					// and push it on the decoration list for the cell
					cap = Wall.make(w[dirE].p[1], cells[col+1][row].walls[dirW].p[0])
					cells[col][row].decorations.push cap
					// if we needed to, we could add it to both cells:
					//cells[col+1][row].decorations.push cap				
					// but it seems like it's not necessary
				end if
				if not w[dirN] and row < maxRow and
				  not cells[col+1][row+1].walls[dirS] and
				  not cells[col][row+1].walls[dirE] then
					cap = Wall.make(cells[col+1][row].walls[dirW].p[1], w[dirE].p[0])
					cells[col][row].decorations.push cap
				end if
			end if
			if w[dirN] and row < maxRow and cells[col][row+1].walls[dirS] then
				// vertical (E/W) wall
				if not w[dirW] and col > 0 and
				  not cells[col-1][row+1].walls[dirE] and
				  not cells[col-1][row].walls[dirN] then
					cap = Wall.make(cells[col][row+1].walls[dirS].p[1], w[dirN].p[0])
					cells[col][row].decorations.push cap
				end if
				if not w[dirE] and col < maxCol and
				  not cells[col+1][row+1].walls[dirW] and
				  not cells[col+1][row].walls[dirN] then
					cap = Wall.make(w[dirN].p[1], cells[col][row+1].walls[dirS].p[0])
					cells[col][row].decorations.push cap
				end if				
			end if

		end for
	end for
end function


// Calculate the camera-relative angles of the four corners of this cell,
// along with our min/max angles, and whether we are possibly visible.
Cell.calcAngles = function(containsCamera=false)
	self.angles[0] = camera.relativeAngle(self.cornerPos[0])
	self.angles[1] = camera.relativeAngle(self.cornerPos[1])
	self.angles[2] = camera.relativeAngle(self.cornerPos[2])
	self.angles[3] = camera.relativeAngle(self.cornerPos[3])
	anglesCopy = self.angles[:]
	anglesCopy.sort
	self.minAngle = anglesCopy[0]
	self.maxAngle = anglesCopy[3]
		
	if containsCamera then
		self.visible = true
		return
	end if
	
	angSpan = self.maxAngle - self.minAngle
	if angSpan > pi then		// behind us
//		print "Cell " +self.col+","+self.row + " is behind us"
		self.visible = false
	else
		minAng = camera.angleRad - camera.halfFovRad	// ToDo: cache this
		maxAng = camera.angleRad + camera.halfFovRad
		if maxAng < minAng or minAng > maxAng then
//			print "Cell " +self.col+","+self.row + " is out of view"
			self.visible = false
		else if camera.distance(self.cornerPos[0]) > 15 then
			// too far
			self.visible = false
		else
			self.visible = true
		end if
	end if
end function

// Write the visible walls of this cell to the given depth buffer.
// Return whether we found any spots in the depth buffer that we 
// could actually write to (i.e., not occluded by something closer).
Cell.writeToDepthBuffer = function(depthBuf)
	actuallyVisible = false
	for wallIdx in [0,1,2,3]		
		nextIdx = (wallIdx+1) % 4
		angLeft = self.angles[nextIdx]
		angRight = self.angles[wallIdx]
		if angRight > camera.halfFovRad or angLeft < -camera.halfFovRad then continue
		x0 = round(camera.screenX(angLeft))
		if x0 < 0 then x0 = 0
		x1 = round(camera.screenX(angRight))
		if x1 > 959 then x1 = 959
		if x0 > x1 then continue
		writeIt = (self.walls[wallIdx] != null and self.walls[wallIdx].blocksVision)
		for x in range(x0, x1)
			if not depthBuf[x] then
				actuallyVisible = true
				if writeIt then depthBuf[x] = true else break
			end if
		end for
	end for
	return actuallyVisible
end function

// Push the visible neighbors of this cell onto the given to-do list
// (but only if they don't already have the toDo flag set; and then 
// set it, so we never push the same cell twice in one render cycle).
Cell.pushVisibleNeighbors = function(cellGrid, toDoList)
	for wallIdx in [0,1,2,3]
		// The wall is visible (facing the camera) if its first angle
		// is greater than (?) the second.
		nextIdx = (wallIdx+1) % 4
		if self.angles[wallIdx] < self.angles[(wallIdx+1) % 4] then
			// A Wall is opaque if its has blocksVision == true.
			// So, the neighbor here is visible if wall == null
			// or not wall.blocksVision.
			if self.walls[wallIdx] == null or not self.walls[wallIdx].blocksVision then
				nx = self.col + dirDx[wallIdx]
				ny = self.row + dirDy[wallIdx]
//				print "In direction " + wallIdx + " is cell " + nx + "," + ny
				if nx >= 0 and ny >= 0 and 
				  nx < cellGrid.len and ny < cellGrid[0].len and
				  not cellGrid[nx][ny].toDo then
					cellGrid[nx][ny].toDo = true
					toDoList.push cellGrid[nx][ny]
				end if
			else
//				print "Wall " + wallIdx + " is opaque"
			end if
		else
//			print "Wall " + wallIdx + " has bad angles"
		end if
	end for
end function	

// Build and return a 2D array of initialized cells (i.e. a blank map).
Cell.make2dArray = function(columns, rows)
	result = list.init2d(columns, rows)
	for col in range(0, columns-1)
		for row in range(0, rows-1)
			c = new Cell
			c.init col, row
			result[col][row] = c
		end for
	end for
	return result
end function

hack=0
Cell.render = function(spriteList)
	// draw each wall
	for w in self.walls
		if w then w.render spriteList
	end for
	for dec in self.decorations
		dec.render spriteList
	end for
end function

Cell.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	if self.hasIndex("rock") and self.rock then
		gfx.fillRect left + self.col*scaleX, bottom + self.row * scaleY, 
			  scaleX-1, scaleY-1, color.gray
	else
		gfx.setPixel left + self.col*scaleX, bottom + self.row * scaleY, color.gray
	end if
	for w in self.walls
		if not w then continue
		w.drawInMap left, bottom, scaleX, scaleY
	end for
	for d in self.decorations
		d.drawInMap left, bottom, scaleX, scaleY
	end for
end function

//---------------------------------------------------------------
// Entity class: represents things that can move around
// in the game, and always faces the camera directly.
Entity = new Sprite
Entity.pos = [0,0]
Entity.calcAngle = function
	self.angle = camera.relativeAngle(self.pos)
	self.invD = 1 / camera.distance(self.pos)
	self.visible = (self.angle < camera.halfFovRad and 
	  self.angle > -camera.halfFovRad)
end function
Entity.positionSprite = function
	self.x = 480 - tan(self.angle)*1158  // (1158 ~= 480 / tan(halfFovRad))
	self.y = 320
	self.scale = 5 * self.invD
end function
Entity.pushSprite = function
	self.positionSprite
	display(4).sprites.push self
end function

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

Renderer.light = [0.4, 0.6, -1]
normalize Renderer.light

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
