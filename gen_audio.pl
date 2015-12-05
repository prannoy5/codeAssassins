#!/usr/bin/perl

##############################################
## used to generate audio_in.dat file for ECE551 Fall '15 testing
#############################################

$outfile = "audio_in.dat";

open(OUTFILE,">$outfile") || die "ERROR: Can't open $outfile for write\n";

print "Enter frequency of sound (0 - 20000):";
$freq = <STDIN>;
print "Enter amplitude of sound (0 - 32000):";
$amp = <STDIN>;

$t = 0.0;
$tstep = 6.28328/48828.0;

for ($x=0; $x<4096; $x++) {
  $lft_sig = $amp*sin($t*$freq);
  $rht_sig = $amp*cos($t*$freq); 
  
  $lft = sprintf("%4x",$lft_sig);
  if (length($lft)>4) {
    $lft = substr($lft,-4);
  }

  $rht = sprintf("%4x",$rht_sig);
  if (length($rht)>4) {
    $rht = substr($rht,-4);
  }

  printf OUTFILE "\@%x %s\n",$x*2,$lft;
  printf OUTFILE "\@%x %s\n",$x*2+1,$rht;
  $t += $tstep;
}
print "file $outfile has been created\n";
close(OUTFILE);
