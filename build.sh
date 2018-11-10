#!/bin/bash
../picotool/p8tool build flowerhead_build.p8 --lua-minify \
 --lua flowerhead.p8   --gfx flowerhead.p8 --gff flowerhead.p8 \
 --music flowerhead.p8 --map flowerhead.p8 --sfx flowerhead.p8
comment='\
-- f l o w e r h e a d \
-- by charlie tran \
-- this code is minified \
-- the original source is here \
-- github.com/charlietran/flowerhead '

sed -i '' "s@__lua__@__lua__\
$comment\
@" flowerhead_build.p8

/Applications/PICO-8.app/Contents/MacOS/pico8 flowerhead_build
cp -v ~/dev/pico8/cart.js ~/dev/charlietran.com/games/flowerhead/cart.js
