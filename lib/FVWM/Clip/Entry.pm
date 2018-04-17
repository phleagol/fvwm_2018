package FVWM::Clip::Entry ;
use utf8 ;
use v5.26 ;
use Moo ;
use namespace::clean ;

use Text::Unidecode qw( unidecode ) ;
use List::Util      qw( none all any ) ;
use File::LibMagic ;

has [qw( md5 linkpath linkmenu_name linkmenu_title maxchars )] => ( is => 'ro', require => 1 ) ;
has [qw( type icon label linkmenu launchers trigger_cmds )]    => ( is => 'lazy' ) ;

##  Regex matches for type "url_image"
has _regex_image => ( is => 'rw', default => sub {[
        qr{[.](png|jpg|jpeg|gif)([?].*)?$},
        qr{://(www[.])?imgur[.]com.*/[a-zA-Z0-9]+$},
        qr{://(www[.])?scrot[.]moe/image.*/[a-zA-Z0-9]+$},
        qr{://(www[.])?ibb.co/\w+},
    ]}) ;

##  Regex matches for type "url_video_ytdl" 
has _regex_ytdl => ( is => 'rw', default => sub {[
        qr{://(www[.])?youtu[.]be/},
        qr{://(www[.])?youtube[.]com/},
    ]}) ;

##  Regex matches for type "url_video_other" 
has _regex_video => ( is => 'rw', default => sub {[
        qr{://(www[.])?instagram[.]com/},
        qr{://(www[.])?gfycat[.]com/},
        qr{://(www[.])?twitter[.]com/},
        qr{tumblr[.]com/video_file},
        qr{webm|mp4|mkv|gifv},
    ]}) ;

#  https://thomaz-t69.tumblr.com/video_file/t:zZ-fyjHdn4EuSDJ8T4q7eA/171417487274/tumblr_p4nr2s10eh1th768t/480

##  Regex matches for type "url_video_stream" 
has _regex_stream => ( is => 'rw', default => sub {[
        qr{://(www[.])?twitch[.]tv/\w+},
        qr{://(www[.])?chaturbate[.]com/\w+/},
        qr{://(www[.])?cam4[.]com/\w+/},
        qr{://(www[.])?bongacams[.]com/\w+/},
        qr{://(www[.])?euronews[.]com/\w+/},
    ]}) ;

##  Find the entrys type, using some adhoc mimetyping.
sub _build_type  {
    my $self = shift ;
    my $linkpath = $self->linkpath ;
    my @lines = $linkpath->lines_utf8( { chomp => 1, count => 2 } ) ;
    my $first = $lines[0] ;

    my $type = "multiline" ;
    if (@lines == 1) {
        $type = "singleline" ;
        if ($first =~ m{^http[s]?://}) {
            (my $url = $first) =~ s|#.*$|| ; 
            $url =~ s/[?&]utm_.*$// ;                     ## strip redundant utm tokens 
            if (any {$url =~ $_} @{$self->_regex_image})        { $type = "url_image"
            } elsif (any {$url =~ $_} @{$self->_regex_ytdl})    { $type = "url_video_ytdl"
            } elsif (any {$url =~ $_} @{$self->_regex_video})   { $type = "url_video_other"
            } elsif (any {$url =~ $_} @{$self->_regex_stream})  { $type = "url_video_stream"
            } elsif ($url =~ m{://boards.4chan.org})            { $type = "url_video_4chan"
            } elsif ($url =~ /[.]torrent$/)                     { $type = "url_torrent"
            } else                                              { $type = "url_other"
            }
        } elsif ($first =~ m{^/} or $first =~ m{^file:///} or $first =~ m{^[~]}) {
            (my $file = $first) =~ s|^file://|| ;
            $file =~ s|^[~]|$ENV{HOME}| ;
            my $filetype = $self->_filetype($file) ;
            if (-e $file) {
                if ( -d $file )                              { $type = "file_folder"
                } elsif ($filetype eq "video")               { $type = "file_video"
                } elsif ($filetype eq "audio")               { $type = "file_audio"
                } elsif ($filetype eq "image")               { $type = "file_image"
                } elsif ($filetype eq "pdf")                 { $type = "file_pdf"
                } elsif ($file =~ qr{[.](html|htm|maff)$})   { $type = "file_html"
                } elsif ($filetype eq "executable")          { $type = "file_exec"
                } elsif (-x $file and $filetype eq "text")   { $type = "file_text_exec"
                } elsif ($filetype eq "text")                { $type = "file_text"
                } else                                       { $type = "file_other" 
                }
            }
        } elsif ($first =~ /^magnet[:][?]/)       { $type = "url_magnet" 
        } elsif ($first =~ /^\s*[a-zA-z]+\s*$/ )  { $type = "singleword" 
        }
    }
    #say STDERR "type == $type" ;
    return $type ;
}

##  Build a label suitable for a fvwm menu.
sub _build_label  {
    my $self = shift ;
    my $linkpath = $self->linkpath ;
    my $type = $self->type ;
    my $max_chars = $self->maxchars ;

    ##  Obtain the first line with word chars.
    my $label = "--" ;
    foreach my $line ( $linkpath->lines_utf8({ chomp => 1 }) )  {
        if ($line =~ /\w|\d/) { $label = $line ; last }
    } ;

    ##  Shorten filenames, restrict label length, and limit chars to ascii.
    unidecode $label ;
    if ( $type =~ /^url/ ) {
        $label =~ s|^https?://|| ;
        $label = substr $label, 0, $max_chars ;
    } elsif ( $type =~ /^file/ ) {
        $label =~ s|^$ENV{HOME}|\~| ;
        while ( length($label) > $max_chars and $label =~ s|/([^/])[^/]+/|/$1/| ) { }
        my $num = length($label) - $max_chars ;
        $label = "..." . substr($label, $num+3) if $num > 0 ;
    } else { $label = substr $label, 0, $max_chars ;
    }

    ##  Escape/delete/replace special chars etc, such that the label will 
    ##  display correctly within a fvwm menu .
    for ($label)  {
        s/[%\$\*\\]+//g ;
        s/([\[\]\#\'\?\^`!@;])/\\$1/g ;
        s/&/&&/g ; 
        s/\s+/ /g ;
        s/^\s*//g ;
        s/^www[.]//g ;
        s/^\s*$/--/ ;
    }
    return $label ;
}

sub _build_icon {
    my $self = shift ;
    my $type = $self->type ;
    my %icons = (
        url_torrent      => '$[infostore.icon_cb_url_torrent_type]', 
        url_other        => '$[infostore.icon_cb_url_other_type]',     
        url_image        => '$[infostore.icon_cb_url_image_type]',     
        url_video_other  => '$[infostore.icon_cb_url_video_type]',
        url_video_ytdl   => '$[infostore.icon_cb_url_youtube_type]',
        url_video_4chan  => '$[infostore.icon_cb_url_other_type]',
        url_video_stream => '$[infostore.icon_cb_url_video_type]',
        url_magnet       => '$[infostore.icon_cb_magnet_type]',
        file_folder      => '$[infostore.icon_cb_folder_type]',   
        file_video       => '$[infostore.icon_cb_file_video_type]',
        file_audio       => '$[infostore.icon_cb_file_audio_type]',  
        file_image       => '$[infostore.icon_cb_file_image_type]',      
        file_pdf         => '$[infostore.icon_cb_file_pdf_type]',    
        file_html        => '$[infostore.icon_cb_file_html_type]',
        file_exec        => '$[infostore.icon_cb_file_exec_type]',     
        file_text_exec   => '$[infostore.icon_cb_file_exec_type]',     
        file_text        => '$[infostore.icon_cb_file_other_type]',  
        file_other       => '$[infostore.icon_cb_file_other_type]',  
        singleword       => '$[infostore.icon_cb_other_type]',
        multiword        => '$[infostore.icon_cb_other_type]',
        singleline       => '$[infostore.icon_cb_other_type]',
        multiline        => '$[infostore.icon_cb_other_type]',
    ) ;
    return $icons{$type} ;
}

##  Generate an fvwm link menu.
sub _build_linkmenu {
    my $self  = shift ;
    my $type  = $self->type ;
    my $label = $self->label ;
    my $linkpath  = $self->linkpath ;

    ##  Only certains type allowed a linkmenu.
    return [] if $type !~ /^url/ ;
    return [] if any { $_ eq $type } qw( url_torrent url_magnet ) ;

    my $sxiv = 0 ;
    my ($ytdl_best, $ytdl_480p, $ytdl_720p )          = (0) x 3 ;
    my ($mpv_best, $mpv_720p, $mpv_360p, $mpv_4chan ) = (0) x 4 ;
    my ($stream_720p, $stream_480p, $stream_other)    = (0) x 3 ;

    if ($type eq "url_video_ytdl")       { 
        ($mpv_720p, $mpv_360p, $ytdl_480p, $ytdl_720p, $stream_720p, $stream_480p) = (1) x 6 ;
    } elsif ($type eq "url_video_other")  { $mpv_best = 1 ; $ytdl_best = 1 ;
    } elsif ($type eq "url_video_4chan")  { $mpv_4chan = 1 ;
    } elsif ($type eq "url_video_stream") { $stream_other = 1 ;
    } elsif ($type eq "url_image")        { $sxiv = 1 ;
    } ;

    my ($divider1, $divider2, $divider3) = (0) x 3 ;
    $divider1++ if any { $_ } ( $mpv_best, $mpv_720p, $mpv_360p, $mpv_4chan ) ;
    $divider2++ if any { $_ } ( $stream_720p, $stream_480p, $stream_other ) ;
    $divider3++ if any { $_ } ( $ytdl_best, $ytdl_480p, $ytdl_720p ) ;

    my @menu ;
    my $name  = $self->linkmenu_name ;
    my $title = $self->linkmenu_title ;
    push @menu, "\"\$[infostore.icon_cb_firefox_app]&Firefox\"    OpenFirefox xsel" ;
    push @menu, "\"\$[infostore.icon_cb_palemoon_app]P&aleMoon\"  OpenPaleMoon xsel" ;
    push @menu, "\"\$[infostore.icon_cb_chromium_app]&Chromium\"  OpenChromium xsel" ;
    push @menu, "\"\$[infostore.icon_cb_dillo_app]&Dillo\"        OpenDillo" ;
    push @menu, "\"\$[infostore.icon_cb_sxiv_app]&Sxiv\"          Module SxivGet" if $sxiv ;
    push @menu, " \"\" Nop" if $divider1 ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]Mpv 360p\"        MPV360p"    if $mpv_360p ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]Mp&v 720p\"       MPV720p"    if $mpv_720p ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]Mp&v (4chan)\"    MPV4Chan"   if $mpv_4chan ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]Mp&v\"            MPVBest"    if $mpv_best ;
    push @menu, " \"\" Nop" if $divider2 ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]Stream 480p\"     Stream480p" if $stream_480p ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]&Stream 720p\"    Stream720p" if $stream_720p ;
    push @menu, "\"\$[infostore.icon_cb_mpv_app]&Streamlink\"     StreamBest" if $stream_other ;
    push @menu, " \"\" Nop" if $divider3 ;
    push @menu, "\"\$[infostore.icon_cb_ytdl_add_app]Ytdl 480p\"  Ytdl480p"   if $ytdl_480p ;
    push @menu, "\"\$[infostore.icon_cb_ytdl_add_app]&Ytdl 720p\" Ytdl720p"   if $ytdl_720p ;
    push @menu, "\"\$[infostore.icon_cb_ytdl_add_app]Ytdl\"       YtdlBest"   if $ytdl_best ;

    substr($_, 0, 0) = "AddToMenu $name " foreach @menu ;
    unshift @menu, "AddToMenu $name \"$title\" Title" ; 
    unshift @menu, "DestroyMenu $name" ;
    #push @menu, "FF-Message 1 $label" ;
    push @menu, "Menu $name Root c c " ;
    return \@menu ;
}

##  Extra launchers for bottom of clipmenu. Headless menu entries.
sub _build_launchers {
    my $self  = shift ;
    my $type  = $self->type ;
    my $label = $self->label ;
    my @entrys = () ;

    return [] if $type =~ /singleline|url_magnet|url_torrent/ ;
    push @entrys, " '' Nop" ;

    my $cmd = "\'\$[infostore.icon_cb_pastebin_app]&PasteBin\' PasteBin" ;
    push @entrys, $cmd if $type =~ /file_text|multiline/ ;
    $cmd = "\'\$[infostore.icon_cb_gvim_app]&Open in Vim\' OpenVim" ;
    push @entrys, $cmd if $type =~ /file_text/ ;
    $cmd = "\'\$[infostore.icon_cb_tinyurl_app]&TinyURL\' Module TinyURL" ;
    push @entrys, $cmd if $type =~ /^url/ ;
    $cmd = "\'\$[infostore.icon_cb_dictionary_app]&Dictionary\' Module FvwmDict $label" ;
    push @entrys, $cmd if $type eq "singleword" ;
    $cmd = "\'\$[infostore.icon_cb_upload_app]&Imgur Upload\' ImageUpload" ;
    push @entrys, $cmd if $type eq "file_image" ;
    $cmd  = "\'\$[infostore.icon_cb_upload_app]&Transfer.sh\' " ;
    $cmd .= 'Exec $[FVWM_BIN]/transfer-xsel.sh' ;
    push @entrys, $cmd if $type =~ /^file/ ;
    $cmd = "\'\$[infostore.icon_cb_lsof_app]&List Open Files\' ListOpenFiles" ;
    push @entrys, $cmd if $type =~ /file_folder/ ;
    return \@entrys ;
}

##  Commands for this entry, triggered by type.
sub _build_trigger_cmds {
    my $self  = shift ;
    my $type  = $self->type ;
    my @commands = () ;
    push @commands,  "FF-AddTorrent" if $type =~ /magnet|torrent/ ;
    return \@commands ;
}

sub _filetype {
    my ($self, $file) = @_ ;
    my $magic = File::LibMagic->new() ;
    my $info = $magic->info_from_filename($file) ;
    my $type = $info->{mime_type} ;
    return "pdf" if $type eq "application/pdf" ;
    return "executable" if $type =~ /(executable|sharedlib)$/ ;
    $type =~ s|/.*|| ;
    return $type ;
}

1984 ;

