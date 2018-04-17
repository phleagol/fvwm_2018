package FVWM::Clip ;
use utf8 ;
use v5.26 ;
use Moo ;
use namespace::clean ;

use FVWM::Module ;
use FVWM::Clip::Entry ;
use Path::Tiny qw( path ) ;
use Data::Dump qw( dump ) ;
use IPC::Run qw( run timeout ) ;
use Data::Serializer::Raw ;
use Time::Piece ;

has [qw(
    Name Module Folder Period Respawn LinkMenuName LinkMenuTitle
    ClipMenuName ClipMenuTitle ClipMenuWidth ClipMenuEntrys
    )] => ( is => 'ro', require => 1 ) ;

has [qw( _folderpath _serializer _session)] => ( is => 'lazy' ) ;

has _queue      => ( is => 'rw', default => sub { [] } ) ;
has _md5last    => ( is => 'rw', default => 0 ) ;
has _lastentry  => ( is => 'rw' ) ;

##  Returns the folder path where the stack is stored.
sub _build__folderpath  {
    my $self = shift ;
    my $path = path( $self->Folder ) ;
    $path->mkpath unless $path->exists ;
    return $path ;
}

##  To save/restore session data after each new clipboard entry.
sub _build__serializer  {
    return Data::Serializer::Raw->new( serializer => 'Sereal' ) ;
}

sub _build__session  {
    my $self = shift ;
    my $path = $self->_folderpath ;
    return $path->child('session.dat') ;
}

sub start {
    my $self = shift ;
    my $module = $self->Module ;
    my $modname = $self->Name ;
    $self->_restore_session ;
    $SIG{ALRM} = sub { $self->_check() ; } ;
    $self->_check() ;
    $module->addHandler(M_STRING, sub { $self->_action(@_) }) ;
    $module->show_message("starting ".$module->name) ;
    $module->event_loop ;
    system("FvwmCommand 'Schedule 3000 CheckRestartFvwmClip'") if $self->Respawn ;
    $module->terminate ;
    die "Finishing $modname..." ;
}

##  Act upon SendToModule cmnd received from fvwm.
sub _action {
    my ($self, $fvwmmodule, $event) = @_ ;
    my ($action, $arg) = $event->_text =~ /\s*(\w+)\s*(.*)/ ;
    #say STDERR "$action : $arg"  if $action eq "clear" or $action eq "reload" ;
    $self->reload($arg) if $action eq "reload" ;
    $self->sendcmd( $self->clipmenu ) if $action eq "clipmenu" ;
    $self->list() if $action eq "list" ;
    $self->_exit() if $action eq "exit" ;
    return 1 ;
}

sub _exit {
    my $self = shift ;
    my $module = $self->Module ;
    my $modname = $self->Name ;
    $module->terminate ;
    die "Exiting $modname..." ;
}

##  SendToModule FvwmClip list
sub list {
    my $self = shift ;
    say STDERR $_->md5 . "\t" . $_->label foreach @{ $self->_queue } ;
}

##  Front load a different entry from the stack.
sub reload {
    my ($self, $index) = @_ ;
    my $entry = $self->_queue->[$index] // return ;
    return unless defined $self->_xsel_load($entry) ;
    $self->add($entry) ;
    return 1 ;
}

##  A clipboard menu for fvwm. Triggered via SendToModule command w/fvwm. 
sub clipmenu {
    my $self    = shift ;
    my @queue   = @{ $self->_queue } ;
    my $modname = $self->Name ;
    my $name    = $self->ClipMenuName ;
    my $title   = $self->ClipMenuTitle ;
    my $label   = $self->_lastentry->label ;
    my $type    = $self->_lastentry->type ;
    my @menu    = () ;
    for (my $idx  = 0 ; $idx <= $#queue ; $idx++)  {
        my $icon  = $queue[$idx]->icon ;
        my $label = $queue[$idx]->label ;
        push @menu, "\'$icon$label\' SendToModule $modname reload $idx" ;
    }

    push @menu, @{ $self->_lastentry->launchers } ;
    push @menu, " '' Nop" ;
    push @menu, "\'\$[infostore.icon_cb_clear]Clear history\' CleanRestartFvwmClip" ;

    substr($_, 0, 0) = "AddToMenu $name " foreach @menu ;
    unshift @menu, "AddToMenu $name \'$title\' Title" ;
    unshift @menu, "DestroyMenu $name" ;

    push @menu, "WindowId root 1 WarpToWindow 50 90p " ;
    push @menu, "Menu $name Root c c " ;
    return @menu ;
}

