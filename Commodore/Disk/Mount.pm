package Commodore::Disk::Mount;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Access;

use YAML::Tiny qw/LoadFile DumpFile Dump/;

=head1 NAME

Commodore::Disk::Mount - Disk image "mounting" to a "device".

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my $debug    = 0;


=head1 SYNOPSIS

This module provides convenience functions for handling Commodore disk images,
by associating an image file with a "device".  This is a kind of aliasing method,
by which images can be indirectly referred to through an intermediate file.

=cut

=head1 SUBROUTINES/METHODS

=head2 mount( $basename [, ...] ) 

Convenience method. Loads a simple YAML file named "$basename.yml" 
and looks for a value for the key 'File Name'.  If the value is there, the image
is loaded from that file name.

Several basenames may be specified; if this is the case, the first file to have an image name in it is used.

If no name is specified, it first looks for a file named device-8.yml, then device-9.yml,
then device-10.yml, then device-11.yml, before failing.

=cut
#################################################################
#
#  mount( device... ) - loads image mounted to device
#
#################################################################
sub mount
{  
   my @device = @_;
   @device = (8..11) unless @device;
   
   foreach my $device (@device)
   {
      my $yaml = LoadFile( "device-$device.yml" ); # || die "No image mounted to device $device.\n";
      my $imageName = $yaml->{ 'File Name' };
	  
	  if ( -e $imageName )
	  {
	     my $image = Commodore::Disk::Access::load( $imageName ) or die "ERROR loading $imageName\n";
		 return $image;
	  }
   }
   #carp "No image found.\n";
   return undef; # not found
}

=head2 mountImageOnDevice( image, deviceName )

Convenience method.  Associates an image's filename with a "device", which is simply
a simple YAML file containing a reference to the image's filename.

NOTE: image must have an associated filename for this method to work.

=cut
#################################################################
#
#  mountImageOnDevice( image, device ) - associates an image with a 'device'
#
#################################################################
sub mountImageOnDevice
{
   my $image      = shift || return -1;
   my $device     = shift || 8;
   my $filename   = $image->{ 'filename' } || return -1;
   my $model      = $image->{ 'model' };

   my @zone       = $model->zones;
   my $z          = '';

   foreach my $zone (@zone)
   {
      $z .= sprintf( "[%d,%d] ", $zone->{ 'highTrack' }, $zone->{ 'sectorsPerTrack' } );
   }
   
   my $yaml =
   {
      'File Name' => $filename,
      'DID Label' => $image->{ 'hdr' }->{ 'diskLabelASCII' } . ', ' . $image->{ 'hdr' }->{ 'diskId' },
      'Disk Type' => $model->format,
      'DOS Label' => $model->DOStype,
      'Hdr Track' => $model->HDR_DIR_track,
      'Zone Data' => $z
   };

   DumpFile( "device-$device.yml", $yaml );
   
   return Dump $yaml;
}

=head2 unmount( device )

"Unmounts" image from the specified device.
What this REALLY does is simply delete the device metafile.

=cut
#################################################################
#
#  unmount( device ) - deletes the device metafile.
#
#################################################################
sub unmount
{
   my $device = shift;
   unlink "device-$device";
}

1;

