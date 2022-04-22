// This file defines Decoration and its various subclasses.
// These are all objects that exist within a Cell of the level,
// and know how to render themselves.  Generally they are static
// (or static-ish) objects, like trees, lamp posts, cobblestones,
// puddles of water, and other such dungeon dressing.

import "miscUtil"
ensureImport "mathUtil"

//---------------------------------------------------------------
// Decoration class: something in a cell that knows how to render.
Decoration = {}
Decoration.pos = [0,0]  // position of the CENTER of the decoration
Decoration.init = function(pos)
	self.pos = pos
end function
Decoration.render = function(spriteList)
	// subclasses should override this
end function
Decoration.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	// subclasses should override this
end function
Decoration.die = function
	cell = lvl.cells[self.pos[0]][self.pos[1]]
	cell.decorations.removeVal self
end function

//---------------------------------------------------------------
// Billboard: a simple Decoration that always faces the camera.
Billboard = new Decoration
Billboard.sprite = null  // a Sprite
Billboard.sizeFromBottom = true
Billboard.init = function(pos, height, image)
	super.init pos
	self.height = height
	self.sprite = new Sprite
	self.sprite.image = image
end function

Billboard.make = function(imagePath, cell, height=1.6)
	dec = new Billboard
	dec.init [cell.col + 0.5, cell.row + 0.5, 0], height
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
	self.sprite.x = 480 - tan(angle)*1158
	if self.sizeFromBottom then
		baseY = 320 + (-300 + 600 * self.pos[2]) * invD
		self.sprite.y = baseY + spriteHeight/2 * self.sprite.scale
	else
		self.sprite.y = 320 + (-300 + 600 * self.pos[2]) * invD
	end if
	spriteList.push self.sprite
end function

Billboard.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	x = left + self.pos[0]*scaleX
	y = bottom + self.pos[1]*scaleY
	r = 0.3 * scaleX
	gfx.drawEllipse x-r, y-r, r*2, r*2, color.silver
end function

//---------------------------------------------------------------
// TextFloater: a billboard made from text, that floats upwards
// and fades out after a second or two.  This is typically used
// to show damage or other effects when you hit an entity.
TextFloater = new Billboard
TextFloater.init = function(pos, text, color="#FFFF88")
	disp = display(7)
	disp.clear "#00000000"
	disp.print text, 2, 0, "#000000FF", "large"
	disp.print text, 0, 2, color, "large"
	img = disp.getImage(0, 0, 20*text.len+2, 32)
	super.init pos, 0.1, img

	self.endTime = time + 1
	updatable.all.push self
end function
TextFloater.die = function
	super.die
	updatable.all.removeVal self
end function
TextFloater.make = function(cell, pos, text, color="#FFFF88")
	dec = new TextFloater
	dec.init pos, text, color
	self.startColor = color
	self.endColor = color[:7] + "00"	// (clear alpha)
	cell.decorations.push dec
	return dec
end function
TextFloater.update = function(dt)
	self.pos[2] = self.pos[2] + 0.25*dt
	if time > self.endTime then
		self.die
	else if time > self.endTime - 0.5 then
		self.sprite.tint = color.lerp(self.startColor, self.endColor,
			1 - (self.endTime - time) / 0.5)
	end if
end function

//---------------------------------------------------------------
// Imposter: a billboard that selects one of several (typically 
// 8 or 16) different renderings of the object as seen from
// different angles, to give the illusion of a 3D object.
Imposter = new Billboard
Imposter.images = null	// list of images to choose from
Imposter.rotation = 0	// angle the object is facing in the world

// Make an imposter from a series of images, identified by
// a partial path.  For example, "spider/Spider", which would
// then load spider/Spider-00.png, spider/Spider-01.png, etc.
Imposter.make = function(partialPath, cell, height=1.6)
	dec = new Imposter
	dec.init [cell.col + 0.5, cell.row + 0.5, 0], height
	if partialPath then dec.images = images.loadSeries(partialPath)
	cell.decorations.push dec	
	dec.sprite.localBounds = new Bounds
	dec.sprite.localBounds.width = 100
	dec.sprite.localBounds.height = 60
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
	globals.wtf = self
	idx = round(ang*sections/360) % sections

	if key.available and key.get=="1" then print "angToCam:"+angToCam + "; self.rot:"+self.rotation + "; ang:"+ang + "; idx:" + idx + "/" + sections
	
	self.sprite.image = self.images[idx]
	super.render spriteList
	
	if display(2).mode == displayMode.pixel then
		display(2).drawPoly self.sprite.worldBounds.corners
	end if
end function


//---------------------------------------------------------------
// FlatDecal: a Decoration that lays flat on the floor or ceiling.
FlatDecal = new Decoration
FlatDecal.sprite = null  // a Sprite
FlatDecal.init = function(pos, scale)
	super.init pos
	self.sprite = new Sprite
	self.setScale scale
	self.angles = [0]*4  // camera-relative angle of each corner
	self.screenPos = [[0,0],[0,0],[0,0],[0,0]]
