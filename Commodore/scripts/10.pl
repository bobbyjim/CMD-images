#!/usr/bin/perl
use Commodore::Disk::Access;
use Commodore::Disk::Mount;
use YAML::Tiny qw/Dump DumpFile LoadFile/;
use File::Basename;
use strict;
################################################################
#
#  Purpose: Mount an image to a device based on the script name.
#
#  For example, if this script were named "8.pl", the
#  device number would be "8".
#
################################################################
my ($device) = basename $0 =~ /^(.*)\.pl/;

my $fileName = shift;
my $devName  = "device-$device.yml";

if ( $fileName eq 'unmount' )
{
   Commodore::Disk::Mount::unmount( $device );
   print "Unmounted device-$device\n";
   exit;
}

unless ( $fileName )
{
   print "No image mounted to device $device.\n" unless -e $devName;
   print Dump LoadFile( $devName ) or die "No image mounted to device $device.\n";
   exit;
}

# else, mount

my $image = Commodore::Disk::Access::load( $fileName );
my $textDump = Commodore::Disk::Mount::mountImageOnDevice( $image, $device );
print $textDump;
