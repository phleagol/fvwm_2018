#!/bin/bash

##  Shutdown script for fvwm.

dots() { for num in {0..9} ; do echo -n "." ; sleep .5 ; done ; }

# if [[ "$1" != "poweroff" && "$1" != "reboot" ]] ; then
#     echo " * Valid exit command not found..."
#     dots ; exit 
# fi

echo " * Closing open tombs..." | tee -a  ~/.xsession-errors
sudo tomb close all 1>/dev/null 2>&1

echo " * Deleting thumbnails..." | tee -a  ~/.xsession-errors 
rm "$FVWM_THUMBS/0x"* 1>/dev/null 2>&1

echo " * Shred clipboard entries..." | tee -a  ~/.xsession-errors
shred -u -n0 $FVWM_CLIPS/* 1>/dev/null 2>&1

echo " * Running bleachbit..." | tee -a  ~/.xsession-errors
bleachbit --shred --clean pale_moon.all \
    firefox.backup firefox.cache flash.cookies flash.cache \
    firefox.cookies firefox.crash_reports firefox.dom \
    firefox.download_history firefox.forms firefox.passwords \
    firefox.session_restore firefox.url_history \
    chromium.cache chromium.cookies chromium.current_session \
    chromium.dom chromium.form_history chromium.history \
    chromium.passwords chromium.search_engines chromium.vacuum \
    1>/dev/null 2>&1

echo " * Deleting cache..."  | tee -a  ~/.xsession-errors
rm -r "$HOME/.cache/"* 1>/dev/null 2>&1

echo " * Slamming open tombs..."  | tee -a  ~/.xsession-errors
sudo tomb slam all 1>/dev/null 2>&1

echo " * Miscellaneous..."  | tee -a  ~/.xsession-errors
rm ~/.newsbeuter/*lock*    2>/dev/null
rm ~/feh_*_filelist        2>/dev/null
rm ~/.xsel.log             2>/dev/null
rm ~/.w3m/w3mtmp*.gz       2>/dev/null
rm ~/.gnuplot.*.stderr.log 2>/dev/null
rm ~/.w3m/w3mtmp*.gz       2>/dev/null
rm ~/.z.*                  2>/dev/null
cp ~/.xsession-errors ~/.xsession-errors.last
sed -ir '/chat|tumblr|porn|4chan|movies|/d' ~/.cd_history 2>/dev/null
sed -ir '/chat|tumblr|porn|4chan|movies|/d' ~/.bash_history 2>/dev/null

echo " * Pausing MPD..."  | tee -a  ~/.xsession-errors
mpc pause 1>/dev/null 2>&1

echo -n " * Shutdown..." | tee -a  ~/.xsession-errors
dots
sudo /sbin/poweroff 

#  if [[ "$1" == "poweroff" ]] ; then
#      # echo -n "Schedule 500 All Close" | tee -a  ~/.xsession-errors
#      # FvwmCommand "Schedule 500 All Close"
#      # echo -n "Schedule 1000 All Destroy" | tee -a  ~/.xsession-errors
#      # FvwmCommand "Schedule 1000 All Destroy"
#      # echo -n "/sbin/poweroff" | tee -a  ~/.xsession-errors
#  elif [[ "$1" == "reboot" ]] ; then
#      echo -n " * Rebooting..."
#      dots
#      # FvwmCommand "Schedule 500 All Close"
#      # FvwmCommand "Schedule 1000 All Destroy"
#      sudo /sbin/reboot
#  fi














