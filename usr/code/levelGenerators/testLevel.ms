// This is a Level subclass that we use only for testing; it is never
// intended to go into the final game.  Hack away!

import "miscUtil"
ensureImport "level"
ensureImport "entities"

TestDec = new FlatDecal
TestDec.make = function(cell, scale=1)
	dec = new TestDec
	dec.image = file.loadImage("/usr/content/textures/floorCobble1.png")
	dec.init [cell.col, cell.row, 0], scale
	cell.decorations.push dec
	return dec
end function

TestDec.render = function(spriteList)
	super.render spriteList
	
	self.calcAngles
	h = -300 + 600 * self.pos[2]
	for i in [0,1,2,3]
		// calculate the (inverse) depth and x position of each corner
		invD = 1 / camera.distance(self.cornerPos[i])
		if invD < 0 then return	// bail-out, for now
		self.screenPos[i][0] = 480 - tan(self.angles[i])*1158
		self.screenPos[i][1] = self.y + h * invD
		// ToDo: deal with points going off the top or bottom of the
		// screen, similar to how we do with walls when they go off
		// the left and right sides.
	end for
	p = _translatePoly(self.screenPos, gfx.scrollX, gfx.scrollY)
	gfx.drawPoly p, color.orange
	gfx.line p[0][0], p[0][1], p[2][0], p[2][1], color.aqua
	gfx.line p[1][0], p[1][1], p[3][0], p[3][1], color.aqua
end function

TestLevel = new level.Level

TestLevel.init = function
	super.init
	self.addOuterWall
	
	self.addOutwardBox 5, 7, 1, 3
	self.addInwardBox 5, 7, 1, 1
	self.addDoubleSidedWall [11, 1], [15, 1]
	self.addDoubleSidedWall [14, 2], [11, 2]
	self.addDoubleSidedWall [14, 2], [14, 5]
	self.addDoubleSidedWall [15, 5], [15, 1]
	self.addDoubleSidedWall [1,11], [16,11]
	self.addDoubleSidedWall [16,11], [16,0]
	
	self.cells[5][5].addWall dirN, wall.Doorway
	self.cells[5][6].addWall dirS, wall.Doorway

	self.cells[8][5].addWall dirE, wall.Doorway
	self.cells[9][5].addWall dirW, wall.Doorway
	
	//TestDec.make self.cells[3][3]
	cobble = FlatDecal.make("floorCobble1.png", self.cells[3][3])
	cobble.sprite.tint = color.gray
	
	FlatDecal.make "shadow.png", self.cells[4][4], 0.25
	Billboard.make "NPCs/guard.png", self.cells[4][4]

	globals.mob = new entities.Slime
	mob.init self.cells[8][3]
	mob.rotateTo 180

	decorations.Box.make self.cells[3][4], "ToonBrickA.png"
	
	Cell.fixCorners self.cells
end function



if locals == globals then level.doStandardDebugCheck(new TestLevel)
