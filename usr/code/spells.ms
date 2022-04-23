// This module defines spells the player (and maybe mobs?) can cast,
// and has all the code for updating them and applying their effects.

import "miscUtil"
ensureImport "decorations"
ensureImport "images"
ensureImport "renderer"
ensureImport "updatable"

Spell = new updatable.Updatable
Spell.pos = null		// [x,y,z] vector
Spell.billboard = null
Spell.velocity = null	// [x,y,z] vector
Spell.startTime = 0
Spell.lifetime = 1.5
Spell.cell = null

Spell.init = function(pos3d)
	super.init
	self.velocity = [0,0,0]
	self.billboard = new Billboard
	self.billboard.init pos3d, 0.5
	self.billboard.sprite.image = images.sparkle
	
	bounds = new Bounds
	bounds.width = images.sparkle.width * 0.5
	bounds.height = images.sparkle.height * 0.5	
	self.billboard.sprite.localBounds = bounds
	
	self.billboard.sizeFromBottom = false
	self.cell = lvl.cells[pos3d[0]][pos3d[1]]
	self.cell.decorations.push self.billboard
	self.startTime = time
	//print "Initialized spell at " + pos3d
end function

Spell.die = function
	super.die
	pos = self.billboard.pos
	self.cell.decorations.removeVal self.billboard
end function

Spell.update = function(dt=0.1)
	// check spell lifetime
	if time > self.startTime + self.lifetime then
		self.die
		return
	end if
	
	// update sprite for nice sparkly effect
	self.billboard.sprite.rotation = 45 * floor(rnd*8)
	self.billboard.height = 0.3 + 0.4*rnd
	
	// move forward
	pos = self.billboard.pos
	oldPos = pos[:]
	pos.add self.velocity.times(dt)
	newCol = floor(pos[0])
	newRow = floor(pos[1])

	// check for hitting an entity
	cellsToCheck = [self.cell]
	if lvl.inBounds(newCol, newRow) and (newCol != self.cell.col or newRow != self.cell.row) then 
		cellsToCheck.push lvl.cells[newCol][newRow]
	end if
	// (ToDo: figure out neighboring cells we'd better check)
	for c in cellsToCheck
		for e in c.entities
			if e.hitBySpell(self) then
				self.die
				return
			end if
		end for
	end for
	
	// if hit floor or ceiling, we're done
	if pos[2] < 0 or pos[2] > 1 then
		self.die
		return
	end if
	// check for hitting a wall
	hitPt = self.cell.lineSegIntersect(oldPos, pos)
	if hitPt then
		//print "Hit wall at " + hitPt
		self.die
		return
	end if

	// make sure still in bounds
	if not lvl.inBounds(newCol, newRow) then
		self.die
		return
	end if
	
	// update which cell we're in
	if newCol != self.cell.col or newRow != self.cell.row then
		// remove from the old cell, and add ot the new one
		self.cell.decorations.removeVal self.billboard
		self.cell = lvl.cells[newCol][newRow]
		self.cell.decorations.push self.billboard
	end if
end function

// spell.cast: cast a spell, using the renderer camera as the origin
// and direction.
cast = function
	sp = new Spell
	forward = renderer.camera.forwardVec
	startPos = renderer.camera.pos[:]
	startPos[2] = startPos[2] - 0.2
	startPos.add forward.times(0.15)
	sp.init startPos
	sp.velocity = forward.times(20)
end function
