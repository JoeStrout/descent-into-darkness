// This file contains the Wall class and subclasses.

import "miscUtil"
ensureImport "qa"
ensureImport "renderer"

//---------------------------------------------------------------
// Make a Wall class to represent any vertical surface that
// extends from floor to ceiling.  A wall is represented by two
// ordered points: left and right points on the floor
// (when viewed from the visible side).

globals.Wall = {}
Wall.p = null // 2D floor points, in world coordinates: [left, right]
Wall.imageA = file.loadImage("/usr/content/textures/SewerWallA.png")
Wall.imageB = file.loadImage("/usr/content/textures/SewerWallB.png")
Wall.alts = [file.loadImage("/usr/content/textures/SewerWallAlt.png")]
Wall.imageAshort = Wall.imageA.getImage(0, 0, Wall.imageA.width/10, Wall.imageA.height)
Wall.imageBshort = Wall.imageB.getImage(0, 0, Wall.imageB.width/10, Wall.imageB.height)
Wall.sprite = null
Wall.blocksMovement = true
Wall.blocksVision = true
Wall.blocksSpell = true
Wall.init = function(left, right, cell)
	qa.assert left.len==2 and right.len==2  // left/right should be 2D floor coordinates
	self.p = [left, right]
	self.tint = renderer.Renderer.tintForSurface(left + [0], right + [0], left + [1])
	self.sprite = new Sprite
	if mathUtil.distance(left, right) < 0.25 then
		if rnd < 0.5 then self.sprite.image = self.imageAshort else self.sprite.image = self.imageBshort
	else
		if rnd < 0.5 then self.sprite.image = self.imageA else self.sprite.image = self.imageB
		if self.alts and rnd < 0.1 then self.sprite.image = self.alts.any
	end if
end function
Wall.make = function(left, right, cell)
	w = new Wall
	w.init left, right, cell
	return w
end function

Wall.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	gfx.line left + self.p[0][0]*scaleX, bottom + self.p[0][1]*scaleY,
			 left + self.p[1][0]*scaleX, bottom + self.p[1][1]*scaleY,
			 "#444444", 3
end function

// Call this method when a wall extends beyond the left end of the screen.
// Give it a reference point somewhere on the screen (at refScreenX), and
// the corresponding point on the wall in world coordinates.  This method
// will then set self.x0 and self.invD0 so that the wall looks correct at
// the edge of the screen (by extrapolating way beyond it as needed).
Wall.extrapolateOnLeft = function(refScreenX, refWallPt)
	// First, calculate t (distance along wall from right to left)
	// and inverse-distance of where the wall intersects left
	// edge of screen, from the wall reference point.
	angRad = camera.angleRad + camera.halfFovRad // angle at screen edge
	screenEdgeWorld = [camera.pos[0] + cos(angRad)*10,
	   camera.pos[1] + sin(angRad)*10]  // a world position at screen edge
	t = mathUtil.lineIntersectProportion(refWallPt, self.p[0],
	  camera.pos, screenEdgeWorld)  // t along wall (ref->0) at screen edge
	posCut = mathUtil.lerp2d(refWallPt, self.p[0], t)  // wall pos at screen edge
	invDcut = 1 / camera.distance(posCut)  // invD at screen edge
	// Now we know all about the point on the wall at the edge
	// of the screen, extrapolate to find a proper x0 and invD0.
	self.x0 = refScreenX - refScreenX * (1/t)
	refInvD1 = 1 / camera.distance(refWallPt)
	self.invD0 = refInvD1 + (invDcut - refInvD1) * (1/t)
end function

// Call this method when a wall extends beyond the right end of the screen.
// Give it a reference point somewhere on the screen (at refScreenX), and
// the corresponding point on the wall in world coordinates.  This method
// will then set self.x1 and self.invD1 so that the wall looks correct at
// the edge of the screen (by extrapolating way beyond it as needed).
Wall.extrapolateOnRight = function(refScreenX, refWallPt)
	// First, calculate t (distance along wall from ref point to right)
	// and inverse-distance of where the wall intersects right
	// edge of screen.
	angRad = camera.angleRad - camera.halfFovRad // angle at screen edge
	screenEdgeWorld = [camera.pos[0] + cos(angRad)*10,
	   camera.pos[1] + sin(angRad)*10]  // a world position at screen edge
	t = mathUtil.lineIntersectProportion(refWallPt, self.p[1],
	  camera.pos, screenEdgeWorld)  // t along wall (0->1) at screen edge
	posCut = mathUtil.lerp2d(refWallPt, self.p[1], t)  // wall pos at screen edge
	invDcut = 1 / camera.distance(posCut)  // invD of wall
	// Now we know all about the point on the wall at the edge
	// of the screen, extrapolate to find a proper x1 and invD1.
	self.x1 = refScreenX + (960 - refScreenX) * (1/t)
	refInvD1 = 1 / camera.distance(refWallPt)
	self.invD1 = refInvD1 + (invDcut - refInvD1) * (1/t)		
