import "listUtil"
import "mathUtil"
import "microstein"
import "levels"

for identifier in "Renderer camera Cell".split
	globals[identifier] = microstein[identifier]
end for

clear
lvl = levels.get(3)
Renderer.cell = lvl.cells
camera.pos = [lvl.startPos[0] + 0.5, lvl.startPos[1] + 0.5, 0.6]

// draw the floor and ceiling
gfx.clear color.gray, 960, 960
gfx.drawImage file.loadImage("/usr/content/backgrounds/floorCeiling.jpg")
gfx.scrollY = 160

text.color = color.white

// Limit the camera movement so that it does not pass through
// walls (or other obstacles).  We're given the old position
// of the camera; read and update camera.pos so that it does
// not get too close to (or cross through) any solid wall.
limitCameraMovement = function(oldPos)
	oldCol = floor(oldPos[0])
	oldRow = floor(oldPos[1])
	cell = lvl.cells[oldCol][oldRow]
	if camera.pos[0] > oldPos[0] and cell.walls[dirE] and cell.walls[dirE].blocksMovement then
		camera.pos[0] = mathUtil.clamp(camera.pos[0], 0, oldCol+0.75)
	else if camera.pos[0] < oldPos[0] and cell.walls[dirW] and cell.walls[dirW].blocksMovement then
		camera.pos[0] = mathUtil.clamp(camera.pos[0], oldCol+0.25, 99999)
	end if
	if camera.pos[1] > oldPos[1] and cell.walls[dirN] and cell.walls[dirN].blocksMovement then
		camera.pos[1] = mathUtil.clamp(camera.pos[1], 0, oldRow+0.75)
	else if camera.pos[1] < oldPos[1] and cell.walls[dirS] and cell.walls[dirS].blocksMovement then
		camera.pos[1] = mathUtil.clamp(camera.pos[1], oldRow+0.25, 99999)
	end if
	// Also check the new cell, in case we've snuck into it sideways
	// and are now too close to a wall.
	newCol = floor(camera.pos[0])
	newRow = floor(camera.pos[1])	
	cell = lvl.cells[newCol][newRow]
	if camera.pos[0] < newCol + 0.25 and cell.walls[dirW] and cell.walls[dirW].blocksMovement then
		camera.pos[0] = newCol + 0.25
	else if camera.pos[0] > newCol + 0.75 and cell.walls[dirE] and cell.walls[dirE].blocksMovement then
		camera.pos[0] = newCol + 0.75
	end if
	if camera.pos[1] < newRow + 0.25 and cell.walls[dirS] and cell.walls[dirS].blocksMovement then
		camera.pos[1] = newRow + 0.25
	else if camera.pos[1] > newRow + 0.75 and cell.walls[dirN] and cell.walls[dirN].blocksMovement then
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
	if mouseX != 0 then camera.turn -2 * mouseX

	mouseY = key.axis("Mouse Y")
	if mouseY != 0 then
		gfx.scrollY = mathUtil.clamp(gfx.scrollY + mouseY * 25, 0, 320)
		display(4).scrollY = gfx.scrollY - 160
	end if

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
