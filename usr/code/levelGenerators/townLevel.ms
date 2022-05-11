
// This level represents the town on the surface.  It's a walled
// town with lots of buildings and twisty little roads.

import "miscUtil"
ensureImport "level"
ensureImport "entities"
import "townSky"

Roof = new decorations.Mesh
Roof.verts = [null] * 4	// index by direction, then by corner type (none, left, right, both)

Roof.verts[dirW] = [	// roofs to the WEST (east side of bldg)
  [[0.1, 0, 1], [0.1, 1, 1], [-0.1, 1, 1.5], [-0.1, 0, 1.5], [0, 0, 1], [0, 1, 1]],	// no corners
  [[0.1, -0.1, 1], [0.1, 1, 1], [-0.1, 1, 1.5], [-0.1, 0.1, 1.5], [0, 0, 1], [0, 1, 1]], // corner on left
  [[0.1, 0, 1], [0.1, 1.1, 1], [-0.1, 0.9, 1.5], [-0.1, 0, 1.5], [0, 0, 1], [0, 1, 1]], // corner on right
  [[0.1, -0.1, 1], [0.1, 1.1, 1], [-0.1, 0.9, 1.5], [-0.1, 0.1, 1.5], [0, 0, 1], [0, 1, 1]] ] // both corners

Roof.verts[dirE] = [	// roofs to the EAST (west side of bldg)
  [[0.9, 1, 1], [0.9, 0, 1], [1.1, 0, 1.5], [1.1, 1, 1.5], [1, 1, 1], [1, 0, 1]],	// no corners
  [[0.9, 1.1, 1], [0.9, 0, 1], [1.1, 0, 1.5], [1.1, 0.9, 1.5], [1, 1, 1], [1, 0, 1]], // corner on left
  [[0.9, 1.1, 1], [0.9, -0.1, 1], [1.1, 0.1, 1.5], [1.1, 1, 1.5], [1, 1, 1], [1, 0, 1]], // corner on right
  [[0.9, 1.1, 1], [0.9, -0.1, 1], [1.1, 0.1, 1.5], [1.1, 0.9, 1.5], [1, 1, 1], [1, 0, 1]] ] // both corners

Roof.verts[dirS] = [	// roofs to the SOUTH (north side of bldg)
  [[1, 0.1, 1], [0, 0.1, 1], [0, -0.1, 1.5], [1, -0.1, 1.5], [1, 0, 1], [0, 0, 1]],	// no corners
  [[1.1, 0.1, 1], [0, 0.1, 1], [0, -0.1, 1.5], [0.9, -0.1, 1.5], [1, 0, 1], [0, 0, 1]], // corner on left
  [[1, 0.1, 1], [-0.1, 0.1, 1], [0.1, -0.1, 1.5], [1, -0.1, 1.5], [1, 0, 1], [0, 0, 1]], // corner on right
  [[1, 0.1, 1], [-0.1, 0.1, 1], [0.1, -0.1, 1.5], [0.9, -0.1, 1.5], [1, 0, 1], [0, 0, 1]] ] // both corners

Roof.verts[dirN] = [	// roofs to the NORTH (south side of bldg)
  [[0, 0.9, 1], [1, 0.9, 1], [1, 1.1, 1.5], [0, 1.1, 1.5], [0, 1, 1], [1, 1, 1]],	// no corners
  [[-0.1, 0.9, 1], [1, 0.9, 1], [1, 1.1, 1.5], [0.1, 1.1, 1.5], [0, 1, 1], [1, 1, 1]],	// corner on left
  [[0, 0.9, 1], [1.1, 0.9, 1], [0.9, 1.1, 1.5], [0, 1.1, 1.5], [0, 1, 1], [1, 1, 1]],	// corner on right
  [[-0.1, 0.9, 1], [1.1, 0.9, 1], [0.9, 1.1, 1.5], [0.1, 1.1, 1.5], [0, 1, 1], [1, 1, 1]] ]	// both corners

Roof.quads = [ [0, 1, 2, 3], [4, 5, 1, 0] ]
Roof.make = function(cell, direction, cornerOnLeft, cornerOnRight)
	result = new Roof
	result.vertices = Roof.verts[direction][cornerOnLeft + cornerOnRight*2]
	result.init [cell.col, cell.row, 0]
	cell.decorations.push result
	result.quadTexture = file.loadImage("/usr/content/textures/ThatchedRoof.png")
	return result
end function


TownLevel = new level.Level

TownLevel.addGuard = function(column, row)
	FlatDecal.make "shadow.png", self.cells[column][row], 0.25
	Billboard.make "NPCs/guard.png", self.cells[column][row]
end function

