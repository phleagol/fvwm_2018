#!/bin/sh
##  Used by conky.
bri=$(cat /sys/class/backlight/radeon_bl0/brightness)
[ $bri -ge 255 ] && bri=255 
echo -n $((bri*100/255))
