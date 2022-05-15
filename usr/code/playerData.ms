ensureImport "hud"
ensureImport "sounds"
ensureImport "mathUtil"
ensureImport "inventoryUI"
ensureImport "stats"
ensureImport "mapUtil"

globals.player = {}
player.name = "PLAYER NAME"

// Base stats: what the player has inherently, i.e. without the
// effects of any equipment, magic, etc.
player.baseStats = new Stats
player.baseStats.health = 8
player.baseStats.maxHealth = 10
player.baseStats.mana = 10
player.baseStats.maxMana = 10
player.baseStats.damage = 1		// affects how much damage offensive spells do
player.baseStats.manaRegen = 1	// affects how quickly mana regenerates
player.baseStats.toughness = 10	// reduces damage from physical attacks
player.baseStats.elemFire = 0		// bonus/penalty in fire attacks
player.baseStats.elemCold = 0		// bonus/penalty in cold attacks
player.baseStats.elemInfect = 0	// bonus/penalty in infection attacks

// Stats: the player's current *effective* stats taking into account
// equipment and status effects.  Call player.updateStats to update.
player.stats = new player.baseStats

player.level = 0
player.xp = 0
player.gold = 0

player.initialize = function
	// Create our initial items:
	staff = Item.make("greenStaffglow")
	staff.unusedCells = [[1,0], [0,2]]
	staff.stats.damage = 3
	inventoryUI.pickUp staff

	inventoryUI.pickUp Item.make("dagger")
	inventoryUI.pickUp Item.make("dagger")
	inventoryUI.pickUp items.HealthPotion.make
	inventoryUI.pickUp items.HealthPotion.make
	inventoryUI.pickUp Item.make("yellowGemstone")
	inventoryUI.pickUp Item.make("yellowGemstone")
	inventoryUI.pickUp items.ManaRing.make
	inventoryUI.pickUp items.Boots.make
	inventoryUI.pickUp items.Boots.make("shoes")
	inventoryUI.pickUp items.Garment.make("blueRobe")
	inventoryUI.pickUp items.Headgear.make("headpiece")	
	inventoryUI.pickUp items.Food.make("apple")
	
	self.updateStats
end function

player.updateStats = function
	player.stats = new player.baseStats
	for slot in inventoryUI.equipmentSlots
		item = slot.contents
		if item == null then continue
		itemStats = item.stats
		player.stats.maxHealth = player.stats.maxHealth + itemStats.get("maxHealth")
		player.stats.maxMana = player.stats.maxMana + itemStats.get("maxMana")
		player.stats.damage = player.stats.damage + itemStats.get("damage")
		player.stats.manaRegen = player.stats.manaRegen + itemStats.get("manaRegen")
		player.stats.toughness = player.stats.toughness + itemStats.get("toughness")
		player.stats.elemFire = player.stats.elemFire + itemStats.get("elemFire")
		player.stats.elemCold = player.stats.elemCold + itemStats.get("elemCold")
		player.stats.elemInfect = player.stats.elemInfect + itemStats.get("elemInfect")
	end for
end function

player.gainXP = function(dXP)
	self.xp = self.xp + dXP
end function

player.gainGold = function(dGold)
	self.gold = self.gold + dGold
	if dGold then sounds.coinsMany.play
end function

player.takeDamage = function(damage)
	self.baseStats.health = self.baseStats.health - damage
	if self.baseStats.health < 0 then self.baseStats.health = 0
	if damage > 0 then
		hud.showPain
		sounds.grunt.play mathUtil.lerp(0.5, 1, damage/20), 0, 0.8 + 0.4*rnd
	end if
	if self.baseStats.health <= 0 then self.die
end function

player.gainHealth = function(benefit)
	self.baseStats.health = self.baseStats.health + benefit
	if self.baseStats.health > self.stats.maxHealth then self.baseStats.health = self.stats.maxHealth
	hud.update
end function

player.gainMana = function(benefit)
	self.baseStats.mana = self.baseStats.mana + benefit
	self.stats.mana = self.stats.mana + benefit
	if self.baseStats.mana > self.baseStats.maxHealth then self.baseStats.mana = self.baseStats.maxHealth
	if self.stats.mana > self.stats.maxHealth then self.stats.mana = self.stats.maxHealth
	hud.update
end function

player.die = function
	hud.showDeath
	// for now:
	key.clear; key.get
	clear
	exit
end function