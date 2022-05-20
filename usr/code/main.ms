import "miscUtil"
import "listUtil"
import "mathUtil"
import "updatable"
import "renderer"
import "levels"
import "spells"
import "sounds"
import "items"
import "inventoryUI"
import "playerData"
clear
import "hud"

currentLevelNum = 0

Renderer = renderer.Renderer
camera = renderer.camera

display(7).mode = displayMode.pixel
display(7).clear color.clear
// set up display 2 for debug drawing
display(2).mode = displayMode.pixel
display(2).color = color.fuchsia
display(2).clear color.clear


player.init

lvl = levels.get(currentLevelNum)
Renderer.cell = lvl.cells
camera.pos = [lvl.startPos[0] + 0.5, lvl.startPos[1] + 0.5, 0.6]
lvl.drawBackground

jumpToLevelNum = null

// Other code can call this function, even during rendering,
// to move the player to the next level down:
enterNextLevel = function
	globals.jumpToLevelNum = currentLevelNum + 1
end function

// This is the function that actually does all the work.  But it
// is called from the main loop when jumpToLevelNum is set; other
// code should not call it directly.
ascendOrDescend = function
	if jumpToLevelNum > currentLevelNum then verb = "Descending" else verb = "Ascending"
	globals.currentLevelNum = jumpToLevelNum
	msg = verb + " to level " + currentLevelNum + "..."
	hud.fadeOut msg
	entities.clearAll
	globals.lvl = levels.get(currentLevelNum)
	Renderer.cell = lvl.cells
	camera.pos = [lvl.startPos[0] + 0.5, lvl.startPos[1] + 0.5, 0.6]
	lvl.drawBackground
	renderer.rerender
	hud.fadeIn msg
end function

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

doAction = function
	// open/close a door if we are facing one
	cell = lvl.cells[camera.pos[0]][camera.pos[1]]
	dir = miscUtil.closestDir(camera.angle)
	if cell.walls[dir] isa wall.Doorway then
		cell.walls[dir].toggleDoor
		if cell.walls[dir].isClosed then
			sounds.doorClose.play
		else
			sounds.doorOpen.play
		end if
	end if
end function

doFire = function
	// fire (cast) a spell!
	spells.cast
end function

showMap = function
	// parchment
	display(3).mode = displayMode.pixel
	display(3).clear "#00000044"
	display(3).drawImage images.parchment, 480-images.parchment.width/2, 320-images.parchment.height/2
	display(2).mode = displayMode.pixel
	
	// level
	mapMidX = 480-15
	mapMidY = 320-6
	mapSize = 384
	mapLeft = mapMidX - mapSize/2
	mapBottom = mapMidY - mapSize/2
	globals.gfx = display(2)
	gfx.clear color.clear
	lvl.drawMap mapLeft, mapBottom, mapSize, mapSize
	
	// player indicator
	display(1).mode = displayMode.sprite
	display(1).clear
	playerInd = new Sprite
	playerInd.image = images.playerIndicator
	playerInd.scale = 0.1
	playerInd.x = mapLeft + camera.pos[0] * mapSize/lvl.cols
	playerInd.y = mapBottom + camera.pos[1] * mapSize/lvl.rows
	playerInd.rotation = camera.angle
	display(1).sprites.push playerInd
	
	while key.pressed("m"); yield; end while; key.clear
	
	gfx.print "Press any key", 650, 105, "#555522AA", "small"
	while not key.available
		playerInd.scale = 1/8 + 0.01 * sin(time*3)
		yield
	end while
	key.clear
	while key.pressed("m"); yield; end while; key.clear
	display(3).mode = displayMode.text
	globals.gfx = display(5)
	display(1).mode = displayMode.text
end function

showInventory = function
	while key.pressed("i"); yield; end while
	key.clear
	inventoryUI.dropArea.pickUpFromWorld
	inventoryUI.presentModal
	inventoryUI.dropArea.dropIntoWorld
	while key.pressed("i") or key.pressed("escape"); yield; end while
	key.clear
end function

wasActionDown = false
wasFireDown = false
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
	if mouseX != 0 then camera.turn -3 * mouseX
	
	mouseY = key.axis("Mouse Y")
	if mouseY != 0 then
		gfx.scrollY = mathUtil.clamp(gfx.scrollY + mouseY * 25, 0, 320)
		display(4).scrollY = gfx.scrollY - 160
		display(2).scrollY = display(4).scrollY
	end if
	
	if vInput or hInput then limitCameraMovement prevPos
	
	actionDown = key.pressed("left shift") or key.pressed("right shift") or key.pressed("tab")
	if actionDown and not wasActionDown then doAction
	outer.wasActionDown = actionDown
	
	fireDown = key.pressed("space") or key.pressed("return") or key.pressed("enter")
	if fireDown and not wasFireDown then doFire
	outer.wasFireDown = fireDown
	
	if key.pressed("m") then showMap
	if key.pressed("i") then showInventory
end function

//setup timestamp variables

lastTimestamp = time
recentDt = [1/60] * 30
recentDtIdx = 0

// enter the main loop
while true
	if key.pressed("escape") then
		break
	else 
		handleInputs
	end if
	if jumpToLevelNum != null then
		ascendOrDescend
		jumpToLevelNum = null
	end if
	
	dt = time - lastTimestamp
	lastTimestamp = time
	updatable.update min(dt, 0.1)
	renderer.rerender		// (includes `yield`)
	
	recentDt[recentDtIdx] = dt
	recentDtIdx = (recentDtIdx + 1) % 30
	hud.fps = 1 / (recentDt.mean)
	hud.update
end while
key.clear
text.row = 2
