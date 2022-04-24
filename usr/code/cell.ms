// The Cell class represents one square of a level, including any
// walls, decorations, and entities in that square.

ensureImport "wall"

// Cell class: represents one cell of the map.
globals.Cell = {}
// Each cell knows its own row and column.
Cell.col = null
Cell.row = null
// Cell.walls: the walls of this cell.  May be null where there is no wall.
Cell.walls = null  // [N, S, E, W]
// Cell.decorations: a list of Decoration objects in this cell.
// A decoration is any object that knows how to render itself.
Cell.decorations = null
// Cell.entities: a list of entities that are at least partially in this cell.
// Entities are like decorations, except that they generally move around and
// may span more than one cell.
Cell.entities = null
// Positions of our four corners on the floor, in order: SW, SE, NE, NW
Cell.cornerPos = null
// Rendering data.
Cell.angles = null		// cam-relative angle of each corner, in floor-draw order
Cell.minAngle = 0		// minimum camera-relative angle among our corners
Cell.maxAngle = 0		// maximum cam-relative angle
Cell.visible = false	// whether it is within the camera's view 
Cell.minDistSeen = 999	// min distance at which this cell has been rendered

// Initialize a cell.
Cell.init = function(col, row)
	self.col = col
	self.row = row
	self.walls = [null]*4
	self.decorations = []
	self.entities = []
	self.cornerPos = [[col,row,0], [col+1,row,0], [col+1,row+1,0], [col,row+1,0]]
	self.center = [col+0.5, row+0.5, 0]
	self.angles = [0]*4
end function

// Convenience method to add a wall to a cell.
// Note that the wall so added is inset a bit, and will not join neatly
// to form a corner with a neighboring wall (but see Cell.fixCorners).
Cell.addWall = function(dir, wallClass=null)
	if wallClass == null then wallClass = Wall
	w = new wallClass
	h = 0.05  // inset of wall from edge of cell
	if dir == dirS then
		w.init [self.col+1, self.row+h], [self.col, self.row+h], self
	else if dir == dirW then
		w.init [self.col+h, self.row], [self.col+h, self.row+1], self
	else if dir == dirN then
		w.init [self.col, self.row+1-h], [self.col+1, self.row+1-h], self
	else
		w.init [self.col+1-h, self.row+1], [self.col+1-h, self.row], self
	end if

	self.walls[dir] = w
end function

// Method to call on a 2d array of cells, to go through and fix up all
// the corners so that the walls join neatly.
Cell.fixCorners = function(cells)
	maxRow = cells.len - 1
	maxCol = cells[0].len - 1
	for col in cells.indexes
		for row in cells[col].indexes
			w = cells[col][row].walls
			
			// first, fix inner corners (easy)
			if w[dirN] and w[dirE] then
				w[dirN].p[1][0] = w[dirE].p[0][0]
				w[dirE].p[0][1] = w[dirN].p[1][1]
			end if
			if w[dirE] and w[dirS] then
				w[dirE].p[1][1] = w[dirS].p[0][1]
				w[dirS].p[0][0] = w[dirE].p[1][0]
			end if
			if w[dirS] and w[dirW] then
				w[dirS].p[1][0] = w[dirW].p[0][0]
				w[dirW].p[0][1] = w[dirS].p[1][1]
			end if
			if w[dirW] and w[dirN] then
				w[dirW].p[1][1] = w[dirN].p[0][1]
				w[dirN].p[0][0] = w[dirW].p[1][0]
			end if
			
			// then, fix outer corners (trickier)
			for wallDir in range(0,3)
				if not w[wallDir] then continue
				dir2 = (wallDir+1) % 4
				x2 = col + dirDx[wallDir] - dirDx[dir2]
				y2 = row + dirDy[wallDir] - dirDy[dir2]
				if x2 < 0 or x2 > maxCol or y2 < 0 or y2 > maxRow then continue
				w2 = cells[x2][y2].walls
				if not w2[dir2] then continue
				if w[(wallDir+3)%4] then continue
				if cells[x2][y2].walls[(wallDir+2)%4] then continue
				if wallDir == dirN then
					w[wallDir].p[1][0] = w2[dirW].p[0][0]
					w2[dirW].p[0][1] = w[dirN].p[1][1]
				else if wallDir == dirE then
					w[dirE].p[1][1] = w2[dirN].p[0][1]
					w2[dirN].p[0][0] = w[dirE].p[1][0]
				else if wallDir == dirS then
					w[dirS].p[1][0] = w2[dirE].p[0][0]
					w2[dirE].p[0][1] = w[dirS].p[1][1]
				else
					w[dirW].p[1][1] = w2[dirS].p[0][1]
					w2[dirS].p[0][0] = w[dirW].p[1][0]
				end if
			end for
						
			// finally, cap any freestanding walls
			if w[dirE] and col < maxCol and cells[col+1][row].walls[dirW]then
				// vertical (N/S) wall
				if not w[dirS] and row > 0 and
				  not cells[col+1][row-1].walls[dirN] and
				  not cells[col][row-1].walls[dirE] then
					// Create the cap as a freestanding wall,
					// and push it on the decoration list for the cell
					cap = Wall.make(w[dirE].p[1], cells[col+1][row].walls[dirW].p[0])
					cells[col][row].decorations.push cap
					// if we needed to, we could add it to both cells:
					//cells[col+1][row].decorations.push cap				
					// but it seems like it's not necessary
				end if
				if not w[dirN] and row < maxRow and
				  not cells[col+1][row+1].walls[dirS] and
				  not cells[col][row+1].walls[dirE] then
					cap = Wall.make(cells[col+1][row].walls[dirW].p[1], w[dirE].p[0])
					cells[col][row].decorations.push cap
				end if
			end if
			if w[dirN] and row < maxRow and cells[col][row+1].walls[dirS] then
				// vertical (E/W) wall
				if not w[dirW] and col > 0 and
				  not cells[col-1][row+1].walls[dirE] and
				  not cells[col-1][row].walls[dirN] then
					cap = Wall.make(cells[col][row+1].walls[dirS].p[1], w[dirN].p[0])
					cells[col][row].decorations.push cap
				end if
				if not w[dirE] and col < maxCol and
				  not cells[col+1][row+1].walls[dirW] and
				  not cells[col+1][row].walls[dirN] then
					cap = Wall.make(w[dirN].p[1], cells[col][row+1].walls[dirS].p[0])
					cells[col][row].decorations.push cap
				end if				
			end if

		end for
	end for
