// This file manages the Heads-Up Display, i.e., the overlays that
// show the player's status during the game.

import "miscUtil"
ensureImport "playerData"
ensureImport "updatable"
ensureImport "listUtil"
ensureImport "mathUtil"
ensureImport "stringUtil"

display(1).mode = displayMode.text
textDisp = display(1)
textDisp.clear
textDisp.color = color.silver
textDisp.delimiter = ""

display(0).mode = displayMode.sprite
painDisp = display(0)
painDisp.clear

painSprite = new UpdatableSprite
painSprite.image = file.loadImage("/usr/content/vfx/painOverlay.png")
painSprite.x = 480
painSprite.y = 320
painSprite.alpha = 255
painSprite.init
painSprite.suspend

fps = 60

painSprite.update = function(dt)
	self.alpha = mathUtil.moveTowards(self.alpha, 0, 512*dt)
	if self.alpha <= 0 then
		self.suspend
		painDisp.sprites.removeVal self
	else
		self.tint = "#FFFFFF" + hex2(self.alpha)
	end if
end function

showPain = function
	painSprite.resume
	if painDisp.sprites.indexOf(painSprite) == null then painDisp.sprites.insert 0, painSprite
	painSprite.alpha = 255
	painSprite.tint = "#FFFFFF"
	display(0).mode = displayMode.sprite
end function

// Call this function when the player dies.
// Note: this is a blocking function (does not return until it's done).
showDeath = function
	update
	showPain
	display(3).mode = displayMode.solidColor
	while painSprite.alpha >= 1
		painSprite.update 1/240
		display(3).color = "#000000" + hex2(255 - painSprite.alpha)
		yield
	end while
	textDisp.row = 12; textDisp.column = 27; textDisp.color = color.silver
	textDisp.print "You have died."
	wait 2
end function

printCentralMessage = function(msg="")
	textDisp.row = 12
	textDisp.column = 0
	textDisp.color = color.silver
	textDisp.print " "*(34-msg.len/2) + msg + " "*(34-msg.len/2)
	return
end function

fadeOut = function(msg="")
	update
	
	printCentralMessage msg

	display(3).mode = displayMode.solidColor
	for alpha in range(0, 255, 2)
		display(3).color = "#000000" + hex2(alpha)
		yield
	end for
end function

fadeIn = function(msg="")
	update
	
	printCentralMessage msg
	
	display(3).mode = displayMode.solidColor
	for alpha in range(255, 0, -2)
		display(3).color = "#000000" + hex2(alpha)
		yield
	end for
	display(3).mode = displayMode.text

	printCentralMessage ""
end function

update = function
	display(1).mode = displayMode.text
	textDisp.row = 25; textDisp.column = 3
	
	textDisp.color = color.silver
	textDisp.print "Health: "
	if player.health > 70 then
		textDisp.color = color.lime
	else if player.health > 30 then
		textDisp.color = color.yellow
	else
		textDisp.color = color.red
	end if
	textDisp.print str(player.health).pad(6)
	textDisp.color = color.silver
	textDisp.print "XP: " + str(player.xp).pad(6)
	textDisp.print "Coins: "
	textDisp.color = "#FFFF88"; textDisp.print str(player.gold).pad(6)
	textDisp.color = color.silver
	textDisp.print "Depth: " + str(currentLevelNum).pad(6)
	camDir = miscUtil.closestDir(camera.angle)
	textDisp.print miscUtil.dirString(camDir).pad(8)
	
	textDisp.color = color.gray
	textDisp.column = 60
	textDisp.print ("    " + round(fps) + " FPS")[-8:]
end function

if locals == globals then
	clear
	camera = {"angle": 0}
	update
	print
	print
	print "Press space to trigger pain."
	while true
		if key.available then
			k = key.get
			if k == char(27) then break
			if k == " " then
				player.health = player.health - 5
				showPain
			end if
		end if
		update
		updatable.update
		yield
	end while
end if
