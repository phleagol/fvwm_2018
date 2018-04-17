package FVWM::Mount::Vfat ;
use utf8 ;
use v5.26 ;
use Moo ;
use namespace::clean ;

use Path::Tiny ;
#use Data::Dump qw( dump ) ;

has device => ( is => 'ro', require => 1 ) ;
has [qw( subdevice label mountpoint _rw status )] => ( is => 'lazy' ) ;

# has [qw( md5 linkpath linkmenu_name linkmenu_title maxchars )] => ( is => 'ro', require => 1 ) ;

##  Device's basename.
sub _build_subdevice {
    my $self = shift ;
    (my $subdev = $self->device) =~ s{^.*\/}{} ;
    return $subdev ;
}

##  The device label if available via lsblk.
sub _build_label {
    my $self = shift ;
    my $subdev = $self->subdevice ;
    my $re = qr/vfat.+="${subdev}"/ ;
    my ( $lsblk ) = grep { $_ =~ $re } readpipe('lsblk -Pno FSTYPE,NAME,LABEL,MOUNTPOINT') ;
    my $label = $subdev ;
    $label = $1 if defined $lsblk and $lsblk =~ /LABEL="([^"]+)"/ ;
    return $label ;
}

##  The device mountpoint if available via mtab?
sub _build_mountpoint { 
    my $self = shift ;
    my $device = $self->device ;
    my $re = qr/^${device}\s.*\svfat\s/ ;
    my ( $mtab ) = grep { $_ =~ $re } path('/etc/mtab')->lines ;
    return 0 unless defined $mtab ;
    chomp $mtab ;
    my $mntpnt = 0 ;
    $mntpnt = $1 if $mtab =~ /^\S+\s+(\S+)\s/ ;
    return $mntpnt ;
}

##  Is device mounted "rw" according to /proc/mounts?
sub _build__rw { 
    my $self = shift ;
    my $device = $self->device ;
    my $re = qr/^${device}\s.*\svfat\s/ ;
    my ( $procmnt ) = grep { $_ =~ $re } path('/proc/mounts')->lines ;
    return 0 unless defined $procmnt ;
    return ($procmnt =~ /\sro[,\s]/) ? 0 : 1 ;
}

##  Mount status for this vfat device.
sub _build_status {
    my $self = shift ;
    if (not $self->mountpoint)                 { return "unmounted" ;
    } elsif ($self->mountpoint and $self->_rw) { return "mounted" ;
    } else                                     { return "hanging" ;
    }
}

1984 ;

