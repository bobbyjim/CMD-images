#!/usr/bin/perl

# Purpose: Print a summary of a mounted image.

use Commodore::Disk::Mount;
use Commodore::Disk::Access;

my $device = shift || 8;

my $image = Commodore::Disk::Mount::mount( "$device" );
my $msg = '';

if ( defined $image )
{
    $msg = Commodore::Disk::Access::summary( $image );
}
else
{
    $msg = "Image not mounted on device\n";
}

print $msg;

