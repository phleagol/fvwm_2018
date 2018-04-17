#!/bin/bash

clear
rm ci_*

##  Nominal icon geometry


convert indicator-cpufreq-128x128.orig.png -verbose -quality 100 \
    -crop '100x100+0+12' -adaptive-resize 26x26 ci_cpu.png

echo
convert drive-harddisk-128x128.orig.png -verbose -quality 100 \
    -adaptive-resize 24x24 ci_readwrite.png

echo
convert go-up.orig.png -verbose -quality 100 \
    -adaptive-resize 24x24 ci_up.png

echo
convert go-down.orig.png -verbose -quality 100 \
    -adaptive-resize 24x24 ci_down.png

echo
montage -verbose -background gray9 -geometry +12+12 -tile 5x1 \
    ci_cpu.png ci_readwrite.png ci_up.png ci_down.png ci_montage.png

##  convert Ram-icon-40x40.xbm -verbose -quality 100 \
##       -transparent white -fuzz 10% -fill gray65 \
##       -opaque black sg_memory.png

# convert memory-chip_40x40.xbm -verbose -quality 100 \
#      -transparent white -fuzz 10% -fill gray70 \
#      -opaque black sg_memory.png

echo
#convert -verbose -quality 100 \
#    -composite drive-harddisk-128x128.orig.png pause-emblem-128x128.orig.png \
#    -adaptive-resize $GEOM sg_iowait.png


# convert -verbose -quality 100 \
#     gdu-error-128x128.png -fuzz 30% -fill steelblue4 -opaque '#932424' \
#     -adaptive-resize $GEOM sg_iowait.png


# echo
# convert applications-internet2-128x128.orig.png -verbose -quality 100 \
#     -adaptive-resize 35x35 sg_updown.png

#convert -quality 99 nm-device-wired.png -colorspace Gray \
#    -brightness-contrast 20x0 -adaptive-resize 40x40 sg_updown.png


##  convert harddrive-pause-2.png -verbose -quality 100 \
##      -adaptive-resize 40x40 sg_iowait.png
#cp -v harddrive-pause-2.png sg_iowait.png

##  convert Ram-icon-48x48.orig.png -verbose -quality 100 \
##      -rotate -90 -brightness-contrast 70x0 sg_memory.png


