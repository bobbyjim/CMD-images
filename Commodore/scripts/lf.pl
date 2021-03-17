#!/usr/bin/perl
use Commodore::Disk::Access;
use Commodore::Disk::Mount;
use YAML::Tiny qw/Dump DumpFile LoadFile/;
use File::Basename;
use strict;
################################################################
#
#  Purpose: Show images mounted to all devices.
#
################################################################
for my $device (8,9,10,11)
{
   my $devName  = "device-$device.yml";
   next unless -s $devName;
   my $yaml = LoadFile( $devName );
   printf "%2d:  %3s  %s\n",
      $device, $yaml->{ 'Disk Type' }, $yaml->{ 'File Name' };
}