end function


Wall.positionSprite = function
	// Assumes that calcAngles has already been called.
	// Find the start and end screen column.
	self.x0 = 480 - tan(self.angles[0])*1158  // (1158 ~= 480 / tan(halfFovRad))
	self.x1 = 480 - tan(self.angles[1])*1158
	
	cutOnLeft = self.angles[0] > camera.halfFovRad
	cutOnRight = self.angles[1] < -camera.halfFovRad
	if cutOnLeft and cutOnRight then
		// This wall is cut off on both sides.  Dang, what a pain.
		// Let's find a point in the wall at the middle of the screen.
		screenMidWorld = [camera.pos[0] + cos(camera.angleRad)*10,
		   camera.pos[1] + sin(camera.angleRad)*10]
		t = mathUtil.lineIntersectProportion(self.p[0], self.p[1],
		  camera.pos, screenMidWorld)  // t along wall (0->1) at screen midpoint
		posMid = mathUtil.lerp2d(self.p[0], self.p[1], t)  // wall pos at screen mid
		// OK, now we know where the wall is in the center of the screen.
		// Let's use this, and the intersection of each screen edge,
		// to compute where the off-screen wall ends should be.
		self.extrapolateOnLeft 480, posMid
		self.extrapolateOnRight 480, posMid
	else if cutOnLeft then
		// This wall is cut off on the left.  Let's compute exactly
		// where on the wall that screen intersection happens, and
		// deal with just the visible part.
		self.invD1 = 1 / camera.distance(self.p[1])
		self.extrapolateOnLeft self.x1, self.p[1]
	else if cutOnRight then
		self.invD0 = 1 / camera.distance(self.p[0])
		self.extrapolateOnRight self.x0, self.p[0]
	else
		// Easy case: wall is entirely on screen.
		self.invD0 = 1 / camera.distance(self.p[0])
		self.invD1 = 1 / camera.distance(self.p[1])
	end if
	
	self.x0 = round(self.x0)
	self.x1 = round(self.x1)

	sp = self.sprite
	sp.x = (self.x0 + self.x1)/2
	sp.y = 320
	h0 = 300 * self.invD0
	h1 = 300 * self.invD1
	sp.setCorners [[self.x0, sp.y-h0], [self.x1, sp.y-h1], 
	  [self.x1, sp.y+h1], [self.x0, sp.y+h0]]
	  
	// darken the sprite in the distance
	avgInvD = (self.invD0 + self.invD1)*0.5
	sp.tint = Renderer.darkenForDistance(self.tint, avgInvD)
	sp.avgInvD = avgInvD
end function

Wall.render = function(spriteList)
	self.angles = [camera.relativeAngle(self.p[0]), camera.relativeAngle(self.p[1])]
	if self.angles[0] < self.angles[1] then return	// facing away
	if self.angles[1] > camera.halfFovRad or self.angles[0] < -camera.halfFovRad then return // out of view
	self.positionSprite
	spriteList.push self.sprite
end function

//---------------------------------------------------------------

Doorway = new Wall
Doorway.width = 0.5		// (proportion of the total wall width)
Doorway.height = 0.8	// (same)
Doorway.doorImage = file.loadImage("/usr/content/textures/doorTexture.png")
Doorway.isClosed = false
Doorway.blocksMovement = function; return self.isClosed; end function
Doorway.blocksVision = function; return self.isClosed; end function
Doorway.type = -1		// one of the constants below

// Constants for what type of mesh the doorway should use:
Doorway.typeEmpty = 0
Doorway.typeClosedBack = 1
Doorway.typeClosedFront = 2
Doorway.typeOpenBack = 3
Doorway.typeOpenFront = 4

