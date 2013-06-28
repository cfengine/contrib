#!/usr/bin/perl 
#
# The purpose of this script is to detect cfengine klients 
# that has gone AWOL (Absent WithOut Leave).
# 
# It parses lastseen.xml file(s) from cfengine servers and
# and reports an aggregated report on when any of the servers
# last saw a particular client. The report is sorted descending on
# number of minutes since the host were last seen. 
# Each entry contains the «seeing» host. The name of 
# the «seeing» host is taken from the filename where that observation
# came from, hence it is a good idea to name the input file(s)
# equal to the server name it was taken from. 
# Only the most recent observation across all servers (files)
# is reported.
#
# $Id: lastseen_report_xml.pl 1063 2013-06-28 08:59:14Z jb $

use warnings;
use strict;
use XML::Simple;
use Data::Dumper;
use Date::Parse;
use Getopt::Long;

my $csv;
GetOptions("csv"  => \$csv,);

unless ( $ARGV[0] ) {
  usage();
}

my $aliases;
my $hours;
my %d;
my %hostaliases;
my %times;

foreach my $cfserverhost (@ARGV) {
  my $xml = readfile($cfserverhost);
#  Fix broken lastseen XML-report
  $xml =~ s/<alias>\n(.+?)\n<\/ip>/<alias>\n$1\n<\/alias>/sg;
  $xml =~ s/\n//sg;
  $d{$cfserverhost} = XMLin($xml);
}

# $cfserver = filenames of arguments
foreach my $cfserver (keys %d ) {
  foreach my $entry (@{$d{$cfserver}->{'entry'}}) {
    my $ago = $entry->{'q'};
    my $time = str2time($entry->{'date'});
    my $alias = $entry->{'alias'};
    my $host = $entry->{'hostname'};
# Lookup table for md5hash to alias.
    $hostaliases{$host} = $alias;
# Push each observing host and observed klient onto each timestamp
    push(@{$times{$time}},"$cfserver:$host");
  }
}

print_csv_report() if $csv;;
print_text_report() if ! $csv;

sub print_csv_report {
  my %seen;
  my $separator = ',';
  print "Host key".$separator."Seen by".$separator."Ago(min)".$separator."Alias')\n";
  my $now = time();
  foreach my $tm ( sort {$b cmp $a} keys %times ) {
    foreach my $h (@{$times{$tm}}) {
      my ($cfserver,$host) = split(":",$h);
      unless ( $seen{$host} ) {
	my $ago = ($now - $tm) / 60;
	print ($host,$separator,$cfserver,$separator,$ago,$separator,$hostaliases{$host});
        print "\n";
	$seen{$host} = 1;
      }
    }
  }
}

sub print_text_report {
  my $width = 154;
  my $linesym = '-';
  my %seen;
  printline($linesym,$width);
  print sprintf('| %-40s | %-15s | %8s | %-80s | ','Host key','Seen by','Ago(min)','Alias')."\n";
  printline($linesym,$width);
  my $now = time();
  foreach my $tm ( sort {$b cmp $a} keys %times ) {
    foreach my $h (@{$times{$tm}}) {
      my ($cfserver,$host) = split(":",$h);
      unless ( $seen{$host} ) {
	my $ago = ($now - $tm) / 60;
	print sprintf('| %-40s | ',$host);
	print sprintf('%-15s | %8.2f | %-80s |',$cfserver,$ago,$hostaliases{$host})."\n";
	$seen{$host} = 1;
      }
    }
  }
  printline($linesym,$width);
}



sub usage {
  print "Usage: $0 server_lastseen_report1 [server_lastseen_report2] ...\n";
  exit 1;
}

sub readfile {
  my $f_name = shift;
  local $/=undef;
  open FILE, $f_name or die "Couldn't open file $f_name: $!";
  my $ret = <FILE>;
  close FILE;
  return $ret;
} 

sub printline {
  my $sym = shift;
  my $width = shift;
  my $c;
  if ( ! $sym ) { $sym = "-"; } 
  for ($c = 1 ; $c <= $width ; $c++) {
    print "$sym";
  }
  print "\n";
}

