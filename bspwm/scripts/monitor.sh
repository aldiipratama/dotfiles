#!/usr/bin/env bash

if [[ $(xrandr -q | grep "eDP-1 connected") ]]; then
  xrandr --output eDP-1 --primary --mode 1920x1080 --scale 1 --pos 0x0 --rotate normal
  bspc monitor eDP-1 -d 1 2 3 4 5 6 7 8 9
fi
