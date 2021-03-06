// This defines a base class for anything that should be
// updated on a regular basis.  Be sure to call init and die.

// list of all active updatables:
all = []

globals.Updatable = {}
Updatable.init = function
	all.push self
end function

Updatable.suspend = function
	idx = all.indexOf(self)
	if idx != null then all.remove idx
end function

Updatable.resume = function
	idx = all.indexOf(self)
	if idx == null then all.push self
end function

Updatable.die = function
	self.suspend
end function

Updatable.update = function(dt=0.016)
end function

globals.UpdatableSprite = new Sprite
for kv in Updatable
	UpdatableSprite[kv.key] = @kv.value
end for

Bounds.left = function; return self.x - self.width/2; end function
Bounds.top = function; return self.y + self.height/2; end function
Bounds.right = function; return self.x + self.width/2; end function
Bounds.bottom = function; return self.y - self.height/2; end function


// function to update them all!
update = function(dt=0.016)
	// We do the following loop very carefully, in case
	// some of that update code might alter our `all` list.
	if not all then return
	for i in range(all.len - 1)
		if i < all.len then all[i].update dt
	end for
end function
