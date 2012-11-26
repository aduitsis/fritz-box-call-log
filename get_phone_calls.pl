#!/usr/bin/env perl 

# this script was written by Walter Soldierer 
# some minor modifications by Athanasios Douitsis
# see http://blog.soldierer.com/2009/12/06/neues-fritzbox-session-id-login-verfahren-in-perl/

use v5.14;

use Data::Printer;
use Data::Dumper;
use warnings;
use strict;
use LWP;
use Encode qw(encode);
use Digest::MD5 qw(md5_hex);
use XML::LibXML;
use Term::ReadKey;
use Term::ReadLine;
use Getopt::Long;

my $boxpasswort;# challenge string holen

GetOptions('password|p:s' => \$boxpasswort ) ;

if( defined( $boxpasswort ) && ( $boxpasswort eq '' ) ) {
	ReadMode 'noecho';
	my $term = Term::ReadLine->new('password prompt');
	my $prompt = 'please enter your fritz!box password:';
	$boxpasswort = $term->readline($prompt);
	ReadMode 'restore';
}


die 'password missing, please use the -p option' unless defined $boxpasswort;

my $user_agent = LWP::UserAgent->new;
my $http_response = $user_agent->post(
	'http://fritz.box/cgi-bin/webcm',
	{
		getpage => '../html/login_sid.xml',
	}
);

my ( $challengeStr ) = ( $http_response->content =~ /<Challenge>(\w+)<\/Challenge>/i ) 
	or die 'Cannot extract challenge string from HTTP response';

# response zur challenge generieren
# my $ch_Pw = $challengeStr.'-'.$boxpasswort;
# version1 # $ch_Pw =~ s/(.)/$1 . chr(0)/eg;
# version2 # my $ch_pw = join '', map { $_ . chr(0) } ( split '', $challengeStr.'-'.$boxpasswort );

# version 3 :
# We take $challengeStr.'-'.$boxpasswort, then we encode it
# to UTF-16LE (LE stands for Little Endian), then we extract
# the bytes, the we reassemble it into a byte string
my $ch_bytes = pack 'C*', unpack 'U*', encode('UTF-16LE',$challengeStr.'-'.$boxpasswort );

my $md5 = lc md5_hex $ch_bytes;
my $challenge_response = $challengeStr.'-'.$md5;

$http_response = $user_agent->post(
	'http://fritz.box/cgi-bin/webcm', 
	{ 
		getpage => '../html/de/home/foncallsdaten.xml',
		'login:command/response' => $challenge_response, 
	},
);

# XML Daten anzeigen
#say $http_response->content;

my $dom = XML::LibXML->load_xml(
	string => $http_response->content,
);

my $document = XML::LibXML->load_xml( string => $http_response->content )->getDocumentElement; 

#p $document;

my @calls;

for my $call ( $document->findnodes('/Foncalls/Calls') ) {
	#say $call->nodeName;
	$call->getAttribute('id');
	my %attrs;
	for my $subelem ( $call->findnodes('*') ) {
		#say $subelem->nodeName;
		#say $subelem->textContent;
		$attrs{ lc $subelem->nodeName } = $subelem->textContent || undef ;
	}
	push @calls, \%attrs;
	
}

p @calls;

for( @calls ) {
	state $i; say join "\t",keys %{ $_ } unless $i++; 
	say join "\t",values %{ $_ } ;
}
