#!/usr/bin/perl
use Commodore::Disk::Mount;
use Commodore::Disk::Image;
use Commodore::Disk::HDR;
################################################################
#
#  Purpose: Display or change the header.
#
################################################################
my $device = shift || 8;
my $label  = shift;
my $id     = shift;

my $image  = Commodore::Disk::Mount::mount( $device );

if ( $label && $label ne '0' )
{
   Commodore::Disk::HDR::setHeaderLabel( $image, uc $label, uc $id );
   Commodore::Disk::Image::saveImage( $image );
   print $image->{ 'filename' }, ": Header changed.\n";
}
else # just dump header
{
   print $image->{ 'filename' }, " header:\n";
   print "Label: '", $image->{ 'hdr' }->{ 'diskLabelASCII' }, "', ID: '", $image->{ 'hdr' }->{ 'diskId' }, '\', DOS Type: \'', $image->{ 'hdr' }->{ 'dosType' }, "'\n";
}
