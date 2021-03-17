#!/usr/bin/perl
use strict;
use Commodore::Disk::Image;
use Commodore::Disk::Mount;
use YAML::Tiny qw/Dump DumpFile LoadFile/;
use File::Basename;
use List::Util;
################################################################
#
#  Purpose: Create and mount a new, custom image.
#
################################################################
my $name   = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $label  = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $id     = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $device = shift || 8;

my @param = ();
my @defaults = ( '4C', 1, 4, 1, 1, 
		 32, 
                 17, 21,  
		 24, 20,  
		 30, 18,  
		 40, 17, 
                 0, 0, 0, 40, 0 );

my $trackCount = 0;

foreach ( qw/DOStype HDR_DIR_track HDRlabelOffset DIRinterleave FILinterleave
            BAMlabelOffset
            Zone1HighTrack Zone1SectorsPerTrack 
            Zone2HighTrack Zone2SectorsPerTrack 
            Zone3HighTrack Zone3SectorsPerTrack 
            Zone4HighTrack Zone4SectorsPerTrack 
            BAMinterleave BAMrelocation BAMsectorCount tracksPerBAMsector BootTrack/ )
{
   my $default = shift @defaults;

   $default = $trackCount if /tracksPerBAMsector/;

   print "Enter value for $_ [default=$default]: ";
   my $value = <STDIN>;
   $value =~ s/\n//;
   $value = $default unless $value =~ /\w/;
   print "$value\n";
   push @param, $value;

   $trackCount = List::Util::max( $trackCount, $value) if /HighTrack/;
}

my $image = Commodore::Disk::Image::createCustomImage( $name, uc $label, uc $id, @param );
Commodore::Disk::Image::saveImage( $image, $image->{ 'filename' } );
my $text = Commodore::Disk::Mount::mountImageOnDevice( $image, $device );
print "$text\n";
