#!/usr/bin/env bash

pgrep -x sxhkd >/dev/null || sxhkd -c $HOME/.config/bspwm/sxhkdrc &

$HOME/.config/bspwm/scripts/monitor.sh
$HOME/.config/polybar/scipts/launch.sh
$HOME/.config/bspwm/scripts/wallpaper.sh
