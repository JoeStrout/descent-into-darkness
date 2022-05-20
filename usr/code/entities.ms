ensureImport "updatable"
ensureImport "images"
ensureImport "qa"
ensureImport "sounds"

// State constants -- various states an Entity might be in.
kIdle = "Idle"
kWandering = "Wandering"
kChasing = "Chasing"
kAttacking = "Attacking"

//---------------------------------------------------------------
// Entity class: represents things that can move around
// in the game.  Typically these consist of an Imposter
// for whatever it is, and a FlatDecal for the shadow.
Entity = new Updatable
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

Entity.playSound = function(sound)
	d = mathUtil.distance(self.pos, camera.pos)
	if d > 5 then return
	vol = 1/d
	pan = -sin(camera.relativeAngle(self.pos))
	sound.play vol, pan
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
end function

// Call this method to destroy an entity quickly and silently,
// e.g. when switching levels.
Entity.destroy = function
	super.die
	self.cell.entities.removeVal self
	self.shadow.die
	self.main.die
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
	self.playSound sounds.hit
	damage = player.stats.damage
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
Mob.damage = [2,6]		// hit points of damage we do to player
Mob.aggressive = false	// if true, attacks on site; if false, ignores player
Mob.curSets = null		// what set of frames we are currently using
Mob.frameNum = 0		// current frame (image set) we're showing
Mob.nextFrameTime = 0	// time at which we should go to the next frame
Mob.targetPos = null	// target position in kWander or kChase state
Mob.splatImage = "splat.png"
Mob.splatTint = "#444400"
Mob.splatScale = 0.35
Mob.walkSpeed = 0.5
Mob.runSpeed = 1
Mob.lastRenderTime = 0
Mob.lastRoarTime = 0
Mob.moveSound = null
Mob.roarSound = null
Mob.attackSound = null
Mob.deathSound = sounds.splat
Mob.xp = 5				// XP granted for killing this mob

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
	self.main.images = self.idleSets[0]
end function

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
		if self.roarSound and self.lastRoarTime < time - 10 then
			self.playSound self.roarSound
			self.lastRoarTime = time
		end if
	else if self.state == kAttacking then
		self.startAnim self.attackSets
		if self.attackSound then self.playSound self.attackSound
	end if
end function

Mob.update = function(dt)
	frameChanged = false
	if time > self.nextFrameTime then
		self.nextFrameTime = time + 0.3
		frameChanged = (self.frameNum >= 0)	// (doesn't count when coming from -1)
		self.frameNum = (self.frameNum + 1) % self.curSets.len
		self.main.images = self.curSets[self.frameNum]
	end if
	
	playerPos = camera.pos
	if self.state == kIdle then
		if self.aggressive and self.lastRenderTime > time - 0.2 then
			self.enterState kChasing
		else if self.timeInState > 3 then
			self.enterState kWandering
		end if
	else if self.state == kWandering then
		if self.aggressive and self.lastRenderTime > time - 0.2 then
			self.enterState kChasing
		else if self.pos == self.targetPos then
			self.enterState kIdle
		else
			self.approach self.targetPos, dt
			if frameChanged and self.frameNum==0 and self.moveSound then self.playSound self.moveSound
		end if
	else if self.state == kChasing then
		if manhattanDist(self.pos, playerPos) < 1 then
			self.enterState kAttacking
		else
			self.approach playerPos, dt
			if frameChanged and self.frameNum==0 and self.moveSound then self.playSound self.moveSound
		end if
	else if self.state == kAttacking then
		if frameChanged then
			if self.frameNum == 1 then self.applyAttack
			if self.frameNum == 0 then self.enterState kIdle
		end if
	end if
end function

Mob.applyAttack = function
	if mathUtil.distance(self.pos, camera.pos) > 1 then return	// missed!
	if self.damage isa number then
		dam = self.damage
	else
		dam = round(mathUtil.randRange(self.damage[0], self.damage[1]))
	end if
	if not dam then return
	
	player.takeDamage dam
end function

Mob.pickWanderTarget = function
	// Pick a random location within a few steps of our current place.
	possibilities = lvl.reachablePositions(self.pos).indexes
	choice = possibilities.any
	self.targetPos = [choice[0] + 0.5, choice[1] + 0.5, self.pos[2]]
end function

// Turn towards the given target position.
// Returns a suggested speed factor (0-1) that you might want to 
// use if you are trying to move towards that target.
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
	return speed
end function

