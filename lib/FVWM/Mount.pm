package FVWM::Mount ;
use utf8 ;
use v5.26 ;
use Moo ;
use namespace::clean ;

use Path::Tiny ;
use FVWM::Mount::Vfat ;
use Data::Dump qw( dump ) ;

#has [qw( md5 linkpath linkmenu_name linkmenu_title maxchars )] => ( is => 'ro', require => 1 ) ;
# has [qw( type icon label linkmenu launchers trigger_cmds )]    => ( is => 'lazy' ) ;

# has [qw(
#         MenuName MenuTitle AptUpdateFile 
#     )] => ( is => 'ro', require => 1 ) ;




has [qw(
    _mounted _apt_entry  _vfats _vfat_entries _tombs _mounted_tombs_num _tomb_entries  
    )] => ( is => 'lazy' ) ;

has [qw(
    Name Module MountFolder TombFolder MenuName MenuTitle AptUpdateFile
    )] => ( is => 'ro', require => 1 ) ;

has _icon_mounted   => ( is => 'rw', default => '$[infostore.icon_mt_tick]' ) ;
has _icon_unmounted => ( is => 'rw', default => '$[infostore.icon_mt_null]' ) ;
has _icon_hanging   => ( is => 'rw', default => '$[infostore.icon_wm_application_exit]' ) ;
has _icon_locked    => ( is => 'rw', default => '$[infostore.icon_mt_tomb]' ) ;
has _icon_apt       => ( is => 'rw', default => '$[infostore.icon_mt_apt_update]' ) ;

##  ##  temporary
##  has MountFolder => ( is => 'rw', default => '/media' ) ;
##  has TombFolder  => ( is => 'rw', default => '/home/phleagol/tomb' ) ;
##  has MenuName  => ( is => 'rw', default => 'FvwmMount_YadaYada' ) ;
##  has MenuTitle  => ( is => 'rw', default => 'Mount Menu' ) ;
##  has AptUpdateFile  => ( is => 'rw', default => '/home/phleagol/.apt_update' ) ;

##  List of mountpoints in current usage. COULD USE MTAB INSTEAD?
sub _build__mounted {
    my %mounts = () ;
    foreach (`lsblk -Pno MOUNTPOINT`) { $mounts{$1}++ if m{^MOUNTPOINT="(/[^"]+)"} }
    return \%mounts ;
}

##  List of vfat filesystems found.
sub _build__vfats {
    my @devs = () ; my @vfats = () ;
    foreach (`lsblk -Pno FSTYPE,NAME`) { push @devs, $1 if /vfat.*NAME="(\S+)"/ }
    @devs = map { '/dev/' . $_ }
            sort { $a cmp $b }
            grep { $_ !~ /^sda/ } @devs ;
    foreach (@devs) { push @vfats, FVWM::Mount::Vfat->new({ device => $_ }) } ;
    return \@vfats ;
}

##  List of valid tombs found..
sub _build__tombs {
    my $self = shift ;
    my @tombs = () ;
    my $mountdir = path( $self->MountFolder ) ;
    my $tombdir  = path( $self->TombFolder ) ;
    my %mounted = %{ $self->_mounted } ;
    foreach my $tomb ( sort($tombdir->children( qr/\.tomb$/ )) ) {
        my $key = $tombdir->child($tomb->basename . ".key") ; 
        next unless $tomb->is_file and $key->is_file ;
        my $label = $tomb->basename('.tomb') ;
        my $mount = $mountdir->child($label) ;
        my $status = defined($mounted{$mount}) ? "mounted" : "unmounted" ;
        push @tombs, {
            tomb       => $tomb->stringify, 
            key        => $key->stringify,
            label      => $label,
            status     => $status, 
            mountpoint => $mount->stringify 
        } ;
    }
    return \@tombs ;
}

##  Count the mounted tombs, and return an integer.
sub _build__mounted_tombs_num {
    my $self = shift ;
    my $cnt = 0 ;
    foreach my $tomb (@{ $self->_tombs }) { $cnt++ if $tomb->{status} eq "mounted" } ;
    return $cnt ;
}