Doorway.blocksSpell = function; return self.isClosed; end function

Doorway.prepImages = function
	// get images for the wall surrounding the doorway
	wallImg = self.imageA
	w = wallImg.width; h = wallImg.height
	dl = round(w * 0.35)		// door left
	dr = round(w * 0.65)		// door right
	dt = round(h * 0.8)			// door top
	jw = round(w * 0.1)			// jamb width
	self.leftImage = wallImg.getImage(0, 0, dl, h)
	self.topImage = wallImg.getImage(dl, dt, dr-dl, h-dt)
	self.rightImage = wallImg.getImage(dr, 0, w-dr, h)
	self.leftJambImage = wallImg.getImage(dl, 0, jw, dt)
	self.rightJambImage = wallImg.getImage(dr-jw, 0, jw, dt)
	self.topJambImage = wallImg.getImage(dl, dt-jw, dr-dl, jw)
		
	// now get images for the door itself
	doorImg = self.doorImage
	w = doorImg.width; h = doorImg.height
	dw = round(w * 0.3)		// door width
	ew = round(w * 0.025)	// edge (of the door) width
	self.doorClosedFront = doorImg.getImage(0, 0, dw, h)
	self.doorLeftEdge = doorImg.getImage(dw, 0, ew, h)
	self.doorOpenFront = doorImg.getImage(dw+ew, 0, dw, h)
	self.doorClosedBack = self.doorOpenFront
	self.doorRightEdge = doorImg.getImage(dw+ew+dw, 0, ew, h)
end function
Doorway.prepImages

Doorway.cell = null			// (needed for toggling the door)
Doorway.otherSide = function
	if not self.cell then return null
	myDir = self.cell.walls.indexOf(self)
	if myDir == null then return null
	otherDir = (myDir + 2) % 4
	otherCell = lvl.cells[self.cell.col + dirDx[myDir]][self.cell.row + dirDy[myDir]]
	otherWall = otherCell.walls[otherDir]
	if not otherWall isa Doorway then return null
	return otherWall
end function

