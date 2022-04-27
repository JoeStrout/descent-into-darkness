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

Roof.verts[dirS] = [	// roofs to the SOUTH (north side of bldg)
  [[1, 0.1, 1], [0, 0.1, 1], [0, -0.1, 1.5], [1, -0.1, 1.5], [1, 0, 1], [0, 0, 1]],	// no corners
  [[1.1, 0.1, 1], [0, 0.1, 1], [0, -0.1, 1.5], [0.9, -0.1, 1.5], [1, 0, 1], [0, 0, 1]], // corner on left
  [[1, 0.1, 1], [-0.1, 0.1, 1], [0.1, -0.1, 1.5], [1, -0.1, 1.5], [1, 0, 1], [0, 0, 1]], // corner on right
  [[1, 0.1, 1], [-0.1, 0.1, 1], [0.1, -0.1, 1.5], [0.9, -0.1, 1.5], [1, 0, 1], [0, 0, 1]] ] // both corners

Roof.quads = [ [0, 1, 2, 3], [4, 5, 1, 0] ]
Roof.make = function(cell, direction, cornerOnLeft, cornerOnRight)
	result = new Roof
	result.vertices = Roof.verts[direction][cornerOnLeft + cornerOnRight*2]
	result.init [cell.col, cell.row, 0]
	cell.decorations.push result
	result.quadTexture = file.loadImage("/usr/content/textures/ToonBrickA.png")
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
		cornerOnLeft = (row == bottom)
		cornerOnRight = (row == bottom+height-1)
		Roof.make self.cells[left+width][row], dirW, cornerOnLeft, cornerOnRight
	end for
	for col in range(left, left + width - 1)
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
	self.addRectBldg 20, 9, 3, 5, dirW
	
	
	globals.pit = decorations.Pit.make(self.cells[13][2])
	
	self.startPos = [15, 4]

	Cell.fixCorners self.cells
end function


TownLevel.drawBackground = function(displayNum = 5)
	townSky.init(displayNum)
	display(displayNum).scrollY = 160
end function


if locals == globals then level.doStandardDebugCheck(new TownLevel)
