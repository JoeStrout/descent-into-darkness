// Binary Space Partitioning level generator.  Based loosely on:
// http://roguebasin.com/index.php/Basic_BSP_Dungeon_generation


import "miscUtil"
ensureImport "mathUtil"
ensureImport "listUtil"
ensureImport "mapUtil"
ensureImport "level"
ensureImport "wall"

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
	
	// Then add some *extra* passages so it's not a strict tree.
	self.addExtraPassages
	
	// Fix any tiny (size=1) rooms.
	self.fixTinyPassages
	
	// Finally, build walls based on the rock attribute and IDs.
	joined = {}  // set of [roomA,roomB] rooms already joined by a door
	for row in range(0, self.rows-1)
		for col in range(0, self.cols-1)
			cell = self.cells[col][row]
			if cell.rock then continue
			id = cell.roomID
			for dir in [dirS, dirE, dirN, dirW]
				nx = col + dirDx[dir]
				ny = row + dirDy[dir]
				if self.isRock(nx, ny) then
					cell.addWall dir
				else if self.roomID(nx, ny) != id then
					// if these rooms haven't already been joined,
					// then join them by a door; otherwise build a wall
					key = [id, self.roomID(nx, ny)]
					if not joined.hasIndex(key) then
						joined.push key
						cell.addWall dir, wall.Doorway
					else
						cell.addWall dir
					end if
				end if
			end for
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

// Subdivide if the given area is very large, generate each sub-area,
// and then connect them together.
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

BspLevel.addExtraPassages = function
	hSections = 4
	vSections = 4
	colsPerHSec = floor(self.cols / hSections)
	rowsPerVSec = floor(self.rows / vSections)
	for hsec in range(0, hSections-2)
		for vsec in range(0, vSections-2)
			self.connect hsec*colsPerHSec, vsec*rowsPerVSec, colsPerHSec, rowsPerVSec,
			  (hsec+1)*colsPerHSec, vsec*rowsPerVSec, colsPerHSec, rowsPerVSec
			self.connect hsec*colsPerHSec, vsec*rowsPerVSec, colsPerHSec, rowsPerVSec,
			  hsec*colsPerHSec, (vsec+1)*rowsPerVSec, colsPerHSec, rowsPerVSec
		end for
	end for
end function

BspLevel.digRoom = function(left, bottom, width, height)
	roomCells = []
	for col in range(left, left+width-1)
		for row in range(bottom, bottom+height-1)
			cell = self.cells[col][row]
			cell.rock = false
			cell.roomID = self.nextRoomID
			roomCells.push cell
		end for
	end for
	if rnd < 0.1 then
		// add a spider!
		loc = roomCells.any
		FlatDecal.make "shadow.png", loc, 0.4
		spider = Imposter.make("mobs/spider/", loc, 1)
		spider.pos[2] = -0.15	// (sits better on ground)
		spider.rotation = round(360 * rnd)
	end if
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

// Look for rooms of only 1 square.  Combine these with the smallest adjacent
// room.
BspLevel.fixTinyPassages = function
	roomSizes = {}	// key: room ID; value: number of squares with that ID
	roomLocs = {}	// key: room ID; value: [col,row] of some square in that room
	for row in range(0, self.rows-1)
		for col in range(0, self.cols-1)
			cell = self.cells[col][row]
			if cell.rock then continue
			id = cell.roomID
			roomSizes[id] = roomSizes.get(id, 0) + 1
			roomLocs[id] = [col, row]
		end for
	end for
	
	for kv in roomSizes
		if kv.value > 1 then continue
		colRow = roomLocs[kv.key]
		c = colRow[0]
		r = colRow[1]
		// OK, this room at colRow is of size 1.  Check each of its neighbors,
		// and find the ID of smallest neighboring room.
		bestID = -1
		bestSize = 9999
		for n in [[c+1,r], [c,r+1], [c-1,r], [c,r-1]]
			if n[0] < 0 or n[0] >= self.cols or n[1] < 0 or n[1] >= self.rows then continue
			ncell = self.cells[n[0]][n[1]]
			if ncell.rock then continue
			size = roomSizes[ncell.roomID]
			if size < bestSize then
				bestSize = size
				bestID = ncell.roomID
			end if
		end for
		// then change this room to match that ID
		self.cells[c][r].roomID = bestID
	end for
end function

if locals == globals then level.doStandardDebugCheck(new BspLevel)
