Flowerhead
----------
Flowerhead is a difficult platforming game about escaping a dungeon-hive by
filling it with flowers and fighting bees. It is made in [Pico-8][1]. You
can play the game in browser on desktop or mobile:
https://charlietran.com/games/flowerhead

[1]: https://www.lexaloffle.com/pico-8.php

I've small playable things before, but I would consider this my first real game.
I hope you like it, and if you have any feedback, you can find my contact info
at www.charlietran.com

Thanks
------
I made most of this project while in the Fall 2018 batch at the [Recurse
Center](https://www.recurse.com/) in Brooklyn, NY. It's a wonderful organization
that I recommend you check out!

This game wouldn't exist without the help of:

* [Eli Piilonen](https://twitter.com/2darray) for making [Tiny
  Playformer](https://2darray.itch.io/tinyplatformer), which helped me learn a
  ton about making a dynamic, responsive platformer
* [Aaron Wood](https://github.com/itscomputers) for helping me figure out the
  math of the sunshine rays and parallax clouds
* [Sheridan Kates](https://github.com/sheridanvk) for being a wonderful Recurse
  center buddy and telling me to make the flowers say random things on impact :)
* [Lillian Primrose](https://twitter.com/id_load_error) for showing me how to do
  A\* pathfinding for the bees
* [Ayla Myers](https://brid.gs) for inspiring me with their awesome PICO-8 work 
* [Kicked-in-Teeth](https://kicked-in-teeth.itch.io/pico-8-tiles) whose
  excellent free art tiles I used and modified for the game

Source
------
The original source for the game is in `flowerhead.p8`. It's in Pico-8's special
cartridge format which is a combination of Lua code, graphics, tilemap and sound
effects / music data. As is, it's too big for Pico8's normal filesize and token
limits, so I use `build.sh` to minify it via
[picotool](https://github.com/dansanderson/picotool) before release.

