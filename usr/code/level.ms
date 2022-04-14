// This file defines the Level class, which represents one level of the
// dungeon.  It's a map, a scene, a layout -- the set of Cells with their
// walls, decorations, and entities that constitute the current play area.

// Most levels will actually be some subclass (defined in another file),
// which provides unique pseudo-random generation code and perhaps other
// level-specific functionality.

import "miscUtil"
ensureImport "renderer"
ensureImport "decorations"
ensureImport "qa"

for identifier in "Renderer camera Cell".split
	globals[identifier] = renderer[identifier]
end for

Level = {}
Level.cols = 32
Level.rows = 32
Level.cells = null		// 2D array of Cell
Level.startPos = [2,2]

// init method: set up (load or generate) this level.
// Subclasses should override this.
Level.init = function
	self.clear
	self.startPos = [2,2]
end function

// Clear the level entirely.  add a big empty space.
Level.clear = function(cols=32, rows=32)
	self.cols = cols
	self.rows = rows
	self.cells = Cell.make2dArray(cols, rows)
end function

Level.inBounds = function(col, row)
	return col >= 0 and col < self.cols and row >= 0 and row < self.rows
end function

// Add an extended wall, given a leftmost [col,row]
// point and a rightmost [col,row] point as viewed
// when looking at the wall.
Level.addLongWall = function(leftmost, rightmost)
	if leftmost[0] == rightmost[0] then
		x = leftmost[0]
		// vertical wall at x
		if leftmost[1] < rightmost[1] then
			for y in range(leftmost[1], rightmost[1]-1)
				self.cells[x][y].addWall dirW
			end for
		else
			for y in range(rightmost[1], leftmost[1]-1)
				self.cells[x][y].addWall dirE
			end for
		end if
	else if leftmost[1] == rightmost[1] then
		y = leftmost[1]
		// horizontal wall at y
		if leftmost[0] < rightmost[0] then
			for x in range(leftmost[0], rightmost[0]-1)
				self.cells[x][y].addWall dirN
			end for
		else
			for x in range(rightmost[0], leftmost[0]-1)
				self.cells[x][y].addWall dirS
			end for
		end if
	else
		qa.fail "walls must differ in only one dimension"
	end if
end function

// Add a double-sided wall (it doesn't matter which order
// you specify the endpoints in).
Level.addDoubleSidedWall = function(oneEnd, otherEnd)
	if oneEnd[0] == otherEnd[0] then
		// vertical wall
		if oneEnd[1] < otherEnd[1] then
			self.addLongWall oneEnd, otherEnd
			self.addLongWall [otherEnd[0]-1,otherEnd[1]], [oneEnd[0]-1,oneEnd[1]]
		else
			self.addLongWall otherEnd, oneEnd
			self.addLongWall [oneEnd[0]-1,oneEnd[1]], [otherEnd[0]-1,otherEnd[1]]
		end if
	else
		// horizontal wall
		if oneEnd[0] < otherEnd[0] then
			self.addLongWall otherEnd, oneEnd
			self.addLongWall [oneEnd[0],oneEnd[1]-1], [otherEnd[0],otherEnd[1]-1]
		else
			self.addLongWall oneEnd, otherEnd
			self.addLongWall [otherEnd[0],otherEnd[1]-1], [oneEnd[0],oneEnd[1]-1]
		end if
	end if
end function

// Add a box with the walls facing inward (e.g., for
// the outer walls of the map, or inside of a building).
Level.addInwardBox = function(left, bottom, width, height)
	top = bottom + height
	right = left + width
	self.addLongWall [left,bottom], [left,top]
	self.addLongWall [left,top-1], [right,top-1]
	self.addLongWall [right-1,top], [right-1,bottom]
	self.addLongWall [right,bottom], [left,bottom]
end function

// Add a box with the walls facing outward (a column or obstacle).
Level.addOutwardBox = function(left, bottom, width, height)
	top = bottom + height
	right = left + width
	self.addLongWall [left-1,top], [left-1,bottom]
	self.addLongWall [right,top], [left,top]
	self.addLongWall [right,bottom], [right,top]
	self.addLongWall [left,bottom-1], [right,bottom-1]
end function

// Add an inward-facing wall around the edge of the map.
Level.addOuterWall = function
	self.addInwardBox 0, 0, self.cols, self.rows
end function

// Draw this level to gfx in the given rectangular area.
Level.debugDraw = function(left=100, bottom=0, width=640, height=860)
	cellScale = min((width-30)/self.cols, (height-20)/self.rows)	
	for row in self.cells.indexes
		s = str(row)
		gfx.print s, left + 28 - s.len*8, bottom+20 + (row+0.2)*cellScale, color.silver, "small"
		rowCells = self.cells[row]
		for cell in rowCells
			cell.drawInMap left+30, bottom+20, cellScale, cellScale
		end for
	end for
	for col in self.cells[0].indexes
		s = str(col)
		gfx.print s, left+28 + (col+0.5)*cellScale - s.len*4, bottom+4, color.silver, "small"	
	end for
end function

doStandardDebugCheck = function(levelInstance)
	globals.lvl = levelInstance
	clear
	levelInstance.init
	levelInstance.debugDraw
end function

if locals == globals then doStandardDebugCheck(new Level)

	
