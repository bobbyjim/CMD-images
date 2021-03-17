#!/usr/bin/perl
use Commodore::Disk::Mount;
use Commodore::Disk::DIR;
################################################################
#
#  Purpose: Print the directory of the mounted image.
#
################################################################
my $device = shift || 8;
my $track  = shift || 0;
my $sector = shift || 0;

my $image  = Commodore::Disk::Mount::mount( $device );

if ( $track )
{
   my $dirref = Commodore::Disk::DIR::DIR( $image, $track, $sector );
   print Commodore::Disk::DIR::dump( $image, $dirref );
}
else
{
   print Commodore::Disk::DIR::dump( $image );
}
print "\n";
