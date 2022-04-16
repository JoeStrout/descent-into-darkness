// This module defines spells the player (and maybe mobs?) can cast,
// and has all the code for updating them and applying their effects.

import "miscUtil"
ensureImport "decorations"
ensureImport "images"
ensureImport "renderer"

Spell = {}
Spell.pos = null		// [x,y,z] vector
Spell.billboard = null
Spell.velocity = null	// [x,y,z] vector
Spell.instances = []
Spell.startTime = 0
Spell.lifetime = 1.5
Spell.cell = null

Spell.init = function(pos3d)
	self.velocity = [0,0,0]
	self.billboard = new Billboard
	self.billboard.init pos3d, 0.5
	self.billboard.sprite.image = images.sparkle
	self.billboard.sizeFromBottom = false
	self.cell = lvl.cells[pos3d[0]][pos3d[1]]
	self.cell.decorations.push self.billboard
	self.startTime = time
	Spell.instances.push self
	//print "Initialized spell at " + pos3d
end function

Spell.die = function
	pos = self.billboard.pos
	self.cell.decorations.removeVal self.billboard
	Spell.instances.removeVal self
end function

Spell.update = function(dt=0.1)
	if time > self.startTime + self.lifetime then
		self.die
		return
	end if
	
	self.billboard.sprite.rotation = 45 * floor(rnd*8)
	self.billboard.height = 0.3 + 0.4*rnd
	pos = self.billboard.pos
	oldPos = pos[:]
	pos.add self.velocity.times(dt)
	if pos[2] < 0 or pos[2] > 1 then
		self.die
		return
	end if
	hitPt = self.cell.lineSegIntersect(oldPos, pos)
	if hitPt then
		//print "Hit wall at " + hitPt
		self.die
		return
	end if
	newCol = floor(pos[0])
	newRow = floor(pos[1])
	if newCol != self.cell.col or newRow != self.cell.row then
		if not lvl.inBounds(newCol, newRow) then
			self.die
		else
			// remove from the old cell, and add ot the new one
			self.cell.decorations.removeVal self.billboard
			self.cell = lvl.cells[pos[0]][pos[1]]
			self.cell.decorations.push self.billboard
		end if
	end if
end function

// spell.cast: cast a spell, using the renderer camera as the origin
// and direction.
cast = function
	sp = new Spell
	forward = renderer.camera.forwardVec
	startPos = renderer.camera.pos[:]
	startPos[2] = startPos[2] - 0.2
	startPos.add forward.times(0.5)
	sp.init startPos
	sp.velocity = forward.times(2)
end function

// spell.update: main update method that should be called from the main 
// loop.  Update all current spells, including their display.
update = function(dt=0.1)
	for sp in Spell.instances
		sp.update dt
	end for
end function