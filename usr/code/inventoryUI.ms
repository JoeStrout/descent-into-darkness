// This module manages the equipment/inventory UI, which allows
// the users to see, arrange, and equip their gear.

if locals == globals then
	print "This module doesn't run on its own anymore."
	print "Run the game, and press I instead."
	exit
end if

import "miscUtil"
ensureImport "updatable"
ensureImport "listUtil"
ensureImport "qa"

// sprite display: when null, it means the inventory is not currently
// on screen.  When non-null, it is on screen and this is the display
// where our background and item sprites should go.
spriteDisp = null

addSprite = function(sprite, inBackOfOthers = false)
	if spriteDisp != null then
		if inBackOfOthers then
			for i in spriteDisp.sprites.indexes
				if spriteDisp.sprites[i] isa Item then
					spriteDisp.sprites.insert i, sprite
					return
				end if
			end for
		end if
		spriteDisp.sprites.push sprite
	end if
end function

removeSprite = function(sprite)
	if spriteDisp != null then spriteDisp.sprites.removeVal sprite
end function

background = new Sprite
background.image = file.loadImage("/usr/content/ui/inventoryLayout.png")
background.x = 480; background.y = 320

width = background.image.width
height = background.image.height
left = background.x - width/2
right = background.x + width/2
top = background.y + height/2
bottom = background.y - height/2

// define the item wells... most of these can only hold one
// item, up to a certain size
ItemWell = new Bounds
ItemWell.instances = []
ItemWell.left = function; return self.x - self.width/2; end function
ItemWell.right = function; return self.x + self.width/2; end function
ItemWell.bottom = function; return self.y - self.height/2; end function
ItemWell.top = function; return self.y + self.height/2; end function
ItemWell.contents = null	// item, or list of items
ItemWell.equipType = ""		// which equipment type this well supports

ItemWell.init = function(left, top, columns, rows)
	self.cols = columns
	self.rows = rows
	self.x = left + columns*16
	self.y = top - rows*16
	self.width = columns*32
	self.height = rows*32
	ItemWell.instances.push self
end function

ItemWell.make = function(left, top, columns, rows)
	result = new ItemWell
	result.init left, top, columns, rows
	return result
end function

// Return whether this item well can ever hold the given item,
// based on its size and type.  Note that this function does
// NOT consider whether the well is currently occupied (unless
// maybe at some point we consider that it contains a cursed
// item).  In other words, it should return true if the given
// item can replace the current contents.
ItemWell.canHoldItem = function(item)
	if item.rows > self.rows or item.cols > self.cols then return false
	if self.equipType then return item.equipType == self.equipType
	return true
end function

// Return whether the given item can go into this well without
// replacing an existing item.  This is used when picking stuff up.
ItemWell.canFitItem = function(item)
	if not self.canHoldItem(item) then return false
	return self.contents == null
end function

// Fit the given item into this well, moving it where it should go.
// Return true on success, false if failed.
ItemWell.fitItem = function(item)
	if not self.canFitItem(item) then return false
	item.x = self.x
	item.y = self.y
	self.positionItem item
	return true
end function

// Position the given item into this well, possibly based on where
// it is positioned now (for wells that have multiple slots).
ItemWell.positionItem = function(item)
	item.x = self.x
	item.y = self.y
	if self.contents then dropArea.positionItem self.contents
	self.contents = item
	item.well = self
	player.updateStats
	if visible then drawStats
end function

// Remove the given item from this well.
ItemWell.removeItem = function(item)
	if self.contents == item then self.contents = null
	if self.contents isa list then self.contents.removeVal item
	player.updateStats
	if visible then drawStats
end function

// drop area is a special well that can hold any number of items in a heap
// (it is used to exchange items with the environment)
DropArea = new ItemWell
DropArea.init = function(left, top, columns, rows)
	super.init left, top, columns, rows
	self.contents = []
end function

DropArea.canHoldItem = function(item)
	return true		// drop area can hold anything
end function

DropArea.positionItem = function(item)
	// Only make sure the item is in bounds
	dx = self.left - (item.x - item.cols*16)
	if dx > 0 then item.x = item.x + dx
	dx = (item.x + item.cols*16) - self.right
	if dx > 0 then item.x = item.x - dx
	dy = self.bottom - (item.y - item.rows*16)
	if dy > 0 then item.y = item.y + dy
	dy = (item.y + item.cols*16) - self.top
	if dy > 0 then item.y = item.y - dy
	self.contents.push item
	item.well = self
end function

