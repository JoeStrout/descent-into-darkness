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

// Calculate the cross product of two 3D vectors
globals.crossProduct = function(a, b)
	return [ a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0] ]
end function

// Normalize a 2D or 3D vector (in place)
globals.normalize = function(v)
	maxi = v.len - 1
	sumSqr = 0
	for i in range(0, maxi)
		sumSqr = sumSqr + v[i]^2
	end for
	if sumSqr == 0 then return
	factor = 1 / sqrt(sumSqr)
	for i in range(0, maxi)
		v[i] = v[i] * factor
	end for
end function

// subtract: subtract a number from all elements of a list (in place),
// OR do element-wise subtraction with another list of the same size.
list.subtract = function(other)
	if other isa list then
		maxi = self.len - 1
		if other.len - 1 < maxi then maxi = other.len - 1
		for i in range(0,maxi)
			self[i] = self[i] - other[i]
		end for
	else
		for i in self.indexes
			self[i] = self[i] - other
		end for
	end if
end function

// minus: subtract a number from all elements of a list, OR do element-wise 
// subtraction with another list of the same size, returning a new list 
// (leaving this one untouched).
list.minus = function(other)
	result = self[:]
	result.subtract other
	return result
end function

runUnitTests = function()
	ensureImport "qa"
	qa.assert max(2,5) == 5
	qa.assert max(5,2) == 5
	qa.assert min(2,5) == 2
	qa.assert min(5,2) == 2
end function

if locals == globals then runUnitTests

	