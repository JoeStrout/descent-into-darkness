// This file defines the Item class, and various item types in the game.
// (Items are things that can be picked up and moved around in inventory.
// Some of them can also be equipped.)

import "miscUtil"
ensureImport "updatable"
ensureImport "listUtil"

grabbedItem = null		// item mouse is carrying around

globals.Item = new UpdatableSprite
Item.scale = 0.5
Item.well = null
Item.unusedCells = null	// list of [col,row] cells this item does NOT actually use

Item.init = function(filename)
	self.image = file.loadImage("/usr/content/items/" + filename + ".png")
	qa.assert self.image != null, "Couldn't find item image for: " + filename
	self.rows = round(self.image.height / 64)
	self.cols = round(self.image.width / 64)
	self.localBounds = new Bounds
	self.localBounds.width = self.image.width - 4
	self.localBounds.height = self.image.height - 4
	self.x = dropArea.x + round(rnd*60 - 30)
	self.y = dropArea.y + round(rnd*60 - 30)
	spriteDisp.sprites.push self
end function

Item.make = function(filename)
	result = new Item
	result.init filename
	return result
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
	outer.hoveredItem = self
end function

Item.endHover = function
	self.scale = 0.5
	if outer.hoveredItem == self then outer.hoveredItem = null
end function

Item.beginGrab = function
	self.scale = 0.6
	outer.grabbedItem = self
	outer.grabDx = self.x - mouse.x
	outer.grabDy = self.y - mouse.y
	if self.well then self.well.removeItem self
	// move to front
	spriteDisp.sprites.removeVal self
	spriteDisp.sprites.push self
end function

Item.continueGrab = function
	self.x = mouse.x + grabDx
	self.y = mouse.y + grabDy
end function

Item.endGrab = function
	self.scale = 0.5
	if outer.grabbedItem == self then outer.grabbedItem = null
	// move to back (of items), so you can rifle through a pile
	spriteDisp.sprites.removeVal self
	spriteDisp.sprites.insert backmostItemSpriteIndex, self
	self.dropInWell
end function

Item.dropInWell = function
	for well in ItemWell.instances
		if well.canHoldItem(self) and well.contains(self) then
			well.positionItem self
			return
		end if
	end for
	// Not dropped in any well?  Put in drop area.
	dropArea.positionItem self
end function