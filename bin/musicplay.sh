#!/bin/bash

## ./play.sh --playlist $HOME/.fvwm-custom/playlists/strings-yt1.m3u

##  ./play.sh --next
##  ./play.sh --prev
##  c && ./play.sh --toggle
##  c && ./play.sh --stop
##  c && ./play.sh --play 19 --playlist $HOME/.fvwm-custom/playlists/strings-yt1.m3u

SOCKET=/tmp/mpvsocket
YTFORMAT="93/18/134+251/134+171/134+140/134+250/134+249/243+251/243+171/243+140/243+250/243+249"

main() {

    action=
    playlist=
    track=

    TEMP=$(getopt -o '' -l 'next,prev,toggle,stop,play:,playlist:' -n 'playtrack' -- "$@")
    eval set -- "$TEMP"
    unset TEMP

    while true; do
        case "$1" in
            '--next')
                action="next"
                shift
                continue
            ;;
            '--prev')
                action="prev"
                shift
                continue
            ;;
            '--stop')
                action="stop"
                shift
                continue
            ;;
            '--toggle')
                action="toggle"
                shift
                continue
            ;;
            '--play')
                action="play"
                track="$2"
                shift 2
                continue
            ;;
            '--playlist')
                playlist="$2"
                shift 2
                continue
            ;;
            '--')
                shift
                break
            ;;
            *)
                echo 'Internal error!' >&2
                exit 1
            ;;
        esac
    done

    mpv=$(mpv_status)
    mpd=$(mpd_status)

#    echo "action:     $action"   1>&2
#    echo "list:       $playlist" 1>&2
#    echo "track:      $track"    1>&2
#    echo "mpv_status: $mpv"      1>&2
#    echo "mpd_status: $mpd"      1>&2
#    echo "---------------------" 1>&2

    [[ $mpv == "none" ]] && mpv_restart

    if [[ $action == play ]] ; then
#        echo AAA 1>&2
        [[ -z $track ]]    && exitmsg "track not defined"
        [[ -z $playlist ]] && exitmsg "playlist not defined"
        [[ -e $playlist ]] || exitmsg "playlist path not found"
        [[ $mpd == play ]] && mpc pause 1>/dev/null
        mpv_send "loadlist \"$playlist\" replace" 
        mpv_send "no-osd set playlist-pos $track"
        mpv_send "no-osd set pause no"

    elif [[ $action == toggle ]] ; then
#        echo BBB  1>&2
        [[ $mpd == play ]]  && mpc pause 1>/dev/null
        [[ $mpv == play ]]  && mpv_send "no-osd set pause yes"
        [[ $mpv == pause ]] && mpv_send "no-osd set pause no"
        [[ $mpd == pause && $mpv =~ stop|none ]] && mpc toggle 1>/dev/null

    elif [[ $action =~ next|prev ]] ; then
#        echo CCC  1>&2
        if [[ $mpv =~ pause|play ]] ; then
            [[ $action == next ]] &&  mpv_send "playlist-next"
            [[ $action == prev ]] &&  mpv_send "playlist-prev"
            mpv_send "no-osd set pause no"
        else [[ $mpd =~ pause|play ]] && mpc $action 1>/dev/null
        fi

    elif [[ $action == stop ]] ; then
#        echo DDD  1>&2
        [[ $mpd == play ]] && mpc stop  1>/dev/null
        [[ $mpv == pause || $mpv == play ]] && mpv_send 'stop'
    fi

    exit
}


####  FUNCTIONS

mpv_send() { echo "$*" | socat - $SOCKET 1>/dev/null ; }

mpv_restart() {
    if ! pgrep -f "mpv.*$SOCKET.*--idle" 1>/dev/null ; then
        rm $SOCKET 2>/dev/null
        echo "Starting mpv..." 2>&1
        mpv --quiet --no-terminal --x11-name mpvd --loop-playlist \
            --ytdl-format="$YTFORMAT" --input-ipc-server=$SOCKET --idle &
        #mpv --quite --no-terminal --loop-playlist --ytdl-format="$YTFORMAT" \
        #    --input-ipc-server=/tmp/mpvsocket --idle &
        while ! [[ -e $SOCKET ]] ; do sleep .2 ; done
    fi
}

mpv_status() {
    status=play
    pgrep -f "mpv.*$SOCKET.*--idle" 1>/dev/null || { echo "none" ; return ; }
    echo '{ "command": ["get_property", "pause"] }' | 
      socat - $SOCKET | grep -q 'true.*success' && status=pause
    echo '{ "command": ["get_property", "idle-active"] }' |
      socat - $SOCKET | grep -q 'true.*success' && status=stop
    echo $status
}

mpd_status() {
    status=stop
    pgrep mpd 1>/dev/null || { echo "none" ; return ; }
    mpc | grep -q playing && status=play
    mpc | grep -q paused  && status=pause
    echo $status
}

exitmsg() { echo "$*" 1>&2 ; exit ; }

main "$@"



















