// Generator for semi-linear cave-like levels.  Based loosely on:
// http://roguebasin.com/index.php/Basic_directional_dungeon_generation

// This is working sort-of OK, but it has a couple of problems:
//	1. It often generates long sight lines that drag the framerate down.
//	2. It does not always generate fully connected caves, so you can
//		get stuck unable to reach some parts of the map.


import "miscUtil"
import "mathUtil"
ensureImport "level"

randInt = function(halfRange)
	return round(halfRange * 2 * (rnd - 0.5))
end function

CaveLevel = new level.Level

CaveLevel.init = function
	super.init
	
	// We'll use a boolean "rock" attribute on every cell to keep
	// track of which cells are solid rock, and which are walkable.
	// Initialize everything to rock.
	for row in self.cells
		for cell in row
			cell.rock = true
		end for
	end for
	
	// Now dig the cave.
	self.startPos = [round(self.cols/2), 1]
	self.digCave self.startPos, [0,1]
	self.digCave [1, round(self.rows/2)], [1,0]
	
	// ToDo: ensure that all cells are connected.
	
	// Finally, build walls based on the rock attribute.
	for row in range(1, self.rows-2)
		for col in range(1, self.cols-2)
			cell = self.cells[col][row]
			if cell.rock then continue
			if self.cells[col+1][row].rock then cell.addWall dirE
			if self.cells[col-1][row].rock then cell.addWall dirW
			if self.cells[col][row+1].rock then cell.addWall dirN
			if self.cells[col][row-1].rock then cell.addWall dirS
		end for
	end for

	Cell.fixCorners self.cells
end function

CaveLevel.dig = function(col, row)
	// we'll avoid digging the outermost column and row of rooms,
	// to avoid edge cases and generally make our lives easier.
	if col > 0 and col < self.cols-1 and row > 0 and row < self.rows-1 then
		self.cells[col][row].rock = false
	end if
end function

CaveLevel.undig = function(col, row)
	if col > 0 and col < self.cols-1 and row > 0 and row < self.rows-1 then
		self.cells[col][row].rock = true
	end if
end function

CaveLevel.addColumn = function(col, row)
	// put the rock BACK at the given col, row, but dig all
	// around it so that it doesn't end up blocking a passage
	for i in range(col-1, col+1)
		for j in range(row-1, row+1)
			self.dig i,j
		end for
	end for
	self.undig col, row
end function

// This function digs one cave passage, setting cell.rock = false
// for all the walkable cells we dig.
//	startPos: [col, row] position at which to start
//	direction: [dx, dy] position to move each step
//	roughness: how much the width varies from step to step (0-1)
//	windyness: how much the cave wanders back and forth (0-1)
CaveLevel.digCave = function(startPos, direction, roughness=0.5, windyness=0.5)
	pos = startPos[:]
	width = floor(2 + 3*rnd)
	horizontalSection = (abs(direction[0]) < abs(direction[1]))
	if horizontalSection then
		stepsLeft = abs(self.rows-1 - pos[1])
	else
		stepsLeft = abs(self.cols-1 - pos[0])
	end if
	for step in range(1, stepsLeft)
		if horizontalSection then
			// clear a section of rock
			for x in range(round(pos[0]-width/2), round(pos[0]+width/2))
				self.dig x, pos[1]
			end for
			// maybe put back a column here and there
			if rnd*20 < width then
				self.addColumn pos[0] + randInt(width/3), pos[1]
			end if
			// adjust position for windyness
			pos[0] = pos[0] + randInt(windyness * 6)
		else
			// clear a section of rock
			for y in range(round(pos[1]-width/2), round(pos[1]+width/2))
				self.dig pos[0], y
			end for
			// maybe put back a column here and there
			if rnd*20 < width then
				self.addColumn pos[0], pos[1]+randInt(width/3)
			end if
			// adjust position for windyness
			pos[1] = pos[1] + randInt(windyness * 6)
		end if
		// advance
		pos[0] = mathUtil.clamp(pos[0] + direction[0], 1, self.cols-1)
		pos[1] = mathUtil.clamp(pos[1] + direction[1], 1, self.rows-1)
		// adjust width for roughness
		width = mathUtil.clamp(width + randInt(roughness*6), 3, 8)
	end for
end function


if locals == globals then level.doStandardDebugCheck(new CaveLevel)
