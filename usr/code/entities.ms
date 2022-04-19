
// State constants -- various states an Entity might be in.
kIdle = "Idle"
kWandering = "Wandering"
kChasing = "Chasing"
kAttacking = "Attacking"

//---------------------------------------------------------------
// Entity class: represents things that can move around
// in the game.  Typically these consist of an Imposter
// for whatever it is, and a FlatDecal for the shadow.
Entity = new updatable.Updatable
Entity.pos = null				// [x,y,z] position of the main
Entity.decorations = null		// list of parts we need to move around
Entity.shadow = null			// decoration representing the shadow
Entity.main = null				// main Imposter or whatever it is
Entity.rotation = 0				// direction the main is facing (in degrees)
Entity.cell = null				// which cell our position is in
Entity.health = 10				// how many hit points we have
Entity.state = kIdle			// kIdle, kWandering, etc.
Entity.stateStartTime = 0

Entity.init = function(cell, shadowScale = 0.4)
	super.init
	self.pos = [cell.col + 0.5, cell.row + 0.5, 0]

	self.shadow = new FlatDecal
	self.shadow.init self.pos[:], shadowScale
	self.shadow.sprite.image = images.load("textures/shadow.png")
	self.decorations = [self.shadow]
	
	self.cell = cell
	cell.entities.push self
end function

Entity.render = function(spriteList)
	for dec in self.decorations
		dec.render spriteList
	end for
end function

Entity.rotateTo = function(rotation)
	self.rotation = (rotation + 3600) % 360
	self.main.rotation = self.rotation
end function

Entity.forwardVec = function
	radians = self.rotation * pi/180
	return [cos(radians), sin(radians)]
end function

Entity.moveTo = function(x, y)
	self.pos[0] = x; self.pos[1] = y
	for d in self.decorations
		d.pos[0] = x; d.pos[1] = y
	end for
	self.shadow.updateCorners
	if floor(x) != self.cell.col or floor(y) != self.cell.row then
		self.cell.entities.removeVal self
		self.cell = lvl.cells[x][y]
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

Entity.enterState = function(newState)
	if newState == self.state then return false
	self.exitState newState
	self.state = newState
	self.stateStartTime = time
	return true
	// Subclasses should override this as needed, but remember
	// to call super.enterState at the top.
end function

Entity.exitState = function(toState)
	// Subclasses should override this as needed.
end function

Entity.timeInState = function
	return time - self.stateStartTime
end function

//---------------------------------------------------------------
// Mob
// This is the base class for most standard monsters.  A mob
// has all four standard states (kIdle, kWandering, kChasing,
// and kAttacking), with animations for each, and can move around
// the level.  For many common monsters, little or no custom code
// will be needed if they derive from Mob.
Mob = new Entity
Mob.idleSets = null		// idle frames (each one a set of images from different angles)
Mob.walkSets = null		// walk frames
Mob.runSets = null		// running frames
Mob.attackSets = null	// attack frames
Mob.attackDamage = 5	// hit points of damage we do to player
Mob.angry = false		// if true, attacks on site; if false, ignores player
Mob.curSets = null		// what set of frames we are currently using
Mob.frameNum = 0		// current frame (image set) we're showing
Mob.nextFrameTime = 0	// time at which we should go to the next frame
Mob.targetPos = null	// target position in kWander or kChase state

Mob.loadImageSets = function(partialPath)
	self.idleSets = []
	for i in range(1,8)
		set = images.loadSeries(partialPath + "-Idle" + i)
		if not set then break
		self.idleSets.push set
	end for
	
	self.walkSets = []
	for i in range(1,8)
		set = images.loadSeries(partialPath + "-Walk" + i)
		if not set then break
		self.walkSets.push set
	end for
	if not self.walkSets then self.walkSets = self.idleSets
	
	self.runSets = []
	for i in range(1,8)
		set = images.loadSeries(partialPath + "-Run" + i)
		if not set then break
		self.runSets.push set
	end for
	if not self.runSets then self.runSets = self.walkSets
	
	self.attackSets = []
	for i in range(1,8)
		set = images.loadSeries(partialPath + "-Attack" + i)
		if not set then break
		self.attackSets.push set
	end for
	if not self.attackSets then self.attackSets = self.runSets
