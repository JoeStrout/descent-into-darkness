// Miscellaneous small helper functions that don't fit anywhere else.

// Make sure we have the correct folders in our include paths.
if env.importPaths.indexOf("/usr/code") == null then
	env.importPaths.insert 1, "/usr/code"
end if

// ensureImport: check whether the given module has been imported already
// (or is in the process of being imported).  If so, return immediately.
// If not, then import that module into the global namespace.
globals.ensureImport = function(moduleName)
	if globals.hasIndex(moduleName) then return
	//print "ensureImport(" + moduleName + ") called from " + stackTrace[1]
	globals[moduleName] = "PENDING"	// (module is being imported now)
	import moduleName
	globals[moduleName] = locals[moduleName]
end function

// Handy constants
globals.twoPi = pi * 2
globals.halfPi = pi / 2
globals.degToRad = pi / 180
globals.radToDeg = 180 / pi

// Wall directions (tied to the order in which we list corners)
globals.dirS = 0		// Y-1
globals.dirE = 1		// X+1
globals.dirN = 2		// Y+1
globals.dirW = 3		// X-1
globals.dirDx = [0, 1, 0, -1]
globals.dirDy = [-1, 0, 1, 0]

// Get the maximum of two values
globals.max = function(a,b)
	if a > b then return a else return b
end function

// Get the minimum of two values
globals.min = function(a,b)
	if a < b then return a else return b
end function

// Get back the result of a die roll with a certain number of sides
rollDie = function(sides = 6)
	return ceil(rnd * sides)
end function

runUnitTests = function()
	ensureImport "qa"
	qa.assert max(2,5) == 5
	qa.assert max(5,2) == 5
	qa.assert min(2,5) == 2
	qa.assert min(5,2) == 2
end function

if locals == globals then runUnitTests

	