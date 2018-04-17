## vim: syntax=perl
package FVWM::Thumb ;
use v5.26 ;
use Moo ;
use namespace::clean ;

##  Perlmagick
##  https://www.imagemagick.org/script/perl-magick.php
##  Set Opacity
##  https://www.imagemagick.org/discourse-server/viewtopic.php?f=7&t=33779
##  Set Brightness/contrast
##  http://www.imagemagick.org/discourse-server/viewtopic.php?f=7&t=33234

use Path::Tiny ;
use Image::Magick ;
use Time::Piece ;
use File::stat ;
use IPC::Run qw( run timeout ) ;
#use Data::Dump qw( dump ) ;

##  Attributes from the fvwm moduleconfig.
has [qw(
  Name Folder Expires Fifo Height Width 
  CanvasColor CanvasSize InsetBorderColor  
  InsetBorderGeometry Logfile MiniIconResize
  Opacity Brightness
)] => ( is => 'ro', require => 1 ) ;

has [qw( _win_id  _miniicon_file )] => ( is => 'rw' ) ;
has [qw( _pngfile _xwdfile       )] => ( is => 'lazy', clearer => 1 ) ;
has [qw( _logfile _folder        )] => ( is => 'lazy' ) ;

##  Target folder for saving thumbnails.
sub _build__folder  {
    my $self = shift ;
    my $folder = path($self->Folder) ;
    $folder->mkpath unless $folder->exists ;
    $_->remove foreach $folder->children( qr/xwd$/ ) ;
    return $folder ;
}

sub _build__logfile  {
    my $self = shift ;
    my $name = $self->Name ;
    my $logfile = path( $self->Logfile ) ;
    $logfile->append("\n\n============================") ;
    $logfile->append("\nStarting $name daemon...") ;
    $logfile->append("\n============================\n\n") ;
    return $logfile ;
}

##  Filepath to saved png thumbnail for current window id.
sub _build__pngfile  {
    my $self = shift ;
    my $id = $self->_win_id ;
    return $self->_folder->child("${id}.png") ;
}

##  Filepath to saved xwd snapshot for current window id.
sub _build__xwdfile  {
    my $self = shift ;
    my $id = $self->_win_id ;
    return $self->_folder->child("${id}.xwd") ;
}

##  Receive requests to thumbnail the current window.
##  Proceed only when a new thumbnail is actually needed.
sub request {
    my ($self, $win_id, $miniicon_file) = @_ ;
    $self->_clear_pngfile ;
    $self->_clear_xwdfile ;
    $self->_win_id( $win_id ) ;
    $self->_miniicon_file( $miniicon_file ) ;
    if ( $self->_icon_still_fresh ) {
        $self->_logger("") ;
        $self->_logger("current thumb still valid") ;
        return 2 ;
    }
    return $self->_thumbnail ;
}

##  Returns true only if thumbnail already exists and is still fresh (not expired).
sub _icon_still_fresh {
    my $self = shift ;
    my $pngfile = $self->_pngfile ;
    return 0 unless $pngfile->exists ;
    my $diff = time() - stat($pngfile)->mtime ;
    return $diff < $self->Expires ? 1 : 0 ;
}

##  Create thumbnail for current window. All steps from capture to save.
sub _thumbnail  {
    my $self   = shift ;
    my $width  = $self->Width ;
    my $height = $self->Height ;
    $self->_logger("     ") ;

    ##  Capture + reduce + crop + save.
    ##  my $thumb = $self->_capture or return 0 ;  DOES THIS WORK ???
    my $thumb = $self->_capture ;
    return 0 unless $thumb ;
    $self->_logger("capture() : passed ") ;
    return 0 if $thumb->Thumbnail(geometry => "${width}x$height^") ;
    $self->_logger("thumbnail() : Thumbnail() passed ") ;
    return 0 if $thumb->Crop(geometry => "${width}x$height+0+0") ;
    $self->_logger("thumbnail() : Crop() passed ") ;
    $thumb = $self->_set_brightness($thumb) ;
    $thumb = $self->_set_opacity($thumb) ;
    $thumb = $self->_add_miniicon($thumb) ;
    return $self->_save_image($thumb) ;
}

##  Capture raw image for current window. Return as an imagemagick object.
sub _capture  {
    my $self = shift ;
    my $thumb = Image::Magick->new ;
    my $xwdfile = $self->_xwdfile ;
    my $wid = $self->_win_id ;
    #$self->_logger("capture ") ;
    my $out = my $in = my $stderr = "" ;
    my $retval = eval {
        my @cmd = ( "xwd", "-silent", "-nobdrs", "-id", $wid, "-out", $xwdfile, ) ;
        run \@cmd, \$in, \$out, \$stderr, timeout(2) ;
        1 ;
    } ;
    if (not $retval) {
        say STDERR $@ ;
        $xwdfile->remove ;
        return 0 ;
    } elsif ($stderr or not $xwdfile->exists)  {
        $self->_logger("capture() : xwd failed") ;
        $xwdfile->remove ;
        return 0 ;
    } else {
        my $err = $thumb->Read($xwdfile) ;
        $xwdfile->remove ;
        $self->_logger("capture() : Read() fails for xwdfile")  if $err ;
        #$self->_logger("capture() : Read() passes for xwdfile") unless $err ;
        return $err ? 0 : $thumb ;
    }
}

