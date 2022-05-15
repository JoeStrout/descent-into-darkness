// Stats: a class that represents a set of stats for the player,
// or for an item/spell's effect on the player.

globals.Stats = {}
Stats.health = 0		// current hit points (or HP restored)
Stats.maxHealth = 0		// maximum hit points
Stats.mana = 0			// current mana (or mana restored)
Stats.maxMana = 0		// size of mana pool
Stats.damage = 0		// affects how much damage offensive spells do
Stats.manaRegen = 0		// affects how quickly mana regenerates
Stats.toughness = 0		// reduces damage from physical attacks
Stats.elemFire = 0		// bonus/penalty in fire attacks
Stats.elemCold = 0		// bonus/penalty in cold attacks
Stats.elemInfect = 0	// bonus/penalty in infection attacks
