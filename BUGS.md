# Bugs

## Open

## Fixed

- Pressing F1 after dying in a room creator play-test logs "Invalid access to property or key
  'process_frame' on a base object of type 'null instance'". The level timer's fatal
  countdown waited a frame at a time with `get_tree()`, and leaving the game took the timer
  out of the tree mid-wait. It now stops if it's no longer in the tree.
- Running the tests (`tools/check.sh`) wipes the developer's save file. One test cleared
  progress in memory with saving switched off, then switched it back on without restoring
  anything, and a later test that saves (a game over) wrote the cleared progress and full
  volumes to `user://save.cfg`. The test runner now never writes the save file and puts
  SaveData back to what it loaded after every test, and the test restores what it changes.
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
