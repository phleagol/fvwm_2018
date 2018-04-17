#!/usr/bin/perl

#  c && ./sxivget.pl --timeout=8 --folder="$FVWM_SXIVGET"

##  Env variable $FVWM_SXIVGET is expected. Destination folder for images.

##  https://scrot.moe/image/6lY18
##  https://cdn.scrot.moe/images/2017/12/24/Screenshot_2017-12-24_22-23-27.md.png
##  https://cdn.scrot.moe/images/2017/12/24/Screenshot_2017-12-24_22-23-27.png

##  Folder
##  Logfile
##  Timeout
##  Font
##  Geometry

use v5.26 ;
use utf8 ;
use strictures ;
use warnings ;

use URI::URL ;
use HTML::LinkExtor ;
use LWP::UserAgent ;
use Getopt::Long ;
use IPC::Run   qw( run timeout ) ;
use Path::Tiny qw( tempfile path ) ;
use List::MoreUtils qw( any none uniq ) ;
use Term::ExtendedColor qw(:all) ;
use Data::Dump qw( dump ) ;

# my $folder = $ENV{FVWM_SXIVGET} // die 'sxivget : $FVWM_SXIVGET not found : ' . $! ;

#dump @ARGV ;

my ($folder, $timeout) ;
GetOptions(
    'folder=s'  => \$folder,
    'timeout=i' => \$timeout, 
) or die("Error in command line arguments\n") ;

#say STDERR "folder: $folder" ;
$timeout = 30 unless defined $timeout ; 
die "folder not found $!" unless -d $folder ;

##  These patterns whitelist images that may be scraped from an html.
my @patterns = map { qr{$_} } (
    '^https?://i.imgur[.]com/.*(png|jpg|jpeg|gif)$', 
    '^https?://cdn[.]scrot[.]moe/images/.*[^.]..[.](png|jpg|jpeg|gif)$', 
    '^https?://image[.]ibb[.]co/\w+/.*[.](png|jpg|jpeg|gif)$', 
) ;

# https://image.ibb.co/hUidzw/2017_12_28_184112_1366x768_scrot.png

my @img_urls  = () ;
my @img_files = () ;
my $cmd = "" ;
my $ua = LWP::UserAgent->new(
    timeout => $timeout,
    agent   => 'Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0',
) ;
my $p  = HTML::LinkExtor->new(\&callback) ;

my $url = xsel_read() ;
die "$0 : valid url not found" unless defined $url and $url =~ m{^http[s]?://} ;

####  GET IMAGE URLS

my $head = $ua->head($url) ;
if ($head->content_type =~ m{text/html})  {
    say fg('green6', "*"), " Get: ", $url ;
    my $res = $ua->request( HTTP::Request->new(GET => $url), sub {$p->parse($_[0])} );
    die "sxivget : LWP FAILED : $url : $!" unless $res->is_success ;
    my $base = $res->base ;
    @img_urls = map { $_ = url($_, $base)->abs->as_string ; } @img_urls ;

    dump @img_urls ;
    say STDERR "---------------" ;

    my @links = () ;
    my %foo = () ; 
    foreach my $link ( uniq(@img_urls) ) {
        next unless any { $link =~ $_ } @patterns ;
        next if $foo{$link}++ ;
        push @links, $link ;
        #$foo{$link}++ if any { $link =~ $_ } @patterns } ;
    }
#    dump %foo ;

    @img_urls = @links ;
    #@img_urls = keys %foo ;
    $cmd = "nohup sxiv -a -sf -f " ;
    say fg('green6', "*"), " Sxiv: fullscreen mode" ;

} elsif ($head->content_type =~ m{image/}) {
    say fg('green6', "*"), " Get: ", $url ;
    @img_urls = ( $url ) ;
    $cmd = "nohup sxiv -b -sf -a " ;
    say fg('green6', "*"), " Sxiv: normal mode" ;
}

say STDERR "No urls found" unless @img_urls ;
exit unless @img_urls ;

####  GET IMAGE FILES

my $cnt = 0 ;
my $total = scalar @img_urls ;
foreach my $url (@img_urls) {
    say fg('green6', "* "), ++$cnt. "/$total ", $url ;
    my $tmp = tempfile( DIR => $folder ) ;
    my $res = $ua->get( $url, ":content_file" => $tmp->stringify ) ;
    next unless $res->is_success ;
    (my $type = $res->content_type) =~ s{^image/}{} ;
    my $file = $tmp->copy($tmp . ".$type") ;
    push @img_files, $file->stringify ;
    #say STDERR "$type\t$file\t$url" ;
}

$cmd .= join(" ", @img_files) . " 2>/dev/null 1>&2  & " ;
#say fg('green6', "* "), $cmd ;
say fg('green6', "* "), "Done..." ;
exit unless @img_files ;
system($cmd) ;
sleep 3 ;

exit ;


####  SUBS

# Set up a callback that collect image links
sub callback {
   my($tag, %attr) = @_ ;
   # say STDERR "=== $tag ===" ;
   # dump \%attr ;
   return if $tag !~ /img|link/ ;  
   push(@img_urls, values %attr);
}

##  Get latest entry from clipboard.
sub xsel_read  {
    my ($in, $out, $err) = ("", 0, 1) ;
    my $retval = eval {
        my @cmd1 = ("xsel", "-ob") ;
        run \@cmd1, \$in, \$out, \$err, timeout(2) ;
        1 ;
    } ;
    if (not $retval) {
        my $t = localtime ;
        say STDERR "[sxivget]: " . $t->hms . " _xsel_md5 : " . $@ ;
        return ;
    } elsif ($err)  {
        return ;
    } else {
        chomp $out ; 
        $out =~ s/\s.+$// ;
        return $err ? undef : $out ;
    }
}





















