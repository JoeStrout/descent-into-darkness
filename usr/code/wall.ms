// This file contains the Wall class and subclasses.

import "miscUtil"
ensureImport "qa"

//---------------------------------------------------------------
// Make a Wall class to represent any vertical surface that
// extends from floor to ceiling.  A wall is represented by two
// ordered points: left and right points on the floor
// (when viewed from the visible side).

Wall = {}
Wall.p = null // 3D floor points, in world coordinates: [left, right]
Wall.imageA = file.loadImage("/usr/content/textures/SewerWallA.png")
Wall.imageB = file.loadImage("/usr/content/textures/SewerWallB.png")
//Wall.imageA = file.loadImage("/usr/content/textures/TestTexture.png")
//Wall.imageB = Wall.imageA
Wall.imageAshort = Wall.imageA.getImage(0, 0, Wall.imageA.width/10, Wall.imageA.height)
Wall.imageBshort = Wall.imageB.getImage(0, 0, Wall.imageB.width/10, Wall.imageB.height)
Wall.sprite = null
Wall.blocksMovement = true
Wall.blocksVision = true
Wall.init = function(left, right, cell)
	qa.assert left.len==2 and right.len==2  // left/right should be 2D floor coordinates
	self.p = [left, right]
	self.tint = Renderer.tintForSurface(left + [0], right + [0], left + [1])
	self.sprite = new Sprite
	if mathUtil.distance(left, right) < 0.25 then
		if rnd < 0.5 then self.sprite.image = self.imageAshort else self.sprite.image = self.imageBshort
	else
		if rnd < 0.5 then self.sprite.image = self.imageA else self.sprite.image = self.imageB
	end if
end function
Wall.make = function(left, right, cell)
	w = new Wall
	w.init left, right, self
	return w
end function

Wall.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	gfx.line left + self.p[0][0]*scaleX, bottom + self.p[0][1]*scaleY,
			 left + self.p[1][0]*scaleX, bottom + self.p[1][1]*scaleY, self.tint
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
	if avgInvD > 1 then
		sp.tint = self.tint
	else
		sp.tint = color.lerp(self.tint, "#000000", (1 - avgInvD)^5)
	end if
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
Doorway.sourceImage = file.loadImage("/usr/content/textures/doorTexture.png")
Doorway.isClosed = true
Doorway.blocksMovement = function; return self.isClosed; end function
Doorway.blocksVision = function; return not self.isClosed; end function

Doorway.prepImages = function
	w = self.sourceImage.width
	h = self.sourceImage.height
	dl = round(w * 0.35)		// door left
	dr = round(w * 0.65)		// door right
	dt = round(h * 0.8)			// door top
	self.leftImage = self.sourceImage.getImage(0, 0, dl, h)
	self.topImage = self.sourceImage.getImage(dl, dt, dr-dl, h-dt)
	self.rightImage = self.sourceImage.getImage(dr, 0, w-dr, h)
	jw = 0.1 * w				// jamb width
	self.leftJambImage = self.sourceImage.getImage(dl-jw, 0, jw, dt)
	self.rightJambImage = self.sourceImage.getImage(dr, 0, jw, dt)
	self.topJambImage = self.sourceImage.getImage(dl, dt, dr-dl, jw)
	self.doorImage = self.sourceImage.getImage(dl, 0, dr-dl, dt)
end function
Doorway.prepImages

Doorway.init = function(left, right, cell)
	super.init left, right, cell

	// Create a mesh for the wall/doorway
	self.wallMesh = new decorations.Mesh
	self.wallMesh.init [cell.col, cell.row, 0]
	left = left + [0]
	right = right + [0]
	leftTop = left.plus([0,0,1])
	rightTop = right.plus([0,0,1])
	leftRound = left.rounded
	rightRound = right.rounded
	doorLeft = mathUtil.lerp2d(leftRound, rightRound, 0.35) + [0]
	doorRight = mathUtil.lerp2d(leftRound, rightRound, 0.65) + [0]
	doorLeftJamb = doorLeft.plus([0,0,0.8])
	doorRightJamb = doorRight.plus([0,0,0.8])	
	doorLeftTop = doorLeft.plus([0,0,1])
	doorRightTop = doorRight.plus([0,0,1])
	back = [sign(left[1] - right[1])*0.1, sign(right[0] - left[0])*0.1, 0]
	halfBack = back.times(0.5)
	self.wallMesh.vertices = [left, right, rightTop, leftTop, 
		doorLeft, doorRight, doorRightJamb, doorLeftJamb, doorRightTop, doorLeftTop,
		doorLeft.plus(back), doorRight.plus(back), 
		doorRightJamb.plus(back), doorLeftJamb.plus(back),
		doorLeft.plus(halfBack), doorRight.plus(halfBack), 
		doorRightJamb.plus(halfBack), doorLeftJamb.plus(halfBack)]
	// (...it's best to draw a picture...)
	self.wallMesh.quads = [
		[4, 10, 13, 7],		// left doorjamb
		[11, 5, 6, 12],		// right doorjamb
		[13, 12, 6, 7],		// top (jamb) of doorway
		[14, 15, 16, 17],	// door itself
		[0, 4, 9, 3],		// wall to left of door
		[5, 1, 2, 8],		// wall to right of door
		[7, 6, 8, 9]]		// wall above doorway
	self.wallMesh.quadTexture = [
		self.leftJambImage,
		self.rightJambImage,
		self.topJambImage,
		self.doorImage,
		self.leftImage,
		self.rightImage,
		self.topImage]
	
	globals.wtf = self
	globals.ww = self.wallMesh
end function

Doorway.render = function(spriteList)
	self.angles = [camera.relativeAngle(self.p[0]), camera.relativeAngle(self.p[1])]
	if self.angles[0] < self.angles[1] then return	// facing away
	if self.angles[1] > camera.halfFovRad or self.angles[0] < -camera.halfFovRad then return // out of view
	self.wallMesh.render spriteList
end function

Doorway.make = function(left, right, cell)
	w = new Doorway
	w.init left, right
		
	return w
end function

Doorway.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	dx = sign(self.p[1][0] - self.p[0][0])
	dy = sign(self.p[1][1] - self.p[0][1])
	if dx then
		a = [round(self.p[0][0]) + 0.25 * dx, self.p[0][1]]
		b = [round(self.p[0][0]) + 0.75 * dx, self.p[1][1]]
	else
		a = [self.p[0][0], round(self.p[0][1]) + 0.25 * dy]
		b = [self.p[0][0], round(self.p[0][1]) + 0.75 * dy]
	end if
	
	gfx.line left + self.p[0][0]*scaleX, bottom + self.p[0][1]*scaleY,
			 left + a[0]*scaleX, bottom + a[1]*scaleY, self.tint
	gfx.line left + b[0]*scaleX, bottom + b[1]*scaleY,
			 left + self.p[1][0]*scaleX, bottom + self.p[1][1]*scaleY, self.tint
end function