##  Hanging menu entries for vfat devices.
sub _build__vfat_entries {
    my $self = shift ;
    my @entries = () ;
    my $mountdir = path( $self->MountFolder ) ;
    foreach my $vfat (@{ $self->_vfats }) {
        my $dev    = $vfat->device ;
        my $subdev = $vfat->subdevice ;
        my $label  = $vfat->label ;
        my $mnt    = $vfat->mountpoint || $mountdir->child($label)  ;
        my $status = $vfat->status ;
        my ($icon, $cmd) ;
        if ($status eq "mounted")        {
            $icon = $self->_icon_mounted ;
            $cmd = "VfatUnmount \"$dev\" \"$mnt\" \"$label\"" ;
        } elsif ($status eq "unmounted") {
            $icon = $self->_icon_unmounted ;
            $cmd = "VfatMount \"$dev\" \"$mnt\" \"$label\"" ;
        } else { 
            $icon = $self->_icon_hanging ;
            $cmd = "VfatUnmount \"$dev\" \"$mnt\" \"$label\"" ;
        }
        push @entries, "\"${icon}${label}\t${subdev}\" $cmd" ;
    }
    return \@entries ;
}

##  Hanging menu entries for tombs.
sub _build__tomb_entries {
    my $self = shift ;
    my @entries = () ;
    foreach my $tomb (@{ $self->_tombs }) {
        my ($icon, $cmd) ;
        my $label = $tomb->{label} ;
        my $key   = $tomb->{key} ;
        my $luks  = $tomb->{tomb} ;
        my $mnt   = $tomb->{mountpoint} ;
        my $status  = $tomb->{status} ;
        if ($status eq "mounted") {
            $icon = $self->_icon_mounted ;
            $cmd = "TombUmount \"$luks\" \"$key\" \"$label\" \"$mnt\"" ;       
        } elsif ($status eq "unmounted") {
            $icon = $self->_icon_unmounted ;
            $cmd = "TombMount  \"$luks\" \"$key\" \"$label\" \"$mnt\"" ;
        }
        push @entries, "\"${icon}&${label}\tluks\" $cmd" ;
    }
    return \@entries ;
}

sub _build__apt_entry {
    my $self = shift ;
    my $icon = $self->_icon_apt ;
    my $aptfile = $self->AptUpdateFile ;
    my ($apt ) = path( $aptfile )->lines( { chomp => 1, count => 1 } ) ;
    return "\"$icon&Apt Update\t$apt\" AptUpdate" ;
}

sub menu {
    my $self = shift ;
    my @menu  = () ;
    my $menuname  = $self->MenuName ;
    my $menutitle = $self->MenuTitle ;
    my @vfat_entries = @{ $self->_vfat_entries } ;
    my @tomb_entries = @{ $self->_tomb_entries } ;
    push @menu, @vfat_entries ;
    push @menu, '"" Nop' if @menu ;
    push @menu, @tomb_entries ;
    push @menu, '"" Nop' if @tomb_entries ;
    push @menu, $self->_apt_entry ;
    if ( $self->_mounted_tombs_num ) {
        my $icon = $self->_icon_locked ;
        push @menu, '"" Nop' ;
        push @menu, "\"${icon}Tomb Slam\" TombSlam" ;
    }
    substr($_, 0, 0) = "AddToMenu $menuname " foreach @menu ;
    unshift @menu, "AddToMenu   $menuname \"$menutitle\" Title" ;
    unshift @menu, "DestroyMenu $menuname " ;
    push @menu, "WindowId root 1 WarpToWindow 50 30 " ;
    push @menu, "Menu $menuname Root c c" ;
    $self->sendcmd( @menu ) ;
}

sub sendcmd {
    my $self = shift ;
    my $module = $self->Module ;
    foreach ( @_ ) {
        #$module->show_message($_) ;
        $module->send($_) ;
    }
}

1984 ;

