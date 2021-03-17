#!/usr/bin/perl
use Commodore::Disk::Access;
################################################################
#
#  Purpose: Store a PRG file into the specified image file.
#
################################################################
my $imgFile  = shift || die "SYNOPSIS: $0 <disk image> <file to inject>\n";
my $filename = shift || die "SYNOPSIS: $0 <disk image> <file to inject>\n";
my $image    = Commodore::Disk::Access::load( $imgFile );
Commodore::Disk::Access::writeProgramFromFile( $image, $filename );
Commodore::Disk::Access::save( $image, $imgFile );
