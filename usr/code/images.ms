// This module loads (and in many cases, cuts apart) the various images
// needed for sprites and textures in the game.


vfxFolder = "/usr/content/vfx"
sparkle = file.loadImage(file.child(vfxFolder, "sparkle.png"))

uiFolder = "/usr/content/ui"
parchment = file.loadImage(file.child(uiFolder, "parchment_alpha.png"))

playerIndicator = file.loadImage("/sys/pics/arrows/arrow2.png")

// Load an image given a path (under /usr/content unless
// you specify otherwise).  Uses a cache, so feel free to
// call this frequently.
_imageCache = {}	// key: path; value: image
load = function(path)
	if path[0] != "/" then path = "/usr/content/" + path
	if not _imageCache.hasIndex(path) then
		_imageCache[path] = file.loadImage(path)
	end if
	return _imageCache[path]
end function

// Load a whole series of images by appending -00.png,
// -01.png, etc. to the given partial path.
_seriesCache = {}	// key: path; value: image
loadSeries = function(partialPath)
	if _seriesCache.hasIndex(partialPath) then return _seriesCache[partialPath]
	idx = 0
	result = []
	while true
		fullPath = partialPath + "-" + ("0"+idx)[-2:] + ".png"
		img = images.load(fullPath)
		if img then result.push img else break
		idx = idx + 1
	end while
	_seriesCache[partialPath] = result
	return result
end function

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