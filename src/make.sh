#!/bin/sh

./rasm/rasm $1
./pgm/pgm.py ${1%.asm}.obj
