// mazeGenerator
//
//	This module is responsible for generating interesting sets
//	of room walls, making a simple maze.

import "listUtil"

debug = false
kCols = 19
kRows = 19		// should be odd to guarantee fully connected room

// Symmetry types (how second painter moves relative to the first)
kInvertNone = 0
kInvertX = 1
kInvertY = 2
kInvertXY = 3

// Direction class
Direction = {}
Direction.dx = 0
Direction.dy = 0

Direction.make = function(dx, dy)
	result = new Direction
	result.dx = dx
	result.dy = dy
	return result
end function

Direction.other = function(symmetry)
	if symmetry == kInvertX then
		return Direction.make(-self.dx, self.dy)
	else if symmetry == kInvertY then
		return Direction.make(self.dx, -self.dy)
	else if symmetry == kInvertXY then
		return Direction.make(-self.dx, -self.dy)
	else
		return Direction.make(self.dx, self.dy)
	end if
end function

Direction.str = function
	return self.dx + "," + self.dy
end function

// X and Y positions of our two painters
painterX = [0,0]
painterY = [0,0]

// Walls: indexed by column, row, and horizontal(1) vs vertical(0);
// value is 1 for a wall, 0 for no wall
wall = list.init3d(kCols, kRows, 2, 1)	// true or false

// Also track which cells have been visited by a painter,
// and from which direction (so we can backtrack).
breadcrumbs = list.init2d(kCols, kRows)	// Direction or null

debugDraw = function
	left = 950 - 32*kCols
	bottom = 630 - 32*kRows
	gfx.clear
	gfx.drawRect left, bottom, 64*kCols, 64*kRows
	for col in range(0, kCols-1)
		for row in range(0, kRows-1)
			x = left + 32 * col
			y = bottom + 32 * row
			if wall[col][row][0] then gfx.line x, y, x, y + 32
			if wall[col][row][1] then gfx.line x, y, x + 32, y
			if col == painterX[0] and row == painterY[0] then
				gfx.print "0", x+6, y+3
			end if
			if col == painterX[1] and row == painterY[1] then
				gfx.print "1", x+12, y+3
			end if
		end for
	end for
end function

// moveOnePainter: move the given painter in the given direction,
// updating walls and breadcrumbs accordingly.
moveOnePainter = function(p, dir)
	if dir.dx > 0 then
		wall[painterX[p]+1][painterY[p]][0] = false
	else if dir.dx < 0 then
		wall[painterX[p]][painterY[p]][0] = false
	else if dir.dy > 0 then
		wall[painterX[p]][painterY[p]+1][1] = false
	else
		wall[painterX[p]][painterY[p]][1] = false
	end if
	
	painterX[p] = painterX[p] + dir.dx
	painterY[p] = painterY[p] + dir.dy
	if breadcrumbs[painterX[p]][painterY[p]] == null then
		breadcrumbs[painterX[p]][painterY[p]] = dir
	end if
end function

// move: move painter 0 in the given direction, and painter 1
// in the corresponding direction (according to our symmetry),
// knocking out the walls as we go.
move = function(dir)
//	if debug then print "Moving painter 0 " + dir.str + ", and painter 1 " + dir.other(symmetry).str
	moveOnePainter 0, dir
	moveOnePainter 1, dir.other(symmetry)
end function

// addIfValid: if we could move in direction `dir` without wandering
// out of bounds or hitting existing breadcrumbs, then add it to dirs.
addIfValid = function(dir, dirs)
	x = painterX[0] + dir.dx
	y = painterY[0] + dir.dy
	if x < 0 or x >= kCols or y < 0 or y >= kRows then return // out of bounds
	if breadcrumbs[x][y] != null then return	// hit breadcrumbs; been there before
	dirs.push dir
end function

// getValidDirs: find all the directions that painter 0 could
// move from its current position.
getValidDirs = function
	dirs = []
	addIfValid Direction.make(1,0), dirs
	addIfValid Direction.make(-1,0), dirs
	addIfValid Direction.make(0,1), dirs
	addIfValid Direction.make(0,-1), dirs
	return dirs
