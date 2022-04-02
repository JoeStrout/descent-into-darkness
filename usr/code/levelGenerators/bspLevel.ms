// Binary Space Partitioning level generator.  Based loosely on:
// http://roguebasin.com/index.php/Basic_BSP_Dungeon_generation


import "miscUtil"
ensureImport "mathUtil"
ensureImport "listUtil"
ensureImport "level"

randInt = function(min, maxPlus1)
	return floor(mathUtil.randRange(min, maxPlus1))
end function

BspLevel = new level.Level

BspLevel.init = function
	super.init
	
	// We'll use a boolean "rock" attribute on every cell to keep
	// track of which cells are solid rock, and which are walkable.
	// Initialize everything to rock.  We'll also use a "roomID"
	// attribute to keep track of which areas are separate rooms,
	// so we can join them by a thin wall if needed.
	for row in self.cells
		for cell in row
			cell.rock = true
			cell.roomID = 0
		end for
	end for
	self.nextRoomID = 1
	
	// Now dig the rooms and passages.
	self.generate
	
	// Finally, build walls based on the rock attribute.
	for row in range(0, self.rows-1)
		for col in range(0, self.cols-1)
			cell = self.cells[col][row]
			if cell.rock then continue
			id = cell.roomID
			if self.roomID(col+1,row) != id then cell.addWall dirE
			if self.roomID(col-1,row) != id then cell.addWall dirW
			if self.roomID(col,row+1) != id then cell.addWall dirN
			if self.roomID(col,row-1) != id then cell.addWall dirS
		end for
	end for

	Cell.fixCorners self.cells
end function

BspLevel.isRock = function(col, row)
	return col < 0 or col >= self.cols or row < 0 or row >= self.rows or
		self.cells[col][row].rock
end function

BspLevel.roomID = function(col, row)
	if col < 0 or col >= self.cols or row < 0 or row >= self.rows then
		return 0
	else
		return self.cells[col][row].roomID
	end if
end function

// Do one step of generation, i.e., subdivide if the given area is
// very large, generate each sub-area, and then connect them together.
BspLevel.generate = function(left=0, bottom=0, width=null, height=null)
	if width == null then width = self.cols - left
	if height == null then height = self.rows - bottom
	right = left + width
	top = bottom + height
	
	// figure out how to divide the room (if at all)
	divX = null
	divY = null
	if width > 6 then
		if height > 6 then
			// randomly divide in X or Y
			if rnd > 0.5 then
				divX = randInt(left+3, right-3)
			else
				divY = randInt(bottom+3, top-3)
			end if
		else
			// wide but not tall; divide in X
			divX = randInt(left+3, right-3)
		end if
	else if height > 6 then
		// tall but not wide; divide in Y
		divY = randInt(bottom+3, top-3)
	end if

	if divX then
		// divide horizontally
		self.generate left, bottom, divX-left, height
		self.generate divX, bottom, right-divX, height
		self.connect left, bottom, divX-left, height,
					 divX, bottom, right-divX, height
	else if divY then
		// divide vertically
		self.generate left, bottom, width, divY-bottom
		self.generate left, divY, width, top-divY
		self.connect left, bottom, width, divY-bottom,
					 left, divY, width, top-divY
	else	
		// we have reached our minimum area -- dig a room!
		roomLeft = randInt(left, left+width/2)
		roomWidth = randInt(2, right-roomLeft)
		roomBottom = randInt(bottom, bottom+height/2)
		roomHeight = randInt(2, top-roomBottom)
		self.digRoom roomLeft, roomBottom, roomWidth, roomHeight
	end if
	
end function

BspLevel.digRoom = function(left, bottom, width, height)
	for col in range(left, left+width-1)
		for row in range(bottom, bottom+height-1)
			cell = self.cells[col][row]
			cell.rock = false
			cell.roomID = self.nextRoomID
		end for
	end for
	self.startPos = [round(left+width/2), round(bottom+height/2)]
	self.nextRoomID = self.nextRoomID + 1
end function

BspLevel.connect = function(left1, bottom1, width1, height1, left2, bottom2, width2, height2)
	// pick a random point in area 1
	ptA = self.findAnyRoomIn(left1, bottom1, width1, height1)
	// find the closest point in area 2 to that point
	ptB = self.findClosestRoomPointTo(ptA, left2, bottom2, width2, height2)
	// then, find the closest point in area 1 to the point in area 2
	ptA = self.findClosestRoomPointTo(ptB, left1, bottom1, width1, height1)
	// then connect the points
	for x in range(ptA[0], ptB[0])
		cell = self.cells[x][ptA[1]]
		if not cell.rock then continue
		cell.rock = false
		cell.roomID = self.nextRoomID
	end for
	for y in range(ptA[1], ptB[1])
		cell = self.cells[ptB[0]][y]
		if not cell.rock then continue
		cell.rock = false
		cell.roomID = self.nextRoomID
	end for
	self.nextRoomID = self.nextRoomID + 1
end function

BspLevel.findAnyRoomIn = function(left, bottom, width, height)
	options = []
	for col in range(left, left+width-1)
		for row in range(bottom, bottom+height-1)
			if not self.cells[col][row].rock then options.push [col,row]
		end for
	end for
	return options.any
end function

BspLevel.findClosestRoomPointTo = function(target, left, bottom, width, height)
	best = null
	bestDist = 9999
	for col in range(left, left+width-1)
		for row in range(bottom, bottom+height-1)
			if self.cells[col][row].rock then continue
			dist = abs(col - target[0]) + abs(row - target[1])
			if not best or dist < bestDist then
				best = [col, row]
				bestDist = dist
			end if
		end for
	end for
	return best
end function

if locals == globals then level.doStandardDebugCheck(new BspLevel)
