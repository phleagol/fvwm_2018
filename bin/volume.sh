#!/bin/sh
##  Used by conky.
echo -n $(amixer scontents | sed -rn "/Mono.*Play/s/^.*\\[([0-9][0-9][0-9]?)%\\].*/\\1/p")
