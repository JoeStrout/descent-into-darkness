// The town on the surface has a real sky.  This little module draws it.

import "mathUtil"

init = function(dispNum)
	// The camera FOV is 45 degrees, or 1/8 of a circle.
	// So the total sky needs to wrap around at 960*8 = 7680 pixels.
	// Plus we need 1 more screenful for the wrapping, so a total
	// width of 8640 pixels.
	display(dispNum).mode = displayMode.pixel
	g = display(dispNum)
	g.clear color.black, 8640, 960
	g.scrollY = 160
	gradImg = file.loadImage("/usr/content/backgrounds/town_background.png")
	g.drawImage gradImg, 0, 0, g.width, g.height
	
	clouds = []
	for i in [1,2,3,4]
		clouds.push file.loadImage("/usr/content/backgrounds/clouds/cloud" + i + ".png")
	end for
	x = 0
	lastC = null
	while x < 8400
		y = floor(480 + 300 * rnd)
		c = clouds[clouds.len * rnd]
		if c == lastC then continue
		g.drawImage c, x, y
		if x+7680 < 8640 then g.drawImage c, x+7680, y
		if x + c.width > 7680 then
			g.drawImage c, x-7680, y
			break
		end if
		x = round(x + c.width/2 + c.width*rnd)
	end while
end function


if locals == globals then
	clear
	init 5
	g = display(5)
	while true
		yield
		h = key.axis("Horizontal") * 20
		v = key.axis("Vertical") * 20
		g.scrollY = mathUtil.clamp(g.scrollY + v, 0, 320)
		g.scrollX = (g.scrollX + h + 7680) % 7680
		if key.pressed("escape") then break
	end while
	key.clear
end if