Doorway.createMesh = function(meshType, doorOnly=false)
	mesh = new decorations.Mesh
	mesh.init [(self.p[0][0] + self.p[1][0])/2, (self.p[0][1] + self.p[1][1])/2, 0.5]
	
	openDoorAngle = 10
	
	// find the main reference points we will always need
	left = self.p[0] + [0]
	right = self.p[1] + [0]
	leftTop = left.plus([0,0,1])
	rightTop = right.plus([0,0,1])
	// We base our door position on the *full* extent of the wall,
	// ignoring minor adjustments at the end for corner joins.  To
	// do that, we round whichever dimension has the greatest span.
	leftRound = left[:]; rightRound = right[:]
	if abs(left[0]-right[0]) > abs(left[1] - right[1]) then
		leftRound[0] = round(left[0])
		rightRound[0] = round(right[0])
	else
		leftRound[1] = round(left[1])
		rightRound[1] = round(right[1])
	end if
		
	doorLeft = mathUtil.lerp2d(leftRound, rightRound, 0.35) + [0]
	doorRight = mathUtil.lerp2d(leftRound, rightRound, 0.65) + [0]
	doorLeftJamb = doorLeft.plus([0,0,0.8])
	doorRightJamb = doorRight.plus([0,0,0.8])	
	doorLeftTop = doorLeft.plus([0,0,1])
	doorRightTop = doorRight.plus([0,0,1])
	back = [sign(left[1] - right[1])*0.1, sign(right[0] - left[0])*0.1, 0]
	halfBack = back.times(0.5)
	
	if meshType == Doorway.typeOpenFront and doorOnly then
		// create a mesh for JUST the door, to be used as a cell decoration
		dx = sign(right[0] - left[0])
		dy = sign(right[1] - left[1])
		edgeVec = [0.025*dy, -0.025*dx, 0].rotated(openDoorAngle)
		doorVec = [-0.25*dx, -0.25*dy, 0].rotated(openDoorAngle)
		mesh.vertices = [doorLeft, doorLeftJamb,
			doorLeft.plus(doorVec).plus(edgeVec), doorLeft.plus(edgeVec),
			doorLeftJamb.plus(edgeVec), doorLeftJamb.plus(doorVec).plus(edgeVec),
			doorLeft.plus(doorVec), doorLeftJamb.plus(doorVec)]
		mesh.quads = [
			[3, 0, 1, 4],		// right edge of door
			[6, 2, 5, 7],		// left edge of door
			[2, 3, 4, 5]]		// open door as seen from front
		mesh.quadTexture = [
			self.doorRightEdge,
			self.doorLeftEdge,
			self.doorOpenFront]
		return mesh
	end if
	
	// start with the vertices that always apply, even on an empty doorway
	mesh.vertices = [left, right, rightTop, leftTop, 
		doorLeft, doorRight, doorRightJamb, doorLeftJamb, doorRightTop, doorLeftTop,
		doorLeft.plus(back), doorRight.plus(back), 
		doorRightJamb.plus(back), doorLeftJamb.plus(back)]
	// And the quads for the inside (jamb) of the doorway, which are always drawn first
	// (...it's best to draw a picture...)
	mesh.quads = [
		[4, 10, 13, 7],		// left doorjamb
		[11, 5, 6, 12],		// right doorjamb
		[13, 12, 6, 7]]		// top (jamb) of doorway
	mesh.quadTexture = [
		self.leftJambImage,
		self.rightJambImage,
		self.topJambImage]
		
	// then, add the door and front walls, depending on the specified mesh type
	if meshType == Doorway.typeEmpty or meshType == Doorway.typeOpenFront then
		// Note: with typeOpenFront, we create only the empty doorway here;
		// call again with doorOnly=true to get the separate door mesh.
		mesh.quads.push [0, 4, 9, 3]		// wall to left of door
		mesh.quadTexture.push self.leftImage
		mesh.quads.push [7, 6, 8, 9]		// wall above doorway
		mesh.quadTexture.push self.topImage
	else if meshType == Doorway.typeClosedBack then
		mesh.quads.push [10, 11, 12, 13]	// back side of door, recessed
		mesh.quadTexture.push self.doorClosedBack
		mesh.quads.push [0, 4, 9, 3]		// wall to left of door
		mesh.quadTexture.push self.leftImage
		mesh.quads.push [7, 6, 8, 9]		// wall above doorway
		mesh.quadTexture.push self.topImage
	else if meshType == Doorway.typeClosedFront then
		// don't actually need the jambs in this case...
		mesh.vertices = mesh.vertices[:10]
		mesh.quads = []; mesh.quadTexture = []
		mesh.quads.push [0, 4, 9, 3]		// wall to left of door
		mesh.quadTexture.push self.leftImage
		mesh.quads.push [7, 6, 8, 9]		// wall above doorway
		mesh.quadTexture.push self.topImage
		mesh.quads.push [4, 5, 6, 7]		// front side of door, flush
		mesh.quadTexture.push self.doorClosedFront
	else if meshType == Doorway.typeOpenBack then
		dx = sign(right[0] - left[0])
		dy = sign(right[1] - left[1])
		edgeVec = [-0.025*dy, 0.025*dx, 0].rotated(openDoorAngle)
		mesh.vertices.push doorRight.plus(back).plus(edgeVec)
		mesh.vertices.push doorRightJamb.plus(back).plus(edgeVec)
		mesh.quads.push [14, 11, 12, 15]	// right edge of door, seen from back side
		mesh.quadTexture.push self.doorRightEdge
		mesh.quads.push [0, 4, 9, 3]		// wall to left of door
		mesh.quadTexture.push self.leftImage
		mesh.quads.push [7, 6, 8, 9]		// wall above doorway
		mesh.quadTexture.push self.topImage
	else
		qa.abort "Unknown meshType " + meshType
	end if

	mesh.quads.push [5, 1, 2, 8]		// wall to right of door
	mesh.quadTexture.push self.rightImage
	return mesh
end function

Doorway.setType = function(type)
	if type == self.type then return
	if self.type == Doorway.typeOpenFront then
		self.cell.decorations.removeVal self.doorMesh
	end if
	
	self.type = type
	self.mesh = self.createMesh(type)
	if type == Doorway.typeOpenFront then
		self.doorMesh = self.createMesh(type, true)
		self.cell.decorations.insert 0, self.doorMesh
	end if
	
	self.isClosed = (type == Doorway.typeClosedBack or type == Doorway.typeClosedFront)
end function

Doorway.init = function(left, right, cell, type = 0)
	super.init left, right, cell
	self.cell = cell
	self.setType type
