## Descent into Darkness: Gameplay Overview

This is a real-time roguelike RPG.  Let's break that down:

**real-time**: Not turn based.  It plays like a first-person shooter: you use your mouse and keyboard to move around and shoot mobs, while trying to avoid damage yourself.  (Note however that there may be occasional turn-based dialog or other UI while the game is effectively paused.)

**roguelike**: You get one life.  You will probably die.  When you die, the game is over.  It is meant to be played over and over, so most of the world is procedurally generated (and thus different on each play).  Beating the game (i.e. defeating the final boss and retrieving the MacGuffin) should take 3-4 hours, and should feel like a real achievement.

**role-playing game (RPG)**: It's a fantasy world.  You are exploring dungeons, fighting monsters with magic.  You use medieval weapons and armor and gather treasure.  Classic stuff.


## Major Game Loop

1. Descend into the dungeon, fighting your way down as far as you can.
2. When close to death and low on supplies, pop back to town to heal, sell your loot, upgrade your gear, and buy new supplies.
3. Repeat until you have won or died.  (We will need a way to pop back to the level where you left off.)


## Game Controls

- **Mouse/Keyboard**: use mouse to rotate left/right and pitch up/down.  Use WASD to move forward/back and strafe left/right; Q/E to rotate left/right.  Spacebar: use primary weapon/spell, or while hovering over doors/NPCs/etc., activate/engage.  Tab or shift: use secondary item/spell (often a shield or potion).

(Ideal, if we could do it -- but will have to wait for Mini Micro v1.2: Left mouse button: use primary weapon/spell, or while hovering over doors/NPCs/etc., activate/engage.  Right mouse button, or LMB+alt: use secondary item/spell.)


- **Gamepad**: use left stick or D-pad to move/strafe, right stick to turn and look up/down.  Face buttons act as primary/secondary buttons.


## Level Variety

We want the different levels to look and feel different.  Different textures, different generation algorithm resulting in differently-shaped rooms and corridors, different monsters, etc.  This will break up the sameness and make it feel more like there's a full underground world down there.

## Special Levels

- **Town**: aka "level 0", this is the only outdoor level in the game.  So instead of a ceiling you see sky.  There is a wall around the town, and various buildings scattered about.  Some of these have gameplay value (e.g. the shop, or Town Hall where the mayor gives you special rewards for making progress on the quest).  Others are just for fun.  Somewhere in down is the entrance to level 1 of the dungeons.

- **Deep Town**: about halfway down to the dungeons is a "rest" level equipped with a shop and other amenities.  It's still underground, but otherwise seems very much like a town, with NPCs etc., and no monsters.  It's there to give you a clear intermediate goal, and to provide a higher-level rest area (better/more expensive gear, etc.).

- **Sokoban Level**: somewhere, either as a level itself, or a section of some other level (maybe Deep Town?), we should have a sokobon mini-game where you have to push all the crates into pits in order to win some reward.  All in a first-person view!  (Which might make it hard to see the pits... need to think up some clever solution for that.)  This is a nod to Nethack, which has such a level, as well as to our own @Sebnozzi, who made a great Sokoban game in Mini Micro.


## Art Style

We should look to Doom or Castle Wolfenstein for our inspiration, except that our display is considerably higher resolution.  So: fairly detailed, but still cartoony.

