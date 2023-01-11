#!/usr/bin/env perl

use strict;
use warnings; 
use Data::Dumper; 

my $json = shift @ARGV; 
open JSON,"<",$json or die "$!"; 

my $H = {}; 
my ($gsm,$srs,$srx,$srr) = ('') x 4;; 

## this is kind of strange parsing: we want to flatten to ALL SRS, ALL SRX, and ALL SRR per GSM. 
## let's do this.. 

while(<JSON>) { 
  chomp; 
  if (m/\"accession\": \"(GSM\d+)\"/) { 
    $gsm = $1;
  } elsif (m/\"accession\": \"(SRS\d+)\"/) { 
    $srs = $1;
    push @{$H->{$gsm}->{'SRS'}},$srs;
  } elsif (m/\"accession\": \"(SRX\d+)\"/) { 
    $srx = $1;
    push @{$H->{$gsm}->{'SRX'}},$srx;
  } elsif (m/\"accession\": \"(SRR\d+)\"/) { 
    $srr = $1;
    push @{$H->{$gsm}->{'SRR'}},$srr;
  }
} 

my @gsm = keys %{$H}; 
@gsm = sort @gsm;

foreach my $gsm (@gsm) { 
  my @srs = @{$H->{$gsm}->{'SRS'}}; 
  @srs = uniq(@srs); 
  @srs = sort @srs; 
  $srs = join ',',@srs;

  my @srx = @{$H->{$gsm}->{'SRX'}}; 
  @srx = uniq(@srx); 
  @srx = sort @srx; 
  $srx = join ',',@srx;

  my @srr = @{$H->{$gsm}->{'SRR'}}; 
  @srr = uniq(@srr); 
  @srr = sort @srr; 
  $srr = join ',',@srr;

  print "$gsm\t$srs\t$srx\t$srr\n"; 
} 


close JSON;
  
sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}
