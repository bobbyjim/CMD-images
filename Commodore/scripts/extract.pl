#!/usr/bin/perl
use Commodore::Disk::Access;
################################################################
#
#  Purpose: Save a file from DIR index of mounted image.
#
################################################################
my $filename = shift || die "SYNOPSIS: $0 <image name> <index>\n";
my $index    = shift || die "SYNOPSIS: $0 <image name> <index>\n";
my $image    = Commodore::Disk::Access::load($filename);
Commodore::Disk::Access::readStoreProgramByIndex( $image, $index );
