#!/usr/bin/perl
use Commodore::Disk::Mount;
use Commodore::Disk::Access;
use Commodore::Disk::BAM;
################################################################
#
#  Purpose: Mark a block and print the resulting BAM.
#
################################################################
my $track  = shift || die "SYNOPSIS: $0 <track> <sector> [mark [device]]\n";
my $sector = shift || 0;
my $mark   = shift || 0;
my $device = shift || 8;

################################################################
#
#  Load the mounted image.
#
################################################################
my $image  = Commodore::Disk::Mount::mount( $device );

################################################################
#
#  Mark the block as indicated, save, and print the BAM.
#
################################################################
Commodore::Disk::BAM::markBlocks( $image, [[$track, $sector]], $mark );
Commodore::Disk::Access::save( $image );
print Commodore::Disk::BAM::dump( $image );