end function

// pickDirection: pick a direction for painter 0 to move,
// backtracking if necessary.  Return null if no valid move
// can be found.
pickDirection = function
	loopCount = 0
	while true
		dirs = getValidDirs
		if dirs then break	// found some dirs; done backtracking!
		
		// uh-oh... no valid directions from here;
		// backtrack if possible.
		crumb = breadcrumbs[painterX[0]][painterY[0]]
		if crumb.dx == 0 and crumb.dy == 0 then return null  // at beginning
		painterX[0] = painterX[0] - crumb.dx
		painterY[0] = painterY[0] - crumb.dy
		otherCrumb = crumb.other(symmetry)
		painterX[1] = painterX[1] - otherCrumb.dx
		painterY[1] = painterY[1] - otherCrumb.dy
		loopCount = loopCount + 1
		if loopCount > 200 then
			print "Breadcrumb loop!"
			return null
		end if
	end while
	return dirs.any	// pick random valid direction
end function

// pickStartPos: choose a random starting positino for painter 0.
pickStartPos = function
	choice = floor(rnd * 4)
	if choice == 0 then			// top
		painterX[0] = floor(kCols/2)
		painterY[0] = kRows - 1
	else if choice == 1 then	// bottom
		painterX[0] = floor(kCols/2)
		painterY[0] = 0
	else if choice == 2 then	// left
		painterX[0] = 0
		painterY[0] = floor(kRows/2)
	else						// right
		painterX[0] = kCols - 1
		painterY[0] = floor(kRows/2)
	end if
end function

// placePainter1: place the second painter, based on the position
// of the first painter and our symmetry type.
placePainter1 = function
	if symmetry == kInvertX or symmetry == kInvertXY then
		painterX[1] = kCols - 1 - painterX[0]
	else
		painterX[1] = painterX[0]
	end if
	if symmetry == kInvertY or symmetry == kInvertXY then
		painterY[1] = kRows - 1 - painterY[0]
	else
		painterY[1] = painterY[0]
	end if
end function


init = function(rows=9, cols=9)
	outer.kRows = rows
	outer.kCols = cols
	outer.painterX = [0,0]
	outer.painterY = [0,0]
end function

// generate: make a new maze!  This is the main entry point.
// Call this (after init) to make a maze.
generate = function(symmetry = null)
	// reset our data: all walls in place, no crumbs.
	outer.wall = list.init3d(kCols, kRows, 2, 1)
	outer.breadcrumbs = list.init2d(kCols, kRows)
	
	// Place the pointers and assign our symmetry type.
	if symmetry == null then outer.symmetry = floor(4 * rnd) else outer.symmetry = symmetry
	pickStartPos
	placePainter1
	breadcrumbs[painterX[0]][painterY[0]] = Direction.make(0,0) // special start indicator
	
	if debug then
		debugDraw
		print "painter 0 at " + painterX[0]+"," + painterY[0] +
		 ", and painter 1 at " + painterX[1]+"," + painterY[1]
		print "Symmetry: " + symmetry
	end if
			
	loopCount = 0
	while true
		if debug then wait 0.2
		
		// Pick a random neighbor to visit.  (This will backtrack if needed.)
		dir = pickDirection
		if dir == null then break
		
		// Move in that direction, updating walls and breadcrumbs.
		move dir
		if debug then debugDraw
		
		loopCount = loopCount + 1
		if loopCount > 1000 then
			print "Too much moving!"
			return
		end if
	end while	
end function

// Report whether the indicated wall should be in the maze.
// Call this after calling generate.
shouldHaveWall = function(col, row, horizontal)
	if col >= kCols or row >= kRows then return true
	return wall[col][row][horizontal]
end function

if locals == globals then
	debug = true
	init
	clear
	generate
end if
