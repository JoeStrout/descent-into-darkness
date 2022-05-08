ensureImport "hud"
ensureImport "sounds"
ensureImport "mathUtil"
ensureImport "inventoryUI"

globals.player = {}
player.name = "PLAYER NAME"
player.health = 100
player.mana = 100
player.stamina = 100
player.level = 0
player.xp = 0
player.gold = 0

player.initialize = function
	// Create our initial items:
	staff = Item.make("greenStaffglow")
	staff.unusedCells = [[1,0], [0,2]]
	inventoryUI.pickUp staff

	inventoryUI.pickUp Item.make("dagger")
	inventoryUI.pickUp Item.make("dagger")
	inventoryUI.pickUp items.UsableItem.make("redPotion")
	inventoryUI.pickUp items.UsableItem.make("redPotion")
	inventoryUI.pickUp Item.make("yellowGemstone")
	inventoryUI.pickUp Item.make("yellowGemstone")
	inventoryUI.pickUp items.Ring.make
	inventoryUI.pickUp items.Boots.make
end function

player.gainXP = function(dXP)
	self.xp = self.xp + dXP
end function

player.gainGold = function(dGold)
	self.gold = self.gold + dGold
	if dGold then sounds.coinsMany.play
end function

player.takeDamage = function(damage)
	self.health = self.health - damage
	if self.health < 0 then self.health = 0
	if damage > 0 then
		hud.showPain
		sounds.grunt.play mathUtil.lerp(0.5, 1, damage/20), 0, 0.8 + 0.4*rnd
	end if
	if self.health <= 0 then self.die
end function

player.die = function
	hud.showDeath
	// for now:
	key.clear; key.get
	clear
	exit
end function