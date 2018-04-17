## vim: syntax=perl
package FVWM::OpenW3m ;
use v5.24 ;
use Moo ;
use namespace::clean ;

use FVWM::Module;
use Path::Tiny ;
use Data::Dumper ;
use Data::Dump qw( dump ) ;

has name        => ( is => 'ro', required => 1 ) ;
has fvwmname    => ( is => 'ro', required => 1 ) ;
has _fvwmmodule => ( is => 'lazy' ) ;

has _config      => ( is => 'rw', default => sub { {} } ) ;
has _folder    => ( is => 'lazy' ) ;
has _list      => ( is => 'lazy' ) ;
has _font      => ( is => 'lazy', builder => sub { $_[0]->_read_config("Font") }) ;
has _geometry  => ( is => 'lazy', builder => sub { $_[0]->_read_config("Geometry") }) ;

sub _build__fvwmmodule  {
    my $self = shift ;
    my $modname = $self->fvwmname ;
    return new FVWM::Module( Name => $modname, Debug => 0 ) ;
}

sub _build__folder  {
    my $self = shift ;
    my $modname = $self->fvwmname ;
    my $folder = path( $self->_read_config("Folder") ) ;
    die "$modname : Folder not found $!" unless $folder->exists ;
    return $folder ;
}

sub _build__list  {
    my $self = shift ;
    my $module = $self->_fvwmmodule ;
    my $modname = $self->fvwmname ;
    my $name = $self->name ;
    my $list =  $self->_folder->child( $name . ".w3m" ) ;
    unless ( $list->exists ) {
        $module->send("FF-Message 4 W3M : $name not found.") ;
        die "$modname : list not found $!" ;
    }
    return $list ;
}

sub _handler_config_info {
    my ($self, $module, $event) = @_ ;
    my $modname = $self->fvwmname ;
    if ( $event->_text =~ /^\*$modname\s*(\w+)\s+(\S.*)$/ ) {
        my %confighash = %{ $self->_config } ; 
        (my $foo = $2) =~ s/\s+$// ;
        $confighash{$1} = $foo ;
        $self->_config( \%confighash ) ;
    }
}

sub _handler_config_info_end {
    my ($self, $module, $event) = @_ ;
    my $modname = $self->fvwmname ;
    $self->_setup_w3mtmux ;
}

##  Read specific value from the confighash. Used as a builder method.
sub _read_config {
    my ($self, $key) = @_ ;
    my $modname = $self->fvwmname ;
    my $module  = $self->_fvwmmodule ;
    my %confighash = %{ $self->_config } ; 
    die "[$modname] $key not set" unless defined $confighash{$key} ;
    return $confighash{$key} ;
}

sub start {
    my $self = shift ;
    my $modname = $self->fvwmname ;
    my $module  = $self->_fvwmmodule ;
    $module->addHandler(M_CONFIG_INFO, sub { $self->_handler_config_info(@_) }) ;
    $module->addHandler(M_END_CONFIG_INFO, sub { $self->_handler_config_info_end(@_) }) ;
    $module->send("Send_ConfigInfo") ;
    $module->event_loop ;
    #die "Finishing ...$modname" ;
}

##  After config phase has ended. Create separated w3m instances in tmux, and  
##  attach that session to an instance of urxvt.
sub _setup_w3mtmux {
    my $self = shift ;
    my $module  = $self->_fvwmmodule ;
    my $termname = "w3m - " . $self->name ;
    (my $session = $self->name) =~ tr/a-zA-Z0-9_/_/c ;

    ##  New tmux session.
    $module->send("FF-Message 4 Please wait...") ;
    system("tmux kill-session -t   \"$session\" 1>/dev/null 2>&1") ;
    system("tmux new-session -d -s \"$session\" 1>/dev/null 2>&1") ;

    ##  An w3m instance for each url.
    my $cnt = 1 ;
    foreach my $url ( $self->_list->lines({chomp => 1}) ) {
        system("tmux neww -t $session:$cnt -k \"sleep 2 && w3m -cookie -N +25 $url\" 1>/dev/null 2>&1") ;
        $cnt++ ;
    }

    ##  Add a w3m bookmarks page, then attach tmux session to urxvt.
    system("tmux neww -t $session:999 -k \"sleep 2 && w3m -cookie -N -B\" 1>/dev/null 2>&1") ;
    my $cmd = "urxvt -n \"$termname\" -T \"$termname\" -g " . $self->_geometry ;
    $cmd .= " -fn " . $self->_font . " -fb " . $self->_font . " -b 8 -e sh -c '" ;
    $cmd .= "sleep 2 && tmux selectw -t $session:1 \\; attach -t $session' & " ;
    system($cmd) ;
    #dump $cmd ;

    ##  Setup final_command to kill session when window is closed.
    $cmd  = "Schedule 3000 Next (\"$termname\") SetFinalCommand 1 " ;
    $cmd .= "Exec tmux kill-session -t $session 2>/dev/null" ;
    $module->send($cmd) ;
    exit ;
}

1 ;










