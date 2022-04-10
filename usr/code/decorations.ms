// This file defines various subclasses of microstein.Decoration.
// These are all objects that exist within a Cell of the level,
// and know how to render themselves.  Generally they are static
// (or static-ish) objects, like trees, lamp posts, cobblestones,
// puddles of water, and other such dungeon dressing.

import "miscUtil"
ensureImport "microstein"

//---------------------------------------------------------------
// Billboard: a simple Decoration that always faces the camera.
Billboard = new microstein.Decoration
Billboard.sprite = null  // a Sprite
Billboard.init = function(pos, height, image)
	super.init pos
	self.height = height
	self.sprite = new Sprite
	self.sprite.image = image
end function

Billboard.make = function(imagePath, cell, height=1.6)
	dec = new Billboard
	dec.init [cell.col, cell.row, 0], height
	dec.sprite.image = file.loadImage("/usr/content/" + imagePath)
	cell.decorations.push dec
	return dec
end function

Billboard.render = function(spriteList)
	angle = camera.relativeAngle(self.pos)
	invD = 1 / camera.distance(self.pos)
	if invD < 0 then return
	spriteHeight = self.sprite.image.height
	self.sprite.scale = 300 * self.height * invD / spriteHeight
	baseY = 320 + (-300 + 600 * self.pos[2]) * invD
	self.sprite.x = 480 - tan(angle)*1158
	self.sprite.y = baseY + spriteHeight/2 * self.sprite.scale
	spriteList.push self.sprite
end function

Billboard.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	// ToDo
end function

//---------------------------------------------------------------
// Imposter: a billboard that selects one of several (typically 
// 8 or 16) different renderings of the object as seen from
// different angles, to give the illusion of a 3D object.
Imposter = new Billboard
Imposter.images = null	// list of images to choose from
Imposter.rotation = 0	// angle the object is facing in the world

Imposter.make = function(folderPath, cell, height=1.6)
	dec = new Imposter
	dec.init [cell.col, cell.row, 0], height
	dec.images = []
	parent = "/usr/content/" + folderPath
	for f in file.children(parent)
		img = file.loadImage(file.child(parent, f))
		if img then dec.images.push img
	end for
	cell.decorations.push dec
	return dec
end function

Imposter.render = function(spriteList)
	// get the angle of the object as seen from the camera
	angToCam = atan(camera.pos[1] - self.pos[1], camera.pos[0] - self.pos[0]) * radToDeg
	ang = self.rotation - angToCam
	ang = (ang + 3600) % 360  // (get ang in range 0-360)
	// Now assume our images evenly divide the circle.
	// If we have two images, they'll be front and back, so use
	// image 0 for ang < 90 and ang > 270; image 1 for ang < 90 < 270.
	sections = self.images.len
	idx = round(ang*sections/360) % sections
	text.row=24; print "angToCam:" + round(angToCam) + "; ang:"+round(ang) + "; idx:"+idx + "    "
	self.sprite.image = self.images[idx]
	super.render spriteList
end function


//---------------------------------------------------------------
// FlatDecal: a Decoration that lays flat on the floor or ceiling.
FlatDecal = new microstein.Decoration
FlatDecal.sprite = null  // a Sprite
FlatDecal.init = function(pos, scale)
	super.init pos
	self.sprite = new Sprite
	x = self.pos[0]
	y = self.pos[1]
	h = 0.5 * scale  // (half-width)
	self.cornerPos = [   // world position of each corner
	 [x-h, y-h],[x+h, y-h],[x+h, y+h],[x-h, y+h]]
	self.angles = [0]*4  // camera-relative angle of each corner
	self.screenPos = [[0,0],[0,0],[0,0],[0,0]]
end function

FlatDecal.make = function(imageName, cell, scale=1)
	dec = new FlatDecal
	dec.init [cell.col, cell.row, 0], scale
	dec.sprite.image = file.loadImage("/usr/content/textures/" + imageName)
	cell.decorations.push dec
	return dec
end function

FlatDecal.calcAngles = function
	self.angles[0] = camera.relativeAngle(self.cornerPos[0])
	self.angles[1] = camera.relativeAngle(self.cornerPos[1])
	self.angles[2] = camera.relativeAngle(self.cornerPos[2])
	self.angles[3] = camera.relativeAngle(self.cornerPos[3])
	anglesCopy = self.angles[:]
	anglesCopy.sort
	self.minAngle = anglesCopy[0]
	self.maxAngle = anglesCopy[3]
	self.visible = (self.maxAngle > -camera.halfFovRad and
	  self.minAngle < camera.halfFovRad)
	if self.minAngle < -halfPi and self.maxAngle > halfPi then self.visible = false
end function

FlatDecal.render = function(spriteList)
	self.calcAngles
	if not self.visible then return
	midAngle = (self.minAngle + self.maxAngle)/2
	self.sprite.x = 480 - tan(midAngle)*1158
	self.sprite.y = 320
	h = -300 + 600 * self.pos[2]
	for i in [0,1,2,3]
		// calculate the (inverse) depth and x position of each corner
		invD = 1 / camera.distance(self.cornerPos[i])
		if invD < 0 then return	// bail-out, for now
		self.screenPos[i][0] = 480 - tan(self.angles[i])*1158
		self.screenPos[i][1] = self.sprite.y + h * invD
		// ToDo: deal with points going off the top or bottom of the
		// screen, similar to how we do with walls when they go off
		// the left and right sides.
	end for
	self.sprite.setCorners self.screenPos	
	spriteList.push self.sprite
end function

FlatDecal.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	// ToDo
end function


// We use these classes a lot, so let's just make them global:
globals.Billboard = Billboard
globals.Imposter = Imposter
globals.FlatDecal = FlatDecal
