// This is a Level subclass that we use only for testing; it is never
// intended to go into the final game.  Hack away!

import "miscUtil"
ensureImport "level"

TestLevel = new level.Level

TestLevel.init = function
	self.clear
	self.addOuterWall
	
	self.addOutwardBox 5, 7, 1, 3
	self.addInwardBox 5, 7, 1, 1
	self.addDoubleSidedWall [11, 1], [15, 1]
	self.addDoubleSidedWall [14, 2], [11, 2]
	self.addDoubleSidedWall [14, 2], [14, 5]
	self.addDoubleSidedWall [15, 5], [15, 1]
	
	Cell.fixCorners self.cells
end function



if locals == globals then level.doStandardDebugCheck(new TestLevel)
