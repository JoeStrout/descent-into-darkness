// This level forms a proper maze, with an open space at the center
// but otherwise very mazy everywhere else.

import "miscUtil"
ensureImport "level"
import "mazeGenerator"

MazeLevel = new level.Level

MazeLevel.init = function
	// make sure we have an odd number of rows/columns
	self.clear 19, 19
	self.startPos = [2,2]
	self.addOuterWall
	
	// Want a repeatable maze for testing?  Try:  rnd(42)

	mazeGenerator.init self.cols, self.rows
	mazeGenerator.generate mazeGenerator.kInvertX

	// clear a center room
	for col in range(floor(self.cols/2)-1, floor(self.cols/2)+1)
		for row in range(floor(self.rows/2)-1, floor(self.rows/2)+1)
			mazeGenerator.wall[col][row][0] = false
			mazeGenerator.wall[col+1][row][0] = false		
			mazeGenerator.wall[col][row][1] = false		
			mazeGenerator.wall[col][row+1][1] = false		
		end for
	end for

	for col in range(0, self.rows-1)
		for row in range(0, self.cols-1)
			if col > 0 and mazeGenerator.wall[col][row][0] then
				// vertical wall
				self.cells[col][row].addWall dirW
				if col > 0 then self.cells[col-1][row].addWall dirE
			end if
			if row > 0 and mazeGenerator.wall[col][row][1] then
				// horizontal wall
				self.cells[col][row].addWall dirS
				if row > 0 then self.cells[col][row-1].addWall dirN
			end if		
		end for
	end for
	
			
	Cell.fixCorners self.cells

end function



if locals == globals then level.doStandardDebugCheck(new MazeLevel)
