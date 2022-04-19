
//---------------------------------------------------------------
// Entity class: represents things that can move around
// in the game.  Typically these consist of an Imposter
// for whatever it is, and a FlatDecal for the shadow.
Entity = new updatable.Updatable
Entity.pos = null				// [x,y,z] position of the main
Entity.decorations = null		// list of parts we need to move around
Entity.shadow = null			// decoration representing the shadow
Entity.main = null				// main Imposter or whatever it is
Entity.rotation = 0				// direction the main is facing
Entity.cell = null				// which cell our position is in
Entity.health = 10				// how many hit points we have

Entity.init = function(cell)
	super.init
	self.pos = [cell.col + 0.5, cell.row + 0.5, 0]
	self.shadow = FlatDecal.make("shadow.png", cell, 0.4)
	self.cell = cell
	cell.entities.push self
end function

Entity.rotateTo = function(rotation)
	self.main.rotation = rotation
end function

Entity.moveTo = function(x, y)
	self.pos[0] = x; self.pos[1] = y
	for d in self.decorations
		d.pos[0] = x; d.pos[1] = y
	end for
	if floor(x) != self.cell.col or floor(y) != self.cell.row then
		self.cell.entities.removeVal self
		self.cell = lvl.cell[x][y]
		self.cell.entities.push self
	end if
end function

// Call this method when an entity dies.  It should
// leave behind a corspe/smear/etc., drop loot, and 
// then remove this entity from the game.
Entity.die = function
	super.die
	self.cell.entities.removeVal self
	self.shadow.die
	self.main.die
	
	FlatDecal.make("splat.png", self.cell, 0.4)
end function

// Determine whether the given spell hits this entity.
// If so, return true and apply damage to self.
// Otherwise, return false.
Entity.hitBySpell = function(spell)
	myDist = renderer.camera.distance(self.pos)
	spellDist = renderer.camera.distance(spell.pos)
	if spellDist < myDist then return false
	if not self.main.sprite.overlaps(spell.billboard.sprite) then return false
	// We've been hit by this spell!
	sounds.hit.play
	damage = 5
	tf = decorations.TextFloater.make(self.cell, self.pos.plus([0,0,0.25]),
	    "-" + damage, color.red)
	self.health = self.health - damage
	if self.health <= 0 then self.die
	return true
end function

//---------------------------------------------------------------
// Slime
// Small.  Squishy.  Squelchy.
Slime = new Entity
Slime.health = 5
Slime.frameNum = 0
Slime.nextFrameTime = 0
Slime.init = function(cell)
	super.init cell
	self.shadow.setScale 0.2
	self.main = Imposter.make("mobs/Slime/Slime-Idle1", cell, 1)
	self.idleSets = [self.main.images]
	self.idleSets.push images.loadSeries("mobs/Slime/Slime-Idle2")
	self.main.sprite.tint = "#AAFFAADD"
	self.decorations = [self.shadow, self.main]
	self.main.pos[2] = -0.15	// (sits better on ground)
end function
Slime.update = function(dt)
	if time > self.nextFrameTime then
		self.nextFrameTime = time + 0.3
		self.frameNum = (self.frameNum + 1) % 2
		self.main.images = self.idleSets[self.frameNum]
	end if		
end function

//---------------------------------------------------------------
// Spider
// It jumps.  It hisses.  It bites.
Spider = new Entity
Spider.health = 15
Spider.vz = 0
Spider.init = function(cell)
	super.init cell
	self.main = Imposter.make("mobs/spider/Spider", cell, 1)
	self.decorations = [self.shadow, self.main]
	self.main.pos[2] = -0.15	// (sits better on ground)
end function
Spider.update = function(dt)
	self.vz = self.vz - 5 * dt
	y = self.main.pos[2] + self.vz * dt
	if y < -0.15 then
		y = -0.15
		self.vz = 2+rnd
	end if
	self.main.pos[2] = y
	self.shadow.setScale 0.4 - y*0.2
	self.shadow.sprite.tint = color.lerp(color.black, color.clear, y)
end function