end function

Mob.init = function(cell)
	super.init cell	, 0.2
	self.spawnPos = self.pos[:]
	
	self.main = new Imposter
	self.main.init [cell.col + 0.5, cell.row + 0.5, 0], 1
	self.main.sprite.localBounds = new Bounds
	self.main.sprite.localBounds.width = 80
	self.main.sprite.localBounds.height = 80
	self.decorations.push self.main

	self.startAnim self.idleSets
end function

display(1).mode = displayMode.text

Mob.startAnim = function(imageSets)
	self.curSets = imageSets
	self.frameNum = -1
	self.nextFrameNum = time - 0.1	// (ensures we immediately update)
end function

Mob.enterState = function(newState)
//	display(1).print self.state + " --> " + newState
	if not super.enterState(newState) then return
	if self.state == kIdle then
		self.startAnim self.idleSets
	else if self.state == kWandering then
		self.startAnim self.walkSets
		self.pickWanderTarget
	else if self.state == kChasing then
		self.startAnim self.runSets
	else if self.state == kAttacking then
		self.startAnim self.attackSets
	end if
end function

Mob.update = function(dt)
	if time > self.nextFrameTime then
		self.nextFrameTime = time + 0.3
		self.frameNum = (self.frameNum + 1) % self.curSets.len
		self.main.images = self.curSets[self.frameNum]
	end if
	
	if self.state == kIdle then
		if self.timeInState > 3 then
			self.enterState kWandering
		end if
	else if self.state == kWandering then
		if self.pos == self.targetPos then
			self.enterState kIdle
		else
			self.approach self.targetPos, dt
		end if
	else if self.state == kChasing then
		if self.pos == self.targetPos then
			self.enterState kAttack
		else
			self.approach self.targetPos, dt
		end if
	end if
end function

Mob.pickWanderTarget = function
	// For now:
//	self.targetPos = [self.pos[0] + 4*rnd-2, self.pos[1] + 4*rnd-2, self.pos[2]]
	if self.pos == self.spawnPos then
		self.targetPos = [self.pos[0] - 4, self.pos[1], self.pos[2]]
	else
		self.targetPos = self.spawnPos
	end if
end function

Mob.turnTowards = function(targetPos, dt)
	dx = targetPos[0] - self.pos[0]
	dy = targetPos[1] - self.pos[1]
	angleToTarget = atan(dy, dx) * 180/pi
	dAng = angleToTarget - self.rotation
	if dAng > 180 then
		dAng = dAng - 360
	else if dAng  < -180 then
		dAng = dAng + 360
	end if
	speed = 0
	if dAng > -90 and dAng < 90 then speed = 1 - abs(dAng/90)
	if abs(dAng) > 1 then
		// Turn towards the target.
		prevRot = self.rotation
		self.rotateTo mathUtil.moveTowards(self.rotation, self.rotation + dAng, 360*dt)
		//display(1).print "rot:" + round(prevRot) + "; angleToTarget:" + round(angleToTarget) + "; dAng:" + round(dAng) + "; new rot: " + round(self.rotation)
	end if
end function

Mob.approach = function(targetPos, dt)
	self.turnTowards targetPos, dt
	maxDist = 1 * dt
	if mathUtil.distance(self.pos, targetPos) < maxDist then
		self.pos[0] = targetPos[0]
		self.pos[1] = targetPos[1]
	else
		fwd = self.forwardVec.times(maxDist)
		self.moveTo self.pos[0] + fwd[0], self.pos[1] + fwd[1]
	end if
end function

//---------------------------------------------------------------
// Slime
// Small.  Squishy.  Squelchy.
Slime = new Mob
Slime.health = 5
Slime.loadImageSets "mobs/Slime/Slime"
Slime.init = function(cell)
	super.init cell
	self.shadow.setScale 0.2
	self.main.sprite.tint = "#AAFFAADD"
	self.main.pos[2] = -0.13	// (sits better on ground)
	
//	self.startAnim self.walkSets
//	self.state = "DEBUG"
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