end function

FlatDecal.setScale = function(scale)
	self.scale = scale
	self.updateCorners
end function

FlatDecal.updateCorners = function
	x = self.pos[0]
	y = self.pos[1]
	h = 0.5 * self.scale  // (half-width)
	self.cornerPos = [   // world position of each corner
	 [x-h, y-h],[x+h, y-h],[x+h, y+h],[x-h, y+h]]
end function

FlatDecal.make = function(imageName, cell, scale=0.5)
	dec = new FlatDecal
	dec.init [cell.col + 0.5, cell.row + 0.5, 0], scale
	if imageName then
		dec.sprite.image = file.loadImage("/usr/content/textures/" + imageName)
	end if
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

// Update self.screenPos with the screen position of our corners.
// Return true if the result is visible on screen, false if not.
FlatDecal.calcScreenPos = function
	self.calcAngles
	if not self.visible then return false
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
	return true
end function

FlatDecal.render = function(spriteList)
	if not self.calcScreenPos then return
	self.sprite.setCorners self.screenPos	
	spriteList.push self.sprite
end function

FlatDecal.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	screenCoords = []
	for c in self.cornerPos
		screenCoords.push [left + c[0]*scaleX, bottom + c[1]*scaleY]
	end for
	gfx.fillPoly screenCoords, "#CCCCCC88"
end function

//---------------------------------------------------------------
// Pit: similar to a flat decal, except that we actually render
// a separate little polygon for each side that's away from the
// camera, to give the illusion of a pit in the floor.
Pit = new FlatDecal

Pit.init = function(pos, scale)
	super.init pos, scale
	// We may need up to three sprites to render a pit.
	// So prepare that many now.
	img = Image.create(32, 32, color.white)
	self.sprites = []
	for i in range(3)
		sp = new Sprite
		sp.image = img
		sp.tint = "#AAAAAA" * (i==1) + "#888888" * (i!=1)
		self.sprites.push sp
	end for
end function

Pit.make = function(cell, scale=0.5)
	dec = new Pit
	dec.init [cell.col + 0.5, cell.row + 0.5, 0], scale
	cell.decorations.push dec
	return dec
end function

Pit.render = function(spriteList)
	if not self.calcScreenPos then return
	// For now, just:
	//self.sprites[0].setCorners self.screenPos	
	//spriteList.push self.sprites[0]

//	display(2).drawPoly self.screenPos, color.blue

	// Try to drop a line down from each end point, to intersect
	// the two opposite sides.  This will succeed for any point
	// that is towards the back of the pit (as viewed from the
	// camera), bordering some visible wall of the pit.
	dropPts = [null]*4
	for i in [0,1,2,3]
		pt = self.screenPos[i]
		pOpposite = self.screenPos[(i+2)%4]
		if pOpposite[1] > pt[1] then continue
		pDown = [pt[0], pt[1]-1]	// (one pixel away, straight down)
		b = self.screenPos[(i+1)%4]
		t = mathUtil.lineIntersectProportion(b, pOpposite, pt, pDown)
		if t != null and t > 0 and t < 1 then
			dropPts[i] = mathUtil.lerp2d(b, pOpposite, t)
		else
			b = self.screenPos[(i+3)%4]
			t = mathUtil.lineIntersectProportion(pOpposite, b, pt, pDown)
			if t != null and t > 0 and t < 1 then
				dropPts[i] = mathUtil.lerp2d(pOpposite, b, t)
			end if
		end if
	end for
		
	// Now, loop over each side of the pit.  If either end of the side
	// has a corresponding drop point, then add that to the polygon.
	// If neither does, just skip this side and move on.
	spriteIdx = 0
	for i in [0,1,2,3]
		nexti = (i+1) % 4
		if not dropPts[i] and not dropPts[nexti] then continue
		a = self.screenPos[i]
		b = self.screenPos[nexti]
		minY = min(a[1], b[1])
		if a[0] < b[0] then
			minX = a[0]; maxX = b[0]
		else
			minX = b[0]; maxX = a[0]
		end if
		polyCorners = [a, b]
		if dropPts[nexti] then polyCorners.push dropPts[nexti]
		c = self.screenPos[(i+2)%4]
		if c[1] < minY and c[0] > minX and c[0] < maxX then polyCorners.push c
		if dropPts[i] then polyCorners.push dropPts[i]
		c = self.screenPos[(i+3)%4]
		if c[1] < minY and c[0] > minX and c[0] < maxX then polyCorners.push c

		if polyCorners.len == 3 then polyCorners.push polyCorners[-1]	// (sprites need 4 corners)
		sp = self.sprites[spriteIdx]
		sp.setCorners polyCorners
		ca = self.cornerPos[i]; cb = self.cornerPos[nexti]
		normal = [ca[1]-cb[1], cb[0]-ca[0], 0]
		normalize(normal)
		sp.tint = Renderer.tintForNormal(normal)
		spriteList.push self.sprites[spriteIdx]
	
