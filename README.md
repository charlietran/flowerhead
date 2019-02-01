Flowerhead is a Pico-8 action game I created in 2018. You can play the game in browser here, on desktop or mobile: https://charlietran.com/games/flowerhead.

Source
------
The original source for the game is in `flowerhead.p8`. It's in Pico-8's special cartridge format which is a combination of Lua code, graphics, tilemap and sound effects / music data. As is, it's too big for Pico8's normal filesize limitations, so I use `build.sh` to minify it via [picotool](https://github.com/dansanderson/picotool) before release.

Credits
-------
All code, sound and most of the graphics were created by me, [Charlie
Tran](https://charlietran.com). I made most of this project while in the Fall 2018 batch at the [Recurse Center](https://www.recurse.com/)

Additional, many thanks to the following people for their help and support:
* [Eli Piilonen](https://twitter.com/2darray) for making [Tiny
  Playformer](https://2darray.itch.io/tinyplatformer), which helped me learn a
  ton about making platformer physics
* [Aaron Wood](https://github.com/itscomputers) for helping me figure out the
  math of the sunshine rays and parallax clouds
* [Lillian Primrose](https://twitter.com/id_load_error) for showing me how to do
  A\* pathfinding for the bees
* [Sheridan Kates](https://github.com/sheridanvk) for being a wonderful Recurse center buddy and telling me to make the flowers say random things on impact :)
* [Ayla Myers](https://brid.gs) for inspiring me with their awesome PICO-8 work 
* [Kicked-in-Teeth](https://kicked-in-teeth.itch.io/pico-8-tiles) whose excellent free art tiles I used and modified for the game