// Turn towards the given target, and then move towards it.
Mob.approach = function(targetPos, dt)
	if self.state == kWandering then baseSpeed = self.walkSpeed else baseSpeed = self.runSpeed
	speed = baseSpeed * self.turnTowards(targetPos, dt)
	maxDist = speed * dt
	if mathUtil.distance(self.pos, targetPos) < maxDist then
		self.pos[0] = targetPos[0]
		self.pos[1] = targetPos[1]
	else
		fwd = self.forwardVec.times(maxDist)
		newx = self.pos[0] + fwd[0]
		newy = self.pos[1] + fwd[1]
		if floor(newx) != self.cell.col then
			if fwd[0] < 0 then dir = dirW else dir = dirE
			wall = self.cell.walls[dir]
			if wall != null and wall.blocksMovement then newx = self.pos[0]
		end if
		if floor(newy) != self.cell.row then
			if fwd[1] < 0 then dir = dirS else dir = dirN
			wall = self.cell.walls[dir]
			if wall != null and wall.blocksMovement then newy = self.pos[1]
		end if			
		self.moveTo newx, newy
	end if
end function

Mob.render = function(spriteList)
	self.lastRenderTime = time
	super.render spriteList
end function

Mob.hitBySpell = function(spell)
	if super.hitBySpell(spell) then
		self.aggressive = true
		return true
	end if
	return false
end function
	
Mob.die = function
	super.die
	if self.deathSound then self.playSound self.deathSound
	splat = FlatDecal.make("splat.png", self.cell, self.splatScale)
	splat.pos = self.pos
	splat.updateCorners
	splat.sprite.tint = self.splatTint
	player.gainXP self.xp
	
	if rnd < 0.5 then
		loot = items.randomLoot
		pickup = decorations.ItemPickup.make(loot, self.cell)
		pickup.pos = self.pos
	end if
end function

//---------------------------------------------------------------
// Slime
// Small.  Squishy.  Squelchy.
Slime = new Mob
Slime.level = 0
Slime.health = 5
Slime.loadImageSets "mobs/Slime/Slime"
Slime.walkSets.push Slime.walkSets[0]	// (add two extra frames to
Slime.walkSets.push Slime.idleSets[0]	//  the walk set)
Slime.levelColors = ["#AAFFAADD", "#FFFF88DD", "#FF6666DD", "#AAAAFFDD"]
Slime.instances = []	// (list of all slimes in the level)
Slime.splatScale = 0.2
Slime.moveSound = sounds.slimeMove
Slime.roarSound = sounds.slimeRoar
Slime.attackSound = sounds.slimeAttack

Slime.init = function(cell, level=0)
	super.init cell
	self.shadow.setScale 0.2
	self.main.pos[2] = -0.13	// (sits better on ground)
	self.setLevel level
	Slime.instances.push self
end function

Slime.destroy = function
	super.destroy
	Slime.instances.removeVal self
end function

Slime.setLevel = function(level)
	qa.assert level >= 0 and level < Slime.levelColors.len
	self.level = level
	self.health = 4 + 2^level
	self.main.sprite.tint = Slime.levelColors[level]
	self.aggressive = (level > 0)
	self.splatScale = 0.2 + 0.04*level
end function

Slime.splatTint = function
	return self.main.sprite.tint
end function

Slime.die = function
	super.die
	Slime.instances.removeVal self
	// When one slime dies, other slimes level up!
	qtyToUpgrade = 4
	Slime.instances.shuffle
	if Slime.instances.len > qtyToUpgrade then
		others = Slime.instances[:qtyToUpgrade]
	else
		others = Slime.instances
	end if
	for other in others
		if other.level+1 < Slime.levelColors.len then other.setLevel other.level+1
	end for
end function

//---------------------------------------------------------------
// Spider
// It jumps.  It hisses.  It bites.
Spider = new Mob
Spider.loadImageSets "mobs/spider/Spider"
Spider.health = 15
Spider.vz = 0
Spider.splatScale = 0.4
Spider.moveSound = sounds.spiderMove
Spider.roarSound = sounds.spiderRoar
Spider.attackSound = sounds.spiderAttack

Spider.init = function(cell)
	super.init cell
	self.main.pos[2] = -0.15	// (sits better on ground)
	self.main.sprite.localBounds.y = 20
end function
Spider.update = function(dt)
	super.update dt
	return
	
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


//---------------------------------------------------------------
// entities (module) methods
clearAll = function
	for i in Slime.instances.reverseIndexes
		Slime.instances[i].destroy
	end for
	for i in updatable.all.reverseIndexes
		item = updatable.all[i]
		if item isa Entity then item.destroy
	end for	
end function