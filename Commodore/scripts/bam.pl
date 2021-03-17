#!/usr/bin/perl
use Commodore::Disk::Mount;
use Commodore::Disk::BAM;
################################################################
#
#  Purpose: Dump the contents of the BAM
#
################################################################
my $device = shift || 8;
my $image  = Commodore::Disk::Mount::mount( $device );
print Commodore::Disk::BAM::dump( $image );