TownLevel.addRectBldg = function(left, bottom, width, height, doorDirs=0)
	self.addDoubleWallBox left, bottom, width, height
	
	if doorDirs isa number then doorDirs = [doorDirs]
	for d in doorDirs
		if d == dirS then
			self.cutDoor floor(left + width/2), bottom-1, dirN
		else if d == dirE then
			self.cutDoor left+width, floor(bottom + height/2), dirW
		else if d == dirN then
			self.cutDoor floor(left + width/2), bottom + height, dirS
		else if d == dirW then
			self.cutDoor left-1, floor(bottom + height/2), dirE
		end if
	end for
	
	for row in range(bottom, bottom+height-1)
		cornerOnRight = (row == bottom)
		cornerOnLeft = (row == bottom+height-1)
		if left > 0 then Roof.make self.cells[left-1][row], dirE, cornerOnLeft, cornerOnRight
		cornerOnLeft = (row == bottom)
		cornerOnRight = (row == bottom+height-1)
		if left+width < self.cols then Roof.make self.cells[left+width][row], dirW, cornerOnLeft, cornerOnRight
		
		// add ceiling to every cell inside the building
		for col in range(left, left + width - 1)
			// We're going to actually add FOUR celiing decorations to each tile.
			// This works around the culling problem, and avoids distortions that
			// occur when you stretch a really huge sprite at certain angles.
			ceiling = FlatDecal.make("CeilingTile.png", self.cells[col][row], 0.5)
			ceiling.setPos [col+0.25, row+0.25, 1]
			ceiling = FlatDecal.make("CeilingTile.png", self.cells[col][row], 0.5)
			ceiling.setPos [col+0.25, row+0.75, 1]
			ceiling = FlatDecal.make("CeilingTile.png", self.cells[col][row], 0.5)
			ceiling.setPos [col+0.75, row+0.75, 1]
			ceiling = FlatDecal.make("CeilingTile.png", self.cells[col][row], 0.5)
			ceiling.setPos [col+0.75, row+0.25, 1]			
		end for
	end for
	for col in range(left, left + width - 1)
		cornerOnRight = (col == left+width-1)
		cornerOnLeft = (col == left)
		if bottom > 0 then Roof.make self.cells[col][bottom-1], dirN, cornerOnLeft, cornerOnRight
		cornerOnLeft = (col == left+width-1)
		cornerOnRight = (col == left)
		Roof.make self.cells[col][bottom+height], dirS, cornerOnLeft, cornerOnRight
	end for
		
end function

TownLevel.clearWalls = function(left, bottom, width, height)
	for col in range(left, left+width-1)
		for row in range(bottom, bottom+height-1)
			if row > bottom then self.cells[col][row].walls[dirS] = null
			if row < bottom+height-1 then self.cells[col][row].walls[dirN] = null
			if col > left then self.cells[col][row].walls[dirW] = null
			if col < left+width-1 then self.cells[col][row].walls[dirE] = null
		end for
	end for
end function

TownLevel.init = function
	super.init
	
	Wall.imageA = file.loadImage("/usr/content/textures/SewerWallA.png")
	Wall.imageB = file.loadImage("/usr/content/textures/SewerWallB.png")
	Wall.alts = []
	
	self.addOuterWall
	self.addOutwardBox 0, 0, 1, 1
	self.addOutwardBox 31, 0, 1, 1
	self.addOutwardBox 31, 31, 1, 1
	self.addOutwardBox 0, 31, 1, 1
	
	self.addGuard 0, 1
	self.addGuard 30, 0
	self.addGuard 31,30
	self.addGuard 1, 31
	
	Wall.imageA = file.loadImage("/usr/content/textures/TownHouseWallA.png")
	Wall.imageB = file.loadImage("/usr/content/textures/TownHouseWallB.png")
	Wall.alts = [file.loadImage("/usr/content/textures/TownHouseWallAlt.png")]
	wall.Doorway.prepImages
	
	// southwest quarter
	self.addRectBldg 15, 0, 3, 3, dirW
	self.addRectBldg 17, 3, 3, 4, [dirW, dirN]
	self.addRectBldg 12, 5, 3, 4, dirW
	self.addRectBldg 10, 0, 3, 4, dirN
	self.addRectBldg 7, 3, 2, 3, dirE
	self.addRectBldg 7, 10, 7, 3, [dirN, dirE]
	self.addRectBldg 15, 8, 4, 3, [dirS, dirN]
	self.addRectBldg 6, 6, 4, 4, [dirE, dirW]
	self.addRectBldg 3, 0, 3, 4, [dirE, dirN]
	self.addRectBldg 3, 10, 4, 3, dirN
	self.addRectBldg 0, 5, 5, 4, dirN
	self.addRectBldg 0, 10, 2, 5, dirE
	
	self.addRectBldg 1, 16, 5, 2, [dirN, dirE]
	self.addRectBldg 4, 14, 2, 2, dirE
	self.clearWalls 4, 15, 2, 2
	
	self.addRectBldg 7, 13, 2, 4, dirW
	self.addRectBldg 15, 12, 4, 3, dirN

	globals.pit = decorations.Pit.make(self.cells[13][2])
	self.startPos = [15, 4]
	
	// southeast quarter
	self.addRectBldg 20, 9, 3, 5, dirW
	self.addRectBldg 21, 6, 5, 3, [dirN, dirW]
	self.addRectBldg 21, 2, 3, 2, dirN
	self.addRectBldg 24, 0, 4, 2, dirN
	self.addRectBldg 25, 3, 2, 2, dirW
	self.addRectBldg 28, 3, 4, 4, [dirW, dirN]
	self.addRectBldg 27, 8, 4, 3, [dirS, dirE]
	self.addRectBldg 24, 11, 5, 2, dirN
	self.addRectBldg 30, 12, 2, 4, dirW
	self.addRectBldg 17, 16, 7, 2, dirS
	self.addRectBldg 24, 14, 2, 4, [dirN, dirE]
	self.addRectBldg 26, 17, 5, 2, dirS
	Cell.fixCorners self.cells
end function


TownLevel.drawBackground = function(displayNum = 5)
	townSky.init(displayNum)
	display(displayNum).scrollY = 160
end function


if locals == globals then level.doStandardDebugCheck(new TownLevel)
