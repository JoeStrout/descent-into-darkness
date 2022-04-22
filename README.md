![Descent into Darkness (title image)](notes/note-pics/title-small-transparent.png)

## a 3D(ish) realtime dungeon crawler for Mini Micro

This is a community project to develop a Doom-like fantasy RPG dungeon crawler using [MiniScript](https://miniscript.org/) and [Mini Micro](https://miniscript.org/MiniMicro).

![Fairly current screen shot](notes/note-pics/ReadMeShot.png)

## Getting Started

1. Clone (or better yet, fork and then clone) this repo to your local hard drive.
2. Mount the `usr` folder in slot 1 (`/usr`) of Mini Micro.
3. `reboot`

## Controls

- **WASD** or **arrow keys**: move/strafe.
- **Mouse**: rotate and look up/down.
- **Shift**, **Tab**, or **Spacebar**: toggle door.
- **Spacebar** or **Return**: fire a spell.
- **M**: show in-game map.

Note that mobs can't hurt you yet.  But you can destroy them with spells (spiders require multiple hits; slimes need only one).

## Exploring the project

Core game code is in the `code` folder.  This includes `main.ms`, which is the main program; that's the one to reload and run after making a change to anything.  Graphics, sounds, etc. are all in the `content` folder.

## Contributing

This is meant to be a community project.  Join the MiniScript Discord server via the link on the [MiniScript home page]((https://miniscript.org/), find the #descent-into-darkness channel, and join the fun!
