// This file defines the Item class, and various item types in the game.
// (Items are things that can be picked up and moved around in inventory.
// Some of them can also be equipped.)

import "miscUtil"
ensureImport "updatable"
ensureImport "listUtil"
ensureImport "stats"

grabbedItem = null		// item mouse is carrying around

globals.Item = new UpdatableSprite
Item.name = "item"
Item.scale = 0.5
Item.well = null
Item.unusedCells = null	// list of [col,row] cells this item does NOT actually use
Item.equipType = null	// which equipment slot type this item can be used in
Item.useVerb = null		// verb describing how this item is used, or null if not usable
Item.use = null
Item.stats = null		// effect of this item when equipped or used

Item.init = function(filename)
	self.image = file.loadImage("/usr/content/items/" + filename + ".png")
	qa.assert self.image != null, "Couldn't find item image for: " + filename
	self.rows = round(self.image.height / 64)
	self.cols = round(self.image.width / 64)
	self.localBounds = new Bounds
	self.localBounds.width = self.image.width - 4
	self.localBounds.height = self.image.height - 4
	self.x = inventoryUI.dropArea.x + round(rnd*60 - 30)
	self.y = inventoryUI.dropArea.y + round(rnd*60 - 30)
	self.name = filename
	if self.stats == null then self.stats = new Stats
end function

Item.make = function(filename)
	result = new Item
	result.init filename
	return result
end function

Item.destroy = function
	inventory.removeVal self
	if inventoryUI.spriteDisp then
		inventoryUI.spriteDisp.sprites.removeVal self
	end if
	if self.well then self.well.removeItem self
	self.well = null
end function

Item.contains = function(point)
	if not super.contains(point) then return false
	if not self.unusedCells then return true
	col = floor((point.x - self.x)/32 + self.cols/2)
	row = self.rows-1 - floor((point.y - self.y)/32 + self.rows/2)
	if self.unusedCells.contains([col,row]) then return false
	return true
end function

Item.beginHover = function
	self.scale = 0.55
	inventoryUI.hoveredItem = self
end function

Item.endHover = function
	self.scale = 0.5
	if inventoryUI.hoveredItem == self then inventoryUI.hoveredItem = null
end function

Item.beginGrab = function
	self.pickupPos = [self.x, self.y]; self.pickupWell = self.well
	self.scale = 0.6
	outer.grabbedItem = self
	outer.grabDx = self.x - mouse.x
	outer.grabDy = self.y - mouse.y
	if self.well then self.well.removeItem self
	// move to front
	inventoryUI.removeSprite self
	inventoryUI.addSprite self
end function

Item.continueGrab = function
	self.x = mouse.x + grabDx
	self.y = mouse.y + grabDy
end function

Item.endGrab = function
	self.scale = 0.5
	if outer.grabbedItem == self then outer.grabbedItem = null
	inventoryUI.removeSprite self
	inventoryUI.addSprite self, true	// move to back (of items)
	self.dropInWell
end function

Item.dropInWell = function
	for well in inventoryUI.ItemWell.instances
		if well.canHoldItem(self) and well.contains(self) then
			well.positionItem self
			return
		end if
	end for
	// Not dropped in any well?  Put in drop area.
	inventoryUI.dropArea.positionItem self
end function

//----------------------------------------------------------------------
// Subclasses for specific kinds of items

// UsableItem: any Item that can be equipped or used.
UsableItem = new Item
UsableItem.useVerb = "Use"
UsableItem.make = function(filename)
	result = new UsableItem
	result.init filename
	return result
end function

Consumable = new UsableItem
Consumable.useVerb = "Consume"
Consumable.sound = sounds.munch
Consumable.use = function
	if self.sound then self.sound.play
	// consumables apply instant benefits to certain stats
	player.gainHealth self.stats.health
	player.gainMana self.stats.mana
	self.destroy
end function

Food = new Consumable
Food.useVerb = "Eat"
Food.sound = sounds.munch
Food.stats = new Stats
Food.stats.health = 1
Food.make = function(filename)
	result = new Food
	result.init filename
	return result
end function

Drink = new Consumable
Drink.useVerb = "Drink"
Drink.sound = sounds.gulp
Drink.make = function(filename)
	result = new Drink
	result.init filename
	return result
end function

HealthPotion = new Drink
HealthPotion.stats = new Stats
HealthPotion.stats.health = 8
HealthPotion.make = function
	result = new HealthPotion
	result.init "redPotion"
	return result
end function

Equipment = new UsableItem
Equipment.useVerb = "Equip"
Equipment.make = function(filename="goldRing")
	result = new Equipment
	result.init filename
	return result
end function

Ring = new Equipment
Ring.equipType = "ring"
Ring.make = function(filename="goldRing")
	result = new Ring
	result.init filename
	return result
end function

ManaRing = new Ring
ManaRing.stats = new Stats
ManaRing.stats.manaRegen = 1
ManaRing.make = function
	result = new ManaRing
	result.init "goldRing"
	return result
end function

Boots = new Equipment
Boots.equipType = "boots"
Boots.stats = new Stats
Boots.stats.toughness = 1
Boots.make = function(filename="darkBrownBoots")
	result = new Boots
	result.init filename
	return result
end function

Headgear = new Equipment
Headgear.equipType = "headgear"
Headgear.stats = new Stats
Headgear.stats.maxMana = 3
Headgear.make = function(filename)
	result = new Headgear
	result.init filename
	return result
end function

Garment = new Equipment		// (specifically, chest covering)
Garment.equipType = "garment"
Garment.stats = new Stats
Garment.stats.elemCold = 1
Garment.make = function(filename)
	result = new Garment
	result.init filename
	return result
end function

