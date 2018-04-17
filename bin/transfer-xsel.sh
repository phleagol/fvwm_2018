#!/bin/bash

##  Upload file/folder found in xsel to the transfer.sh file hosting service.

##  https://gist.github.com/nl5887/a511f172d3fb3cd0e42d
##  https://github.com/dutchcoders/transfer.sh

arg="$(xsel -ob)"

if [[ -d "$arg" ]] ; then
    #echo "* Folder found..." >&2
    sleep 1
    base=$(basename "$arg" | sed -e 's/[^a-zA-Z0-9._-]/-/g')
    tmpdir=$(mktemp -d) 
    tmpfile=$(mktemp) 
    zipfile="$tmpdir/$base.tar.gz"
    cd "$(dirname $arg)"
    tar -c $base | gzip -8 > "$zipfile"
    curl --upload-file "$zipfile" "https://transfer.sh/$base.tar.gz" >> $tmpfile
    cat $tmpfile
    echo -n $tmpfile | xsel -ib
    rm -r $tmpdir $tmpfile

elif [[ -f "$arg" ]] ; then
    #echo "* File found..." >&2
    base=$(basename "$arg" | sed -e 's/[^a-zA-Z0-9._-]/-/g')
    tmpfile=$(mktemp) 
    curl --upload-file "$arg" "https://transfer.sh/$base" >> $tmpfile
    cat $tmpfile
    xsel -ib <$tmpfile 
    rm -r $tmpfile
fi


