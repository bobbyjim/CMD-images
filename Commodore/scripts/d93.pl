#!/usr/bin/perl -w

##################################################
#
# Purpose: Create a D93
#
##################################################

use Commodore::Disk::Access;
use strict;

my ($ext) = $0 =~ /([a-z]\d\d)\.pl$/i;

print "Extension=$ext\n";

my $filename = shift or synopsis($ext);
my $label    = shift or synopsis($ext);
my $id       = shift or synopsis($ext);

my $image = Commodore::Disk::Access::create( "$filename.$ext", uc $label, uc $id );
Commodore::Disk::Access::save( $image );

sub synopsis
{
   my $ext = shift;
   print "Creates a ", uc($ext), " file\n";
   die "SYNOPSIS: $0 filename label id\n";
}
