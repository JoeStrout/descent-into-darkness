// This module loads (and in many cases, cuts apart) the various images
// needed for sprites and textures in the game.


vfxFolder = "/usr/content/vfx"
sparkle = file.loadImage(file.child(vfxFolder, "sparkle.png"))


if locals == globals then
	clear
	// let's try a little sparkle animation!
	sp = new Sprite
	display(4).sprites.push sp
	sp.image = sparkle
	sp.x = 480; sp.y = 320
	
	while true
		sp.rotation = 45 * floor(rnd*8)
		sp.scale = 2 * (0.8 + 0.4*rnd)
		yield
	end while

end if