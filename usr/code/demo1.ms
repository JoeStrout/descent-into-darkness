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

	microstein.makeInwardBox 0, 0, mazeGenerator.kCols, mazeGenerator.kRows

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
gfx.clear color.gray, 960, 960
gfx.drawImage file.loadImage("/usr/content/backgrounds/floorCeiling.jpg")
gfx.scrollY = 160

text.color = color.white

// Limit the camera movement so that it does not pass through
// walls (or other obstacles).  We're given the old position
// of the camera; read and update camera.pos so that it does
// not get too close to (or cross through) any wall.
limitCameraMovement = function(oldPos)
	oldCol = floor(oldPos[0])
	oldRow = floor(oldPos[1])
	cell = grid[oldCol][oldRow]
	if camera.pos[0] > oldPos[0] and cell.walls[dirE] then
		camera.pos[0] = mathUtil.clamp(camera.pos[0], 0, oldCol+0.75)
	else if camera.pos[0] < oldPos[0] and cell.walls[dirW] then
		camera.pos[0] = mathUtil.clamp(camera.pos[0], oldCol+0.25, 99999)
	end if
	if camera.pos[1] > oldPos[1] and cell.walls[dirN] then
		camera.pos[1] = mathUtil.clamp(camera.pos[1], 0, oldRow+0.75)
	else if camera.pos[1] < oldPos[1] and cell.walls[dirS] then
		camera.pos[1] = mathUtil.clamp(camera.pos[1], oldRow+0.25, 99999)
	end if
	// Also check the new cell, in case we've snuck into it sideways
	// and are now too close to a wall.
	newCol = floor(camera.pos[0])
	newRow = floor(camera.pos[1])
	cell = grid[newCol][newRow]
	if camera.pos[0] < newCol + 0.25 and cell.walls[dirW] then
		camera.pos[0] = newCol + 0.25
	else if camera.pos[0] > newCol + 0.75 and cell.walls[dirE] then
		camera.pos[0] = newCol + 0.75
	end if
	if camera.pos[1] < newRow + 0.25 and cell.walls[dirS] then
		camera.pos[1] = newRow + 0.25
	else if camera.pos[1] > newRow + 0.75 and cell.walls[dirN] then
		camera.pos[1] = newRow + 0.75
	end if
	
end function

handleInputs = function
	hInput = key.axis("Horizontal")
	vInput = key.axis("Vertical")
	prevPos = camera.pos[:]
	camera.moveRight 0.1 * hInput
	camera.moveForward 0.1 * vInput
	if key.pressed("q") then
		camera.turn 4
	else if key.pressed("e") then
		camera.turn -4
	end if
	mouseX = key.axis("Mouse X")
	if mouseX != 0 then camera.turn -5 * mouseX
	if vInput or hInput then limitCameraMovement prevPos
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
key.clear
text.row = 2
