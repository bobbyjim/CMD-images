#!/usr/bin/perl

# Purpose: Extract sprites from a file on an image.

use Commodore::Disk::Sprite;

my $name     = shift || die "SYNOPSIS: $0 <image name> <file name>\n";
my $file     = shift || die "SYNOPSIS: $0 <image name> <file name>\n";

my $bytes   = Commodore::Disk::Sprite::readFileBytes( $name, $file );
my $pbm_ref = Commodore::Disk::Sprite::extractSpritesToPBM( $bytes );

if ( defined $pbm_ref )
{
   foreach (@$pbm_ref) # dump PBM text to stdout for visual inspection
   {
      print;
   }
}
else
{
   print STDERR "Error reading file.\n";
}
