import "mazeGenerator"
import "listUtil"
import "mathUtil"
import "microstein"

for identifier in "Renderer camera Cell Wall Decoration dirN dirE dirS dirW dirDx dirDy".split
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
				grid[col][row].addWall dirW
				if col > 0 then grid[col-1][row].addWall dirE
			end if
			if row > 0 and mazeGenerator.wall[col][row][1] then
				// horizontal wall
				grid[col][row].addWall dirS
				if row > 0 then grid[col][row-1].addWall dirN
			end if		
		end for
	end for
	Cell.fixCorners grid
end function

// prepare the level (maze)
prepareLevel

// draw the floor and ceiling
gfx.fillRect 0, 0, 960, 320, color.silver	// floor
gfx.fillRect 0, 320, 960, 320, color.gray	// ceiling

text.color = color.white

handleInputs = function
	hInput = key.axis("Horizontal")
	vInput = key.axis("Vertical")
	camera.moveRight 0.1 * hInput
	camera.moveForward 0.1 * vInput
	if key.pressed("q") then
		camera.turn 4
	else if key.pressed("e") then
		camera.turn -4
	end if
	mouseX = key.axis("Mouse X")
	if mouseX != 0 then camera.turn -5 * mouseX
	
end function

// enter the main loop
while true
	needRender = true
	if key.pressed("escape") then
		break
	else 
		handleInputs
	end if
	microstein.rerender
	text.row = 25; text.column = 3
	print "X:" + mathUtil.numToStr(camera.pos[0], 2) + 
	   "  Y:" + mathUtil.numToStr(camera.pos[1], 2) + 
	   "  Angle: " + round(camera.angle) + "     "
end while