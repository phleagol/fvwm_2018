#!/bin/sh

sudo /usr/bin/apt update
apt list --upgradable 2>/dev/null | grep / | wc -l >$HOME/.apt_update
echo
echo -n  "Ctrl-C to exit"
sleep 1800