DropArea.pickUpFromWorld = function
	cell = lvl.cells[camera.pos[0]][camera.pos[1]]
	for i in cell.decorations.reverseIndexes
		dec = cell.decorations[i]
		if not dec isa decorations.ItemPickup then continue
		item = dec.sprite
		inventory.push item
		item.scale = 0.5
		self.positionItem item
		cell.decorations.remove i
		display(4).sprites.removeVal dec.sprite
	end for
end function

// Drop our contents into the world as decorations.
DropArea.dropIntoWorld = function
	if not self.contents then return
	cell = lvl.cells[camera.pos[0]][camera.pos[1]]
	for item in self.contents
		// create an ItemPickup for each one, but since the player is
		// purposely dropping these things, do not auto-pick them up again
		decorations.ItemPickup.make item, cell, false
		item.well = null
	end for
	self.contents = []
end function

// Use are: similar to drop area, but causes us to use the object right away
// (and then puts it back where it came from).
UseArea = new ItemWell
UseArea.init = function(left, top, columns=4, rows=2)
	self.cols = 4
	self.rows = 2
	self.x = left + columns*16
	self.y = top - rows*16
	self.width = columns*32
	self.height = rows*32
	ItemWell.instances.push self
end function

UseArea.canHoldItem = function(item)
	if item.useVerb then return true else return false
end function

UseArea.positionItem = function(item)
	item.use
	if spriteDisp.sprites.indexOf(item) != null then
		// item was not consumed, so put it back where it came from
		item.x = item.pickupPos[0]
		item.y = item.pickupPos[1]
		item.pickupWell.positionItem item
	end if
	self.contents = null
end function

// and backpack is also special: it can hold multiple items, neatly
// organized on a grid, as long as they don't overlap
Backpack = new ItemWell
Backpack.init = function(left, top, columns, rows)
	super.init left, top, columns, rows
	self.contents = list.init2d(columns, rows)
	self.colRange = range(0, columns-1)
	self.rowRange = range(0, rows-1)
end function

// Return whether the given item can go into this well without
// replacing an existing item.  This is used when picking stuff up.
// This version of the method returns the top-left [col,row] if
// it can fit, or false (0) if not.
Backpack.canFitItem = function(item)
	if not self.canHoldItem(item) then return false
	// Look for a set of rows/columns where this could fit,
	// not obstructed by existing items.
	for row in range(self.rows - item.rows, 0)
		for col in range(0, self.cols - item.cols)
			blocked = false
			for i in range(0, item.cols-1)
				for j in range(0, item.rows-1)
					if item.unusedCells and item.unusedCells.contains([i,j]) then continue
					if self.contents[col+i][row+j] then
						blocked = true
						break
					end if
				end for
				if blocked then break
			end for
			if not blocked then return [col, row]
		end for
	end for
	return false
end function

// Fit the given item into this well, moving it where it should go.
// Return true on success, false if failed.
Backpack.fitItem = function(item)
	fittingPlace = self.canFitItem(item)
	if not fittingPlace then return false
	item.x = self.left + fittingPlace[0]*32 + item.cols*16
	item.y = self.top - fittingPlace[1]*32 - item.rows*16
	self.positionItem item
	return true
end function

Backpack.removeItem = function(item)
	for i in self.colRange
		for j in self.rowRange
			if self.contents[i][j] == item then
				self.contents[i][j] = null
				
			end if
		end for
	end for
end function

Backpack.positionItem = function(item)
	// Find the nearest column and row of this item's top-left corner
	// relative to the top-left of the backpack.
	itemLeft = item.x - item.cols*16
	itemTop = item.y + item.rows*16
	leftCol = round((itemLeft - self.left)/32)
	topRow = round((self.top - itemTop)/32)
	
	// If it's not in bounds, return to the drop area
	if leftCol < 0 or topRow < 0 or
	  leftCol + item.cols > self.cols or topRow + item.rows > self.rows then
		dropArea.positionItem item
		return
	end if
	
	// Position neatly
	dx = self.left + leftCol*32 - itemLeft
	dy = (self.top - topRow*32) - itemTop
	item.x = item.x + dx
	item.y = item.y + dy

	// Stuff into our content matrix, ejecting any items previously there
	for i in range(0, item.cols-1)
		for j in range(0, item.rows-1)
			if item.unusedCells and item.unusedCells.contains([i,j]) then continue
			other = self.contents[leftCol+i][topRow+j]
			if other and other != item then dropArea.positionItem other
			self.contents[leftCol+i][topRow+j] = item
		end for
	end for
	item.well = self
end function