end function

Doorway.otherSideType = function(doorType)
	if doorType == Doorway.typeOpenFront then return Doorway.typeOpenBack
	if doorType == Doorway.typeClosedFront then return Doorway.typeClosedBack
	if doorType == Doorway.typeOpenBack then return Doorway.typeOpenFront
	if doorType == Doorway.typeClosedBack then return Doorway.typeClosedFront
	return Doorway.typeEmpty
end function
	
Doorway.toggledType = function(doorType)
	if doorType == Doorway.typeOpenFront then return Doorway.typeClosedFront
	if doorType == Doorway.typeClosedFront then return Doorway.typeOpenFront
	if doorType == Doorway.typeOpenBack then return Doorway.typeClosedBack
	if doorType == Doorway.typeClosedBack then return Doorway.typeOpenBack
	return Doorway.typeEmpty
end function
	
Doorway.toggleDoor = function(andOtherSide = true)
	otherDoor = null
	if andOtherSide then otherDoor = self.otherSide
	
	self.setType Doorway.toggledType(self.type)
	if otherDoor then otherDoor.setType Doorway.otherSideType(self.type)
end function

Doorway.render = function(spriteList)
	self.angles = [camera.relativeAngle(self.p[0]), camera.relativeAngle(self.p[1])]
	if self.angles[0] < self.angles[1] then return	// facing away
	if self.angles[1] > camera.halfFovRad or self.angles[0] < -camera.halfFovRad then return // out of view
	self.mesh.render spriteList
end function

Doorway.make = function(left, right, cell, type = 4)
	w = new Doorway
	w.init left, right, cell, type
	return w
end function

Doorway.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	super.drawInMap left, bottom, scaleX, scaleY
	rp0 = self.p[0].rounded
	rp1 = self.p[1].rounded
	a = mathUtil.lerp2d(rp0, rp1, 0.3)
	b = mathUtil.lerp2d(rp0, rp1, 0.7)
	perp = [b[1] - a[1], a[0] - b[0]]
	normalize perp
	perp.multiplyBy 2
	if self.isClosed then c = "#FF0000" else c = "#00FF00"
	gfx.line left + a[0]*scaleX+perp[0], bottom + a[1]*scaleY+perp[1],
	   left + b[0]*scaleX+perp[0], bottom + b[1]*scaleY+perp[1], c, 2
	gfx.line left + a[0]*scaleX+perp[0], bottom + a[1]*scaleY+perp[1],
	   left + a[0]*scaleX-perp[0], bottom + a[1]*scaleY-perp[1], c, 2
	gfx.line left + b[0]*scaleX-perp[0], bottom + b[1]*scaleY-perp[1],
	   left + b[0]*scaleX+perp[0], bottom + b[1]*scaleY+perp[1], c, 2
	return

	super.drawInMap left, bottom, scaleX, scaleY
	rp0 = self.p[0].rounded
	rp1 = self.p[1].rounded
	a = mathUtil.lerp2d(rp0, rp1, 0.3)
	b = mathUtil.lerp2d(rp0, rp1, 0.7)
	x = min(a[0], b[0]); y = min(a[1], b[1])
	if self.isClosed then c = "#FF0000" else c = "#00FF00"
	gfx.drawRect left + x*scaleX-2, bottom + y*scaleY-2,
		abs(b[0]-a[0])*scaleX+4, abs(b[1]-a[1])*scaleY+4, c, 2
	
//	dx = sign(self.p[1][0] - self.p[0][0])
//	dy = sign(self.p[1][1] - self.p[0][1])
//	if dx then
//		a = [round(self.p[0][0]) + 0.25 * dx, self.p[0][1]]
//		b = [round(self.p[0][0]) + 0.75 * dx, self.p[1][1]]
//	else
//		a = [self.p[0][0], round(self.p[0][1]) + 0.25 * dy]
//		b = [self.p[0][0], round(self.p[0][1]) + 0.75 * dy]
//	end if
//	
//	gfx.line left + self.p[0][0]*scaleX, bottom + self.p[0][1]*scaleY,
//			 left + a[0]*scaleX, bottom + a[1]*scaleY, self.tint
//	gfx.line left + b[0]*scaleX, bottom + b[1]*scaleY,
//			 left + self.p[1][0]*scaleX, bottom + self.p[1][1]*scaleY, self.tint
end function