##  Extra step to add miniicon to the thumbnail, if possible.
sub _add_miniicon  {
    my ($self, $thumb) = @_ ;
    return $thumb unless -r $self->_miniicon_file ;
    my $mini = $self->_read_image( $self->_miniicon_file ) or return $thumb ;
    return $thumb if $mini->Resize(geometry => $self->MiniIconResize) ;
    my $canvas = Image::Magick->new() ;
    $canvas->Set(size => $self->CanvasSize) ;
    my $color = $self->CanvasColor ;
    return $thumb if $canvas->ReadImage("canvas:$color") ;
    return $thumb if $canvas->Composite(image => $mini, gravity => "Center") ;
    return $thumb if $canvas->Splice(
        gravity    => "northwest",
        geometry   => $self->InsetBorderGeometry,
        background => $self->InsetBorderColor,
    ) ;
    my $img = $thumb ;
    return $thumb if $img->Composite(image => $canvas, gravity => "SouthEast") ;
    $self->_logger("_add_miniicon() : thumb Composite passed ") ;
    return $img ;
}

sub _set_brightness  {
    my ($self, $img) = @_ ;
    my $orig = $img ;
    my $multiple = $self->Brightness ;
    return $img if $multiple == 1 ;
    my $err = $img->Evaluate(value => $multiple, operator => "Multiply") ;
    $self->_logger("_set_brightness : Brighten : Evalute/multiply failed :  $err") if $err ;
    $self->_logger("_set_brightness : Brighten : PASS") unless $err ;
    return $err ? $orig : $img ;
}

sub _set_opacity  {
    my ($self, $img) = @_ ;
    my $orig = $img ;
    my $multiple = $self->Opacity ;
    return $img if $multiple == 1 ;
    my $err = $img->Set( alpha => 'Set' ) ;
    $self->_logger("_set_opacity :  Set Alpha failed : $err") if $err ;
    return $orig if $err ;
    $err = $img->Evaluate( channel => 'Alpha', operator => "Multiply", value => $multiple ) ;
    $self->_logger("_set_opacity : Evalute/multiply failed : $err") if $err ;
    $self->_logger("_set_opacity : Opacity : PASS") unless $err ;
    return $err ? $orig : $img ;
}

##  Load imagemagick object from image file.
sub _read_image {
    my ($self, $file) = @_ ;
    my $ret = open(IMAGE, $file) ;
    unless ( $ret ) {
        $self->_logger("_read_image : Cannot OPEN image file") ;
        $self->_logger($file) ;
        return 0 ;
    }
    my $img = Image::Magick->New(quality => 100) ;
    my $err = $img->Read(file => \*IMAGE) ;
    close(IMAGE) ;
    $self->_logger("_read_image : Cannot load image file") if $err ;
    $self->_logger($file) if $err ;
    return $err ? 0 : $img ;
}

##  Write imagemagick object to png file, carefully.
sub _save_image {
    my ( $self, $img ) = @_ ;
    my $pngfile  = $self->_pngfile ;
    my $pngtemp  = Path::Tiny->tempfile(SUFFIX => '.png') ;
    my $tempname = $pngtemp->stringify ;
    my $ret = open(IMAGE, ">$tempname") ;
    unless ( $ret ) {
        $self->_logger("_save_image : Cannot OPEN image file") ;
        $self->_logger($pngfile) ;
        return 0 ;
    }
    my $err = $img->Write(
        file => \*IMAGE, 
        filename => $tempname, 
        quality => 100,
        ) ;
    close(IMAGE) ;
    if ($err) { 
        $self->_logger("_save_image : Write failed") ;
        return 0 ;
    } elsif ( $self->_validate_image($tempname) ) {
        $self->_logger("_save_image : Write passed") unless $err ;
        $pngtemp->copy($pngfile) ;
        return 1 ;
    } else {
        $self->_logger("_save_image : Image written but NOT validated") ;
        return 0 ;
    }
}

sub _validate_image {
    my ( $self, $file ) = @_ ;
    my $img = Image::Magick->New ;
    my $err = $img->Read($file) ;
    return $err ? 0 : 1 ;
}

sub _logger {
    my ($self, $msg) = @_ ;
    my $t = localtime ;
    return 0 unless $self->_logfile ;
    $msg =  $t->hms . " " . $self->_win_id . " $msg\n" ;
    #print STDERR "$msg" ;
    $self->_logfile->append_utf8($msg) ; 
}

1984 ;

