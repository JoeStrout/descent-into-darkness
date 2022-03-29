import "mazeGenerator"
import "listUtil"
import "microstein"

for identifier in "Renderer Cell Wall Decoration dirN dirE dirS dirW dirDx dirDy".split
	globals[identifier] = microstein[identifier]
end for

clear

prepareLevel = function
	mazeGenerator.generate
	mazeGenerator.debugDraw

	Renderer.cell = Cell.make2dArray(mazeGenerator.kCols, mazeGenerator.kRows)
	globals.grid = Renderer.cell

	microstein.makeInwardBox(0, 0, mazeGenerator.kCols, mazeGenerator.kRows)

	for col in range(0, mazeGenerator.kCols-1)
		for row in range(0, mazeGenerator.kRows-1)
			if col > 0 and mazeGenerator.wall[col][row][0] then
				// vertical wall
				grid[col][row].addWall dirE
				if col+1 < mazeGenerator.kCols then grid[col+1][row].addWall dirW
			end if
			if row > 0 and mazeGenerator.wall[col][row][1] then
				// horizontal wall
				grid[col][row].addWall dirN
				if row+1 < mazeGenerator.kRows then grid[col][row+1].addWall dirS
			end if		
		end for
	end for
	Cell.fixCorners grid
end function

prepareLevel
microstein.demo
