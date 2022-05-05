// This module manages the equipment/inventory UI, which allows
// the users to see, arrange, and equip their gear.

import "miscUtil"
ensureImport "updatable"
ensureImport "listUtil"
ensureImport "qa"
ensureImport "items"

// development/debugging setup

clear
spriteDisp = display(4)
display(2).mode = displayMode.pixel
display(2).clear color.clear

background = new Sprite
background.image = file.loadImage("/usr/content/ui/inventoryLayout.png")
//background.image = file.loadImage("/usr/content/ui/Frame_1.png")
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

ItemWell.debugDraw = function
	display(2).drawPoly self.corners, "#FF00FF", 3
end function

ItemWell.canHoldItem = function(item)
	if item.rows > self.rows or item.cols > self.cols then return false
	// ToDo: consider restrictions based on equipment slot
	return true
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
	if self.contents isa list then self.contents.removeVal item
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

// and backpack is also special: it can hold multiple items, neatly
// organized on a grid, as long as they don't overlap
Backpack = new ItemWell
Backpack.init = function(left, top, columns, rows)
	super.init left, top, columns, rows
	self.contents = list.init2d(columns, rows)
	self.colRange = range(0, columns-1)
	self.rowRange = range(0, rows-1)
end function

Backpack.removeItem = function(item)
	for i in self.colRange
		for j in self.rowRange
			if self.contents[i][j] == item then self.contents[i][j] == null
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

backmostItemSpriteIndex = spriteDisp.sprites.len
inventory = []
staff = Item.make("greenStaffglow")
staff.unusedCells = [[1,0], [0,2]]
inventory.push staff

inventory.push Item.make("dagger")
inventory.push Item.make("dagger")
inventory.push Item.make("redPotion")
inventory.push Item.make("redPotion")
inventory.push Item.make("yellowGemstone")
inventory.push Item.make("yellowGemstone")

itemUnderMouse = function
	for i in range(spriteDisp.sprites.len - 1)
		sp = spriteDisp.sprites[i]
		if sp isa Item and sp.contains(mouse) then return sp
	end for
	return null
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

while true
	update
	updatable.update
	yield
end while
