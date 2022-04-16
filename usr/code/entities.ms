
//---------------------------------------------------------------
// Entity class: represents things that can move around
// in the game.  Typically these consist of an Imposter
// for whatever it is, and a FlatDecal for the shadow.
Entity = {}
Entity.pos = null				// [x,y,z] position of the main
Entity.decorations = null		// list of parts we need to move around
Entity.shadow = null			// decoration representing the shadow
Entity.main = null				// main Imposter or whatever it is
Entity.rotation = 0				// direction the main is facing

Entity.init = function(cell)
	self.pos = [cell.col + 0.5, cell.row + 0.5, 0]
	self.shadow = FlatDecal.make("shadow.png", cell, 0.4)
	self.main = Imposter.make("mobs/spider/", cell, 1)
	self.decorations = [self.shadow, self.main]
	self.main.pos[2] = -0.15	// (sits better on ground)
end function

Entity.rotateTo = function(rotation)
	self.main.rotation = rotation
end function

Entity.moveTo = function(x, y)
	self.pos[0] = x; self.pos[1] = y
	for d in self.decorations
		d.pos[0] = x; d.pos[1] = y
	end for
end function
