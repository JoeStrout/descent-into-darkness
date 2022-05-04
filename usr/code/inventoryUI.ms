// This module manages the equipment/inventory UI, which allows
// the users to see, arrange, and equip their gear.

import "miscUtil"
ensureImport "updatable"
ensureImport "listUtil"
ensureImport "qa"

// development/debugging setup

clear
spriteDisp = display(4)
display(2).mode = displayMode.pixel
display(2).clear color.clear

background = new Sprite
background.image = file.loadImage("/usr/content/ui/inventoryLayout.png")
background.x = 480; background.y = 320
spriteDisp.sprites.push background

width = background.image.width
height = background.image.height
left = background.x - width/2
right = background.x + width/2
top = background.y + height/2
bottom = background.y - height/2

gfx.fillRect left, bottom, width, height, "#E4E2CA"

// define the item wells... most of these can only hold one
// item, up to a certain size
ItemWell = new Bounds
ItemWell.instances = []
ItemWell.left = function; return self.x - self.width/2; end function
ItemWell.right = function; return self.x + self.width/2; end function
ItemWell.bottom = function; return self.y - self.height/2; end function
ItemWell.top = function; return self.y + self.height/2; end function
ItemWell.contents = null	// item, or list of items

ItemWell.init = function(left, top, columns, rows)
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

ItemWell.debugDraw = function
	display(2).drawPoly self.corners, "#FF00FF", 3
end function

ItemWell.positionItem = function(item)
	item.x = self.x
	item.y = self.y
	if self.contents then dropArea.positionItem self.contents
	self.contents = item
	item.well = self
end function

ItemWell.removeItem = function(item)
	if self.contents == item then self.contents = null
	if self.contents isa map then self.contents.remove item
end function

// drop area is a special well that can hold any number of items in a heap
// (it is used to exchange items with the environment)
DropArea = new ItemWell
DropArea.init = function(left, top, columns, rows)
	super.init left, top, columns, rows
	self.contents = {}
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

// and backpack is also special: it can hold multiple items, neatly
// organized on a grid, as long as they don't overlap
Backpack = new ItemWell
Backpack.init = function(left, top, columns, rows)
	super.init left, top, columns, rows
	self.contents = {}
end function

Backpack.positionItem = function(item)
	// Find the nearest cell based on this item's top-left corner
	// relative to the center of the backpack.
	itemLeft = item.x - item.cols*16 - self.x
	itemBotm = item.y - item.rows*16 - self.y
	dx = round(itemLeft/32)*32 - itemLeft
	dy = round(itemBotm/32)*32 - itemBotm
	item.x = item.x + dx
	item.y = item.y + dy
	self.contents.push item
	item.well = self
end function

// here are all the item wells in our layout:
head = ItemWell.make(left+104, top-72, 2, 2)
chest = ItemWell.make(left+112, top-152, 2, 3)
mainItem = ItemWell.make(left+24, top-184, 2, 3)
offItem = ItemWell.make(left+216, top-216, 2, 2)
rightRing = ItemWell.make(left+32, top-320, 1, 1)
leftRing = ItemWell.make(left+224, top-320, 1, 1)
boots = ItemWell.make(left+136, top-408, 2, 2)
dropArea = new DropArea
dropArea.init left+496, top-352, 4, 4
backpack = new Backpack
backpack.init left+312, top-112, 4, 10

//for well in ItemWell.instances
//	well.debugDraw
//end for

// Item class: represents something that can be moved around in envintory.
Item = new UpdatableSprite
Item.scale = 0.5
Item.well = null

Item.init = function(filename)
	self.image = file.loadImage("/usr/content/items/" + filename + ".png")
	qa.assert self.image != null
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
	if not dropArea.overlaps(self) then self.snapToGrid
end function

Item.snapToGrid = function
	for well in ItemWell.instances
		if well.contains(self) then
			well.positionItem self
			return
		end if
	end for
	// Not dropped in any well?  Put in drop area.
	dropArea.positionItem self
end function

backmostItemSpriteIndex = spriteDisp.sprites.len
items = []
items.push Item.make("greenStaffglow")
items.push Item.make("dagger")
items.push Item.make("redPotion")
items.push Item.make("redPotion")
items.push Item.make("yellowGemstone")

itemUnderMouse = function
	for i in range(spriteDisp.sprites.len - 1)
		sp = spriteDisp.sprites[i]
		if sp isa Item and sp.contains(mouse) then return sp
	end for
	return null
end function

// state variables
hoveredItem = null		// item mouse is hovering over
grabbedItem = null		// item mouse is carrying around
grabDx = 0				// position of item relative to mouse
grabDy = 0

// main (inventory) update function
update = function
	if grabbedItem == null then
		item = itemUnderMouse
		if hoveredItem and item != hoveredItem then hoveredItem.endHover
		if item and item != hoveredItem then item.beginHover
		if item and mouse.button then item.beginGrab
	else
		if mouse.button then grabbedItem.continueGrab else grabbedItem.endGrab
	end if
end function

while true
	update
	updatable.update
	yield
end while
