#!/usr/bin/env perl

use strict;
use warnings;

my $input_filename = $ARGV[0];
my $start = $ARGV[1];
my $end = $ARGV[2];
my $data_filename = $ARGV[3];
my $output_filename = $ARGV[4];

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# Read data file content
my $data_content;
open(my $fh, '<:encoding(UTF-8)', $data_filename)
    or die "Could not open file '$data_filename' $!";
{
  local $/;
  $data_content = <$fh>;
}
close($fh);

# read input file line by line
my $content;
open($fh, '<:encoding(UTF-8)', $input_filename)
    or die "Could not open file '$input_filename' $!";
{
  my $replacing = 0; 
  while (my $row = <$fh>) {
    if (trim($row) eq $start) {
      $replacing = 1;

      $content .= "$row";
      $content .= "$data_content";
  
    } elsif (trim($row) eq $end) {
      $replacing = 0;

      $content .= "$row";
  
    } elsif ($replacing eq 0) {
      $content .= "$row";
    }
  }
}
close($fh);

# output the content
if ($output_filename) {
  # write to file
  open($fh, '>:encoding(UTF-8)', $output_filename)
      or die "Could not open file '$output_filename' $!";
  {
    print $fh $content; 
  }
  close($fh);

} else {
  # write to stdout
  print "$content";
}
