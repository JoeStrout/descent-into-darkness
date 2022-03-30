// This file defines which specific Level subclass is used for
// each level of the game, and can set up any of them for you
// upon request.


_levelClassByDepth = []

_levelClassByDepth.push "TestLevel"		// Town
_levelClassByDepth.push "MazeLevel"		// Dungeon level 1

// ToDo: explicitly (or pseudo-randomly) assign a level type 
// to each of the 32 dungeon levels.  For now, they're all just this:
while _levelClassByDepth.len < 33
	_levelClassByDepth.push "TestLevel"
end for
_levelClassByDepth.push "TestLevel"		// test level


// Main entry point: get a fresh, initialized level for the 
// given dungeon depth.  Special depth values:
//		0 = Town
//	   -1 = TestLevel
get = function(depth = -1)
	// Here we jump through some hoops to import the appropriate file
	// for the given class, copy the class into the global namespace,
	// instantiate it, initialize the instance, and return it.
	olddir = file.curdir
	file.setdir "/usr/code/levelGenerators"
	className = _levelClassByDepth[depth]
	filename = className[0].lower + className[1:]
	import filename
	levelclass = locals[filename][className]
	globals[className] = levelclass
	lvl = new levelclass
	lvl.init
	file.setdir olddir
	return lvl
end function

