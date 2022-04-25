// This level represents the town on the surface.  It's a walled
// town with lots of buildings and twisty little roads.

import "miscUtil"
ensureImport "level"
ensureImport "entities"
import "townSky"

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
end function


TownLevel.init = function
	super.init
	self.addOuterWall

	self.addRectBldg 15, 0, 3, 3, dirW
	self.addRectBldg 17, 3, 3, 4, [dirW, dirN]
	self.addRectBldg 12, 5, 3, 4, dirW
	self.addRectBldg 10, 0, 3, 4, dirN
	self.addRectBldg 7, 3, 2, 3, dirE
	self.addRectBldg 7, 10, 7, 3, [dirN, dirE]
	self.addRectBldg 15, 8, 4, 3, [dirS, dirN]
	self.addRectBldg 6, 6, 4, 4, [dirE, dirW]
	
	globals.pit = decorations.Pit.make(self.cells[13][2])
	
	self.startPos = [15, 4]

	Cell.fixCorners self.cells
end function


TownLevel.drawBackground = function(displayNum = 5)
	townSky.init(displayNum)
	display(displayNum).scrollY = 160
end function


if locals == globals then level.doStandardDebugCheck(new TownLevel)
