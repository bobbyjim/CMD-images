#!/usr/bin/perl

use Commodore::Disk::Mount;
use Commodore::Disk::Access;
################################################################
#
#  Purpose: Sync and save a mounted image to the given filename.
#
################################################################
my $name     = shift || die "SYNOPSIS: $0 <filename> [, device]\n";
my $device   = shift || 8;
my $image    = Commodore::Disk::Mount::mount( $device );
Commodore::Disk::Access::save( $image, $name );
