// Load all the sounds in the content/sounds folder,
// and provide them as entries in this module.

folder = "/usr/content/sounds"

reload = function
	for fname in file.children(folder)
		path = file.child(folder, fname)
		snd = file.loadSound(path)
		if snd then outer[fname - ".wav"] = snd
	end for
	
	outer.hit = file.loadSound("/sys/sounds/hit.wav")
end function

reload