// here are all the item wells in our layout:
head = ItemWell.make(left+104, top-72, 2, 2)
head.equipType = "headgear"

chest = ItemWell.make(left+112, top-152, 2, 3)
chest.equipType = "garment"

mainItem = ItemWell.make(left+24, top-184, 2, 3)

offItem = ItemWell.make(left+216, top-216, 2, 2)

rightRing = ItemWell.make(left+32, top-320, 1, 1)
rightRing.equipType = "ring"

leftRing = ItemWell.make(left+224, top-320, 1, 1)
leftRing.equipType = "ring"

boots = ItemWell.make(left+136, top-408, 2, 2)
boots.equipType = "boots"

dropArea = new DropArea
dropArea.init left+496, top-352, 4, 4

useArea = new UseArea
useArea.init left+312, top-422, 4, 2

backpack = new Backpack
backpack.init left+312, top-80, 4, 10

globals.inventory = []

equipmentSlots = [head, chest, mainItem, offItem, leftRing, rightRing, boots]

// Find the item (in the inventory UI) which the mouse is over.
itemUnderMouse = function
	if spriteDisp == null then return null
	for i in range(spriteDisp.sprites.len - 1)
		sp = spriteDisp.sprites[i]
		if sp isa Item and sp.contains(mouse) then return sp
	end for
	return null
end function

// Main function to "pick up" an item, adding it to our
// backpack if it will fit (or to some other slot, if specified
// and currently empty).
pickUp = function(item, optionalSlot=null)
	inventory.push item
	if not backpack.fitItem(item) then dropArea.positionItem item
end function

print = function(s, x, y)
	statDisp.print s, x, y, color.yellow, "small"
end function

printCentered = function(s, x, y, underline=false)
	statDisp.print s, x - s.len*4, y, color.yellow, "small"
	if underline then
		statDisp.line x - s.len*4, y-2, x + s.len*4, y-2, color.yellow
	end if
end function

drawStats = function
	r = new Bounds
	r.width = 140
	r.x = right - 28 - r.width/2
	r.height = 230
	r.y = top - 74 - r.height/2
	statDisp.fillRect r.left, r.bottom, r.width, r.height, color.clear
	//statDisp.drawRect r.left, r.bottom, r.width, r.height, color.gray
	y = r.top - 20
	x = r.left
	print "HEALTH: " + player.stats.health + " / " + player.stats.maxHealth, x, y; y = y - 20
	print "MANA:   " + player.stats.mana + " / " + player.stats.maxMana, x, y; y = y - 20
	print "MANA REGEN:  " + player.stats.manaRegen, x, y; y = y - 20
	print "SPELL POWER: " + player.stats.damage, x, y; y = y - 20
	print "TOUGHNESS:   " + player.stats.toughness, x, y; y = y - 20
	y = y - 20
	printCentered "Elemental", r.x, y; y = y - 20
	printCentered " Strength ", r.x, y, true
	y = y - 24; x = r.x - 12*4
	print "FIRE:      " + player.stats.elemFire, x, y; y = y - 20
	print "COLD:      " + player.stats.elemCold, x, y; y = y - 20
	print "INFECTION: " + player.stats.elemInfect, x, y; y = y - 20	
end function

// state variables
hoveredItem = null		// item mouse is hovering over
grabDx = 0				// position of item relative to mouse
grabDy = 0

// main (inventory) update function
update = function
	if items.grabbedItem == null then
		item = itemUnderMouse
		if hoveredItem and item != hoveredItem then hoveredItem.endHover
		if item and item != hoveredItem then item.beginHover
		if item and mouse.button then item.beginGrab
	else
		if mouse.button then items.grabbedItem.continueGrab else items.grabbedItem.endGrab
	end if
end function

// Present the inventory UI, and run its own main loop until the
// user dismisses it.
presentModal = function
	display(2).mode = displayMode.sprite
	outer.spriteDisp = display(2)
	spriteDisp.clear
	spriteDisp.sprites.push background
	for item in inventory
		spriteDisp.sprites.push item
	end for
	
	display(1).mode = displayMode.pixel
	outer.statDisp = display(1)
	statDisp.clear color.clear
	drawStats
	
	key.clear
	while true
		if key.available then
			k = key.get
			if k == char(3) or k == char(13) or k == char(27) or k == "i" then
				break
			end if
		end if
		update		
		updatable.update
		yield
	end while
	spriteDisp.clear
	outer.spriteDisp = null
	display(2).mode = displayMode.pixel
	display(1).mode = displayMode.text
end function

// visible: return whether the inventory UI is currently displayed.
visible = function
	return spriteDisp != null
end function