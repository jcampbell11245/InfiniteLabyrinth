# Bugs

## Open

## Fixed

- The Controls page opened off-screen in the bottom-right corner. Its instanced root was
  anchored to the options panel's bottom-right while keeping its own 704x396 size, so the
  dialog started outside the window. It now fills the options panel from its top-left.
- The boss can move through walls and clip out of bounds. The boss only collided with
  physics layer 1, but the wall tiles on the Top and TopWalls layers are on layer 9; it now
  collides with walls and pits like the other enemies.
- The knight's sprite can render underneath the top wall sprite. The side walls are drawn
  over everything next to them, and the knight's sprite is about three times wider than its
  feet, so it could stand half inside the wall art. Knights now keep 22 px from the side walls
  (`side_wall_margin` on Enemy).
- Blood splatters can appear on pit tiles and wall tiles. Splat pieces that would land off the
  9x9 floor or over a pitfall are now dropped (`Room.is_floor_at`).
- The player can get stuck while walking through a side door. Brushing the door frame zeroed
  the auto-walk's velocity and nothing reset it. The auto-walk now sets its velocity every
  frame and steers the player onto the middle of the doorway; the door is also picked from
  which side of the room the player is on rather than which way they were moving.
- The player can walk through the lower side walls of the boss room. Most of its side-wall
  cells held plain floor tiles, so only enemies (which also collide with the wall overlays)
  were stopped; they now use the same solid wall tiles as the start room.
- Knights can walk into an open top doorway and disappear under its arch. Doors open while
  knights are still alive in switch rooms, and nothing but the lock tiles kept enemies out of
  doorways. Every doorway now has a blocker on the top-tiles layer, which enemies collide
  with and the player doesn't.
- Knights' horns clip under the top wall. The top wall's cells were on the Top layer, which
  draws over every character so they can pass behind the side and bottom walls. They now
  sit on layers below everything on the floor (TopBack, plus TopArch for the top door's
  column); the arch is raised over the player only while they walk through a top door.
- The music resumes for a split second after the game over card. The music only paused with
  the game, so it played again when the card unpaused the tree to open the upgrade menu. It
  is now stopped on death (`Music.stop_all`) and the next floor starts it again.