##  Check the system clipboard for new entrys.
sub _check {
    my $self = shift ;
    my $md5 = $self->_xsel_md5() ;
    #print STDERR '.' ;
    if (defined $md5 and $md5 ne $self->_md5last) {
        my $clippath = $self->_xsel_store($md5) ;
        if ( defined $clippath ) {
            print STDERR '<' ;
            my $entry = FVWM::Clip::Entry->new(
                md5            => $md5,
                linkpath       => $clippath, 
                maxchars       => $self->ClipMenuWidth,
                linkmenu_name  => $self->LinkMenuName, 
                linkmenu_title => $self->LinkMenuTitle, 
            ) ;
            $self->add($entry) ;
        }
    }
    alarm($self->Period) ;
    return 1 ;
}

##  Add another entry to the clipboard stack. 
sub add {
    my ($self, $entry) = @_ ;
    my $md5 = $entry->md5 ;
    my %md5hash = () ;
    my @q = @{ $self->_queue } ;
    unshift @q, $entry ;  
    @q = grep { not $md5hash{$_->md5}++ } @q ;  ##  deduplicate entry queue
    $self->_md5last($md5) ;
    $self->_lastentry($entry) ;
    $self->_queue(\@q) ;
    $self->_truncate_queue ;
    $self->sendcmd(@{ $entry->trigger_cmds }) ;
    $self->sendcmd(@{ $entry->linkmenu }) ;
    #dump $entry->linkmenu ;   ## FIXME
    $self->_save_session ;
}

sub _truncate_queue {
    my $self = shift ;
    splice @{ $self->_queue } , $self->ClipMenuEntrys ;  
}

##  Save the entry queue. Prevents loss of the clipboard data.
sub _save_session {
    my $self = shift ;
    my $serializer = $self->_serializer ;
    my $file = $self->_session->canonpath ;
    my @queue = @{ $self->_queue } ;
    $serializer->store(\@queue, $file) ;
    return ;
}

sub _restore_session {
    my $self = shift ;
    return unless $self->_session->exists ;
    my $serializer = $self->_serializer ;
    my $file = $self->_session->canonpath ;
    $self->_queue($serializer->retrieve($file)) ;
    my $entry = $self->_queue->[0] ;
    $self->_lastentry($entry) ;
    $self->_md5last($entry->md5) ;
    $self->_truncate_queue ;
    return ;
}

##  Get latest entry from clipboard, and return its md5 hash value.
sub _xsel_md5  {
    my $self = shift ;
    my $modname = $self->Name ;
    my ($out, $err) = (0, 1) ;
    my $retval = eval {
        my @cmd1 = ("xsel", "-ob") ;
        my @cmd2 = ( "md5sum" ) ;
        run \@cmd1, '|', \@cmd2, \$out, \$err, timeout(2) ; 
        1 ;
    } ;
    if (not $retval) {
        my $t = localtime ;
        say STDERR "[$modname]: " . $t->hms . " _xsel_md5 : " . $@ ;
        return 0 ;
    } elsif ($err)  {
        return 0 ;
    } else {
        chomp $out ; 
        $out =~ s/\s.+$// ;
        return $err ? undef : $out ;
    }
}

##  Store the latest xsel entry to file, and verify/confirm with md5 hash.
sub _xsel_store  {
    my ($self, $md5) = @_ ;
    my $modname = $self->Name ;
    my $path = $self->_folderpath->child("$md5")  ;
    $path->remove if $path->exists ;
    my $retval = eval {
        my @cmd = ("xsel", "-ob") ;
        run \@cmd, ">>", $path->stringify, timeout(2) ; 
        1 ;
    } ;
    if (not $retval) {
        my $t = localtime ;
        say STDERR "[$modname]: " . $t->hms . " _xsel_store : " . $@ ;
        #say STDERR "Clipboard : _xsel_store :" . $@ ;
        return 0 ;
    } ; 
    return 0 unless $path->exists ;
    return $path if $path->digest("MD5") eq $md5 ; 
    $path->remove ;
    return ;
}

##  Push the clip stored for $md5 to the clipboard.
sub _xsel_load  {
    my $self = shift ;
    my $entry = shift ;
    my $modname = $self->Name ;
    my $md5 = $entry->md5 ;
    my $path = $self->_folderpath->child("$md5")  ;
    return unless $path->exists ;
    my @cmd = ("pkill", "xsel") ;
    eval { run \@cmd, timeout(2) } ;
    @cmd = ("xsel", "-ib") ;
    my $retval = eval {
        @cmd = ("xsel", "-ib") ;
        run \@cmd, "<", $path->stringify, timeout(2) ;  
        1 ;
    } ;
    if (not $retval) {
        my $t = localtime ;
        say STDERR "[$modname]: " . $t->hms . " _xsel_load : " . $@ ;
        #say STDERR "Clipboard : _xsel_load :" . $@ ;
        return 0 ;
    } ; 
    return 1 ;
}

sub sendcmd {
    my $self = shift ;
    my $module = $self->Module ;
    foreach ( @_ ) {
        #$module->show_message($_) ;
        $module->send($_) ;
    }
}

8724 ;


