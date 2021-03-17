#!/usr/bin/perl
use Commodore::Disk::Access;
use Commodore::Disk::Mount;
use strict;
################################################################
#
#  Purpose: Create and mount a new image.
#
################################################################
my $name   = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $label  = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $id     = shift || die "SYNOPSIS: $0 <filename> <label> <id> [device]\n";
my $device = shift || 8;
my $image  = Commodore::Disk::Access::create( $name, uc $label, uc $id );

Commodore::Disk::Access::save( $image, $name );
my $yamlText = Commodore::Disk::Mount::mountImageOnDevice( $image, $device );

print "$name created and mounted on device $device:\n";
print $yamlText;