//		display(2).drawPoly polyCorners, ["#FF0000","#00FF00","#00AAFF"][spriteIdx]
		spriteIdx = spriteIdx + 1
	end for
end function

//---------------------------------------------------------------
// Mesh: a 3D model made from a set of quadrilateral faces.
Mesh = new Decoration
Mesh.vertices = null	// list of 3D points, in world space
Mesh.quads = null		// list of [four vertex indices] per quad
// Texture: may use a single image for all quads, or provide a list
// as long as Mesh.quads, to use a different texture on each one.
Mesh.quadTexture = file.loadImage("/usr/content/textures/TestTexture.png")

Mesh.make = function(cell, alreadyMadeInstance=null)
	if alreadyMadeInstance then mesh = alreadyMadeInstance else mesh = new Mesh
	mesh.init [cell.col, cell.row, 0]
	cell.decorations.push mesh
	return mesh
end function

// Mesh.init: if we have vertices defined (probably from a base class),
// we add the given position to shift them into position.  So your base
// class or pre-init vertices should be in local coordinates.
Mesh.init = function(pos)
	self.pos = pos
	if self.vertices then
		newVerts = self.vertices[:]
		for v in newVerts; v.add pos; end for
		self.vertices = newVerts
	end if
	self.screenVerts = []
	self.sprites = []
	self.quadNormals = []
end function

Mesh.render = function(spriteList)
	// First, calculate the screen position of each vertex
	if not self.screenVerts then self.screenVerts = [null]*self.vertices.len
	for i in range(0, self.vertices.len - 1)
		v = self.vertices[i]
		angle = camera.relativeAngle(v)
		x = 480 - tan(angle)*1158
		invD = 1 / camera.distance(v)
		if invD < 0 then return	// ToDo: deal with this
		y = 320 + (-300 + 600 * v[2]) * invD
		self.screenVerts[i] = [x,y]
	end for
	
	// Then submit a properly stretched sprite for each quad that is facing the camera
	if not self.sprites then
		for i in self.quads.indexes
			q = self.quads[i]
			spr = new Sprite
			if self.quadTexture isa list then
				spr.image = self.quadTexture[i]
			else 
				spr.image = self.quadTexture
			end if
			self.sprites.push spr
			normal = miscUtil.surfaceNormal(self.vertices[q[0]], self.vertices[q[1]],
				self.vertices[q[2]])
			self.quadNormals.push normal
			spr.nearbyTint = Renderer.tintForNormal(normal)
		end for
	end if
	for i in self.quads.indexes
		quad = self.quads[i]
		viewVec = camera.pos.minus(self.vertices[quad[0]])
		normalize viewVec
		cosAng = viewVec.dot(self.quadNormals[i])
		if cosAng < 0 then continue
		corners = [null,null,null,null]
		for j in [0,1,2,3]
			corners[j] = self.screenVerts[quad[j]]
		end for
		spr = self.sprites[i]
		spr.setCorners corners
		spr.tint = Renderer.darkenForDistance(spr.nearbyTint, invD)

		spriteList.push spr
	end for
end function

Mesh.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	for quad in self.quads
		corners = []
		for vidx in quad
			v = self.vertices[vidx]
			corners.push [left + v[0]*scaleX, bottom + v[1]*scaleY]
		end for
		gfx.drawPoly corners, color.silver
	end for
end function

//---------------------------------------------------------------
// A few simple shapes mostly to test the Mesh class.
Pyramid = new Mesh
Pyramid.vertices = [
	[0.1, 0.1, 0],
	[0.9, 0.1, 0],
	[0.9, 0.9, 0],
	[0.1, 0.9, 0],
	[0.5, 0.5, 0.6]]
Pyramid.quads = [ [0,1,4,4], [1,2,4,4], [2,3,4,4], [3,0,4,4] ]
Pyramid.make = function(cell, imageName)
	result = super.make(cell, new Pyramid)
	if imageName then result.quadTexture = file.loadImage("/usr/content/textures/" + imageName)
	return result
end function

Box = new Mesh
Box.vertices = [
	[0.2, 0.3, 0],
	[0.8, 0.3, 0],
	[0.8, 0.7, 0],
	[0.2, 0.7, 0],
	[0.2, 0.3, 0.35],
	[0.8, 0.3, 0.35],
	[0.8, 0.7, 0.35],
	[0.2, 0.7, 0.35]]
Box.quads = [ [0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7], [4,5,6,7] ]
Box.make = function(cell, imageName)
	result = super.make(cell, new Box)
	if imageName then result.quadTexture = file.loadImage("/usr/content/textures/" + imageName)
	return result
end function


// We use these classes a lot, so let's just make them global:
globals.Billboard = Billboard
globals.Imposter = Imposter
globals.FlatDecal = FlatDecal