end function


// Calculate the camera-relative angles of the four corners of this cell,
// along with our min/max angles, and whether we are possibly visible.
Cell.calcAngles = function(containsCamera=false)
	self.angles[0] = camera.relativeAngle(self.cornerPos[0])
	self.angles[1] = camera.relativeAngle(self.cornerPos[1])
	self.angles[2] = camera.relativeAngle(self.cornerPos[2])
	self.angles[3] = camera.relativeAngle(self.cornerPos[3])
	anglesCopy = self.angles[:]
	anglesCopy.sort
	self.minAngle = anglesCopy[0]
	self.maxAngle = anglesCopy[3]
		
	if containsCamera then
		self.visible = true
		return
	end if
	
	angSpan = self.maxAngle - self.minAngle
	if angSpan > pi then		// behind us
		self.visible = false
	else
		minAng = camera.angleRad - camera.halfFovRad	// ToDo: cache this
		maxAng = camera.angleRad + camera.halfFovRad
		if maxAng < minAng or minAng > maxAng then	// out of view
			self.visible = false
		else
			dist = camera.distance(self.cornerPos[0])
			if dist > 15 then
				// too far
				self.visible = false
			else
				self.visible = true
			end if
		end if
	end if
end function

// Write the visible walls of this cell to the given depth buffer.
// Return whether we found any spots in the depth buffer that we 
// could actually write to (i.e., not occluded by something closer).
Cell.writeToDepthBuffer = function(depthBuf)
	actuallyVisible = false
	for wallIdx in [0,1,2,3]		
		nextIdx = (wallIdx+1) % 4
		angLeft = self.angles[nextIdx]
		angRight = self.angles[wallIdx]
		if angRight > camera.halfFovRad or angLeft < -camera.halfFovRad then continue
		x0 = round(camera.screenX(angLeft))
		if x0 < 0 then x0 = 0
		x1 = round(camera.screenX(angRight))
		if x1 > 959 then x1 = 959
		if x0 > x1 then continue
		writeIt = (self.walls[wallIdx] != null and self.walls[wallIdx].blocksVision)
		for x in range(x0, x1)
			if not depthBuf[x] then
				actuallyVisible = true
				if writeIt then depthBuf[x] = true else break
			end if
		end for
	end for
	if actuallyVisible then
		dist = camera.distance(self.center)
		if dist < self.minDistSeen then self.minDistSeen = dist
	end if
	return actuallyVisible
end function

// Push the visible neighbors of this cell onto the given to-do list
// (but only if they don't already have the toDo flag set; and then 
// set it, so we never push the same cell twice in one render cycle).
Cell.pushVisibleNeighbors = function(cellGrid, toDoList)
	for wallIdx in [0,1,2,3]
		// The wall is visible (facing the camera) if its first angle
		// is greater than (?) the second.
		nextIdx = (wallIdx+1) % 4
		if self.angles[wallIdx] < self.angles[(wallIdx+1) % 4] then
			// A Wall is opaque if its has blocksVision == true.
			// So, the neighbor here is visible if wall == null
			// or not wall.blocksVision.
			if self.walls[wallIdx] == null or not self.walls[wallIdx].blocksVision then
				nx = self.col + dirDx[wallIdx]
				ny = self.row + dirDy[wallIdx]
				if nx >= 0 and ny >= 0 and 
				  nx < cellGrid.len and ny < cellGrid[0].len and
				  not cellGrid[nx][ny].toDo then
					cellGrid[nx][ny].toDo = true
					toDoList.push cellGrid[nx][ny]
				end if
			end if
		end if
	end for
end function	

// Build and return a 2D array of initialized cells (i.e. a blank map).
Cell.make2dArray = function(columns, rows)
	result = list.init2d(columns, rows)
	for col in range(0, columns-1)
		for row in range(0, rows-1)
			c = new Cell
			c.init col, row
			result[col][row] = c
		end for
	end for
	return result
end function

Cell.render = function(spriteList)
	// draw each wall
	for w in self.walls
		if w then w.render spriteList
	end for
	for dec in self.decorations
		dec.render spriteList
	end for
	for ent in self.entities
		ent.render spriteList
	end for
end function

Cell.debugDraw = function(left, bottom, scaleX=20, scaleY=20)
	if self.hasIndex("rock") and self.rock then
		gfx.fillRect left + self.col*scaleX, bottom + self.row * scaleY, 
			  scaleX-1, scaleY-1, color.gray
	else
		gfx.setPixel left + self.col*scaleX, bottom + self.row * scaleY, color.gray
	end if
	for w in self.walls
		if not w then continue
		w.drawInMap left, bottom, scaleX, scaleY
	end for
	for d in self.decorations
		d.drawInMap left, bottom, scaleX, scaleY
	end for
end function

Cell.drawInMap = function(left, bottom, scaleX=20, scaleY=20)
	if not self.decorations then
		if self.minDistSeen > 10 or (self.hasIndex("rock") and self.rock) then return
	end if
	if self.minDistSeen < 4 then
		c = "#88888888"
	else
		c = color.lerp("#88888888", "#88888800", (self.minDistSeen-4)/5)
	end if
	gfx.fillRect left + self.col*scaleX, bottom + self.row * scaleY, 
	  scaleX, scaleY, c
	for w in self.walls
		if not w then continue
		w.drawInMap left, bottom, scaleX, scaleY
	end for
end function

// Check whether the given 3D ray intersects any wall of this cell.
// IMPORTANT: we do not count hitting a wall of the cell from
// the *backside* (i.e. outside of the cell).  Just like with 
// rendering, walls are one-sided and you can only hit them from
// the inside.
Cell.lineSegIntersect = function(linePtA, linePtB)
	dx = linePtB[0] - linePtA[0]; dy = linePtB[1] - linePtA[1]
	col = self.col; row = self.row
	bestT = 1
	if dx > 0 and self.walls[dirE] then		// check east wall
		t = mathUtil.lineIntersectProportion(linePtA, linePtB, [col+1,row], [col+1,row+1])
		if t > 0 and t < bestT and self.walls[dirE].blocksSpell then bestT = t
	end if
	if dx < 0 and self.walls[dirW] then		// check west wall
		t = mathUtil.lineIntersectProportion(linePtA, linePtB, [col,row], [col,row+1])
		if t > 0 and t < bestT and self.walls[dirW].blocksSpell then bestT = t
	end if
	if dy > 0 and self.walls[dirN] then		// check north wall
		t = mathUtil.lineIntersectProportion(linePtA, linePtB, [col,row+1], [col+1,row+1])
		if t > 0 and t < bestT and self.walls[dirN].blocksSpell then bestT = t
	end if
	if dy < 0 and self.walls[dirS] then		// check south wall
		t = mathUtil.lineIntersectProportion(linePtA, linePtB, [col,row], [col+1,row])
		if t > 0 and t < bestT and self.walls[dirS].blocksSpell then bestT = t
	end if
	if bestT >= 1 then return null
	hitPt = linePtA.plus(linePtB.minus(linePtA).times(bestT))
	return hitPt
end function
