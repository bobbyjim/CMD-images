package Commodore::Disk::Model;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Util;
###############################################################
#
# SUPPORTED FORMATS
#
###############################################################
use Commodore::Disk::Format::C_ANY; 
use Commodore::Disk::Format::C1541; 
use Commodore::Disk::Format::C1571; 
use Commodore::Disk::Format::C1581; 
use Commodore::Disk::Format::C2040; 
use Commodore::Disk::Format::C8050; 
use Commodore::Disk::Format::C8250; 
use Commodore::Disk::Format::C9030;
use Commodore::Disk::Format::C9060;
use Commodore::Disk::Format::C9090;
use Commodore::Disk::Format::CX64P; 

###############################################################
#
#  Model
#
#  This module is for methods which provide computed values
#  based on the disk image model. These methods are independent
#  of specific images; therefore, these methods only take
#  the model as a parameter, and not the image.
#
###############################################################
=head1 NAME

Commodore::Disk::Model - Computes values from the disk image object.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my $debug    = 0;
my $disk;

=head1 SYNOPSIS

This module is for methods which provide computed values
based on the disk image model. These methods are independent
of specific images; therefore, these methods only take
the model as a parameter, and not the image.

=head1 SUBROUTINES/METHODS

=head2 new( filename, deviceRef )

Creates a new instance of Model, associating itself with the appropriate disk format
based on the filename extension or the supplied device reference.

=cut

sub new
{
   my $class     = shift;
   my $filename  = shift;
   my $device    = shift;
   my $self      = bless {}, $class;
   
   my ($ext) = $filename =~ /\.(\w+)$/;
   $ext = '' unless $ext;
   
   # 1540/1, 1551, 1570, 2031, 4031, 4040/1
   $disk = new Commodore::Disk::Format::C1541 if $filename =~ /\.D(64|70)$/i;
   $disk = new Commodore::Disk::Format::C2040 if $filename =~ /\.D(40|67)$/i;  # 2040, 3040
   $disk = new Commodore::Disk::Format::C1571 if $filename =~ /\.D(71|72)$/i;  # 1571, 1572
   $disk = new Commodore::Disk::Format::C1581 if $filename =~ /\.D(81|65)$/i;  # 1581, 1565 (from the C-65)
   $disk = new Commodore::Disk::Format::C8050 if $filename =~ /\.D80$/i;       # 8050
   $disk = new Commodore::Disk::Format::C8250 if $filename =~ /\.D82$/i;       # 8250, SFD-1001
   $disk = new Commodore::Disk::Format::C9030 if $filename =~ /\.D93$/i;       # 9030
   $disk = new Commodore::Disk::Format::C9060 if $filename =~ /\.D96$/i;       # 9060
   $disk = new Commodore::Disk::Format::C9090 if $filename =~ /\.D99$/i;       # 9090
   $disk = new Commodore::Disk::Format::CX64P if $filename =~ /\.X64$/i;       # X64++

   $disk = $device if $device; # override

   die "ERROR: Cannot identify disk image model: ext=$ext : $!\n"
      unless $disk;

   $debug && Commodore::Util::log( 'Commodore::Disk::Model::new', "disk = " . ref $disk );

   return $self;
}

=head2 device

Returns the device format currently used.

=cut
sub device { $disk }

=head2 setDevice

Sets the device format to use.

=cut
sub setDevice { $disk = shift }

###############################################################
#
#  init( image, byteref ) - use the model to return the device's
#  data bytes.
#
###############################################################
=head2 init( image, byteRef )

Use the Model to return the device's data bytes.  This is useful
for discriminating between an actual image format (D64, D81) and
a "virtual" format (X64).

=cut
sub init
{
   my $self    = shift;
   my $image   = shift;
   my $byteref = shift;
   
   if ( $disk =~ /CX64P/ )
   {
      # Determine the ACTUAL format used and assign the proper
	  # device to the image.

      $debug && Commodore::Util::log( 'Commodore::Disk::Model::init', "Found an X64" );  
      my $dataref = $disk->extractData( $image, $byteref );
      $disk       = $disk->extractDevice( $image, $byteref );
      $byteref    = $dataref;
   }
   
   $debug && Commodore::Util::log( "Commodore::Disk::Model::init", "Device = " . ref $disk );
   $debug && Commodore::Util::log( "Commodore::Disk::Model::init", "Format = " . $disk->format );
   
   return $byteref;
}

###############################################################
#
#  buildByteImage( image ) - gets image data for writing
#
###############################################################
=head2 buildByteImage( image )

Gets image data for writing.

=cut
sub buildByteImage
{
   my $self  = shift;
   my $image = shift;
   
   if ( $disk =~ /C_ANY/ ) # Custom image = build X64 signature line
   {
      return Commodore::Disk::Format::CX64P::buildCustomX64data( $image );
   }
   else
   {
      return $image->{ 'data' };
   }
}

=head2 get1540, get1541, get1542, get1551, get1570, get2031, get4031, get4040

Returns a new 1541-compatible parametric format.

=cut

# 1541 compatible formats
sub get1540 { return new Commodore::Disk::Format::C1541 }
sub get1541 { return new Commodore::Disk::Format::C1541 }
sub get1542 { return new Commodore::Disk::Format::C1541 }
sub get1551 { return new Commodore::Disk::Format::C1541 }
sub get1570 { return new Commodore::Disk::Format::C1541 }
sub get2031 { return new Commodore::Disk::Format::C1541 }
sub get4031 { return new Commodore::Disk::Format::C1541 }
sub get4040 { return new Commodore::Disk::Format::C1541 }

=head2 get1571, get1572

Returns a new 1571-compatible parametric format.

=cut

# 1571 compatible formats
sub get1571 { return new Commodore::Disk::Format::C1571 } 
sub get1572 { return new Commodore::Disk::Format::C1571 }

=head2 get1581

Returns a new 1581-compatible parametric format.

=cut
# 1581 compatible formats
sub get1581 { return new Commodore::Disk::Format::C1581 }

=head2 get2040, get3040, get2041

Returns a new 2040-compatible parametric format.

=cut
# 2040 compatible formats
sub get2040 { return new Commodore::Disk::Format::C2040 }
sub get3040 { return new Commodore::Disk::Format::C2040 }
sub get2041 { return new Commodore::Disk::Format::C2040 }

=head2 get8050, get8060, get8061

Returns a new 8050-compatible parametric format.

=cut
# 8050 compatible formats
sub get8050 { return new Commodore::Disk::Format::C8050 }
sub get8060 { return new Commodore::Disk::Format::C8050 }
sub get8061 { return new Commodore::Disk::Format::C8050 }

=head2 getSFD, get8250, get8280

Returns a new 8250-compatible parametric format.

=cut
# 8250 compatible formats
sub getSFD  { return new Commodore::Disk::Format::C8250 }
sub get8250 { return new Commodore::Disk::Format::C8250 }
sub get8280 { return new Commodore::Disk::Format::C8250 }

=head2 get9030, get9060, get9090

Returns a new 90x0-compatible parametric format.

=cut
sub get9030 { return new Commodore::Disk::Format::C9030 }
sub get9060 { return new Commodore::Disk::Format::C9060 }
sub get9090 { return new Commodore::Disk::Format::C9090 }

=head2 summary

Returns a detailed summary of this image's characteristics.

=cut
sub summary
{
   my $format = "%4s %3s %2s %3d %4d %5d %3d %4d %2d %2d %2d %4d %4d %4d %4d %3d\n";
   my $format2 = "%4s %3s %2s %3s %4s %5d %3d %4d %2d %2d %2d %4d %4d %4d %4d %3d\n";
   return sprintf $format2,
				'FMT', 
				'TYP',
				'DS',
				'BT',
				'Trks',
				'Sec',
				'Hdr',
				'HOff',
				'Dx',
				'Fx',
				'Bx',
				'Bsz',
				'BOff',
				'BLoc',
				'BSec',
				'TPB';
   
	sprintf $format,
			$disk->format,
			$disk->DOStype,
			$disk->doubleSided,
			$disk->bootTrack,
			$disk->trackCount,
			$disk->sectorCount,
			$disk->HDR_DIR_track,
			$disk->HDRlabelOffset,
			$disk->DIRinterleave,
			$disk->FILinterleave,
			$disk->BAMinterleave,
			$disk->BAMsize,
			$disk->BAMlabelOffset,
			$disk->BAMlocation,
			$disk->BAMsectors,
			$disk->tracksPerBAMsector;
			
}


=head1 PASSTHROUGH METHODS

The model "passes through" the methods of the format objects:

=head2 doubleSided

A flag.  A value of '1' indicates the image is double-sided.

=head2 format

The disk image format, typically expressed as a file extension.  
For example, the 1541 format is 'D64'.

=head2 DOStype

A string of two hexadecimal digits representing the DOS format type.
For example, the 1541 DOS type is '2A'.

=head2 HDR_DIR_track

The track on which can be found the disk header and directory.

=head2 HDRlabelOffset

The byte offset for the header label.  By definition the header sector
itself is sector 0 on its given track.

=head2 DIRinterleave

The directory interleave: the number of sectors incremented when writing
a new directory sector.

=head2 FILinterleave

The file interleave: the number of sectors incremented when writing
a new file sector.

=head2 BAMlabelOffset

The byte offset for the actual BAM data.  
For disk images with BAM on separate sectors, this informs the BAM label,
which sits between bytes 2 and the BAMlabelOffset.  If there's enough space,
the BAM sector contains this data at these offsets:

$02: Version # ('D' for D81)
$03: One's complement of version# ($BB for D81)
$04-05: Disk ID bytes (same as 40/0 Disk ID for D81)
$06: I/O byte
- bit 7 set   - Verify on
- bit 7 clear - Verify off
- bit 6 set   - Check header CRC
- bit 6 clear - Don't check header CRC
$07: Auto-boot-loader flag

=head2 zones

Returns an array containing zone information, of the form:

(
   { 'highTrack' => $highTrackForZone1, 'sectorsPerTrack' => $sectorsPerTrackForZone1 },
   { 'highTrack' => $highTrackForZone2, 'sectorsPerTrack' => $sectorsPerTrackForZone2 },
   { 'highTrack' => $highTrackForZone3, 'sectorsPerTrack' => $sectorsPerTrackForZone3 },
   { 'highTrack' => $highTrackForZone4, 'sectorsPerTrack' => $sectorsPerTrackForZone4 }
)

=head2 BAMinterleave

The BAM interleave: the number of sectors incremented when writing
a new BAM sector.

=head2 BAMlocation

This is one of three values:

0x00: the BAM is on the HDR sector (sector 0).
0x01: the BAM follows in the sector(s) subsequent to the HDR sector.
0x02: the BAM starts on sector 0 of the track preceding the HDR.
0x47: treat this BAM like it is a 1571 disk image.

=head2 BootTrack

If non-zero, this indicates a track to boot from.

=head2 BAMsectors

If the BAM is not on sector 0 of the HDR sector, then 
this value indicates the number of BAM sectors.

=head2 tracksPerBAMsector

This value indicates the number of tracks accounted for per BAM sector,
and may be freely ignored for images which have their BAM co-located on the 
HDR sector.

=cut
###############################################################
#
#  Methods on the disk object.
#
###############################################################

sub doubleSided        { $disk->doubleSided               }
sub format             { $disk->format                    }
sub DOStype            { $disk->DOStype                   }
sub HDR_DIR_track      { $disk->HDR_DIR_track             }

sub HDRlabelOffset     { $disk->HDRlabelOffset            }
sub BAMlabelOffset     { $disk->BAMlabelOffset            }
sub DIRinterleave      { $disk->DIRinterleave             }
sub FILinterleave      { $disk->FILinterleave             }

sub zones              { $disk->zones                     }

sub BAMinterleave      { $disk->BAMinterleave             }
sub BAMlocation        { $disk->BAMlocation               }
sub BootTrack          { $disk->BootTrack                 }

###############################################################
#
#  These methods SHOULD be derived, but aren't.
#
###############################################################
sub BAMsectors         { $disk->BAMsectors                }
sub tracksPerBAMsector { $disk->tracksPerBAMsector        }

###############################################################
#
#  Derived Values
#
#  Model methods which derive or calculate offsets from the
#  disk object.
#
###############################################################
###############################################################
#
#  $model->getSectorOffset( track, sector )
#
#  Given a track and sector, calculate the sector's
#  number within the entire image.
#
#  NOTE: the byte offset to a sector is:
#
#      sector offset * 0x100
#
###############################################################
=head1 DERIVED VALUES

The following are Model methods which derive or calculate offsets
based on the disk object.

=head2 getSectorOffset( track, sector )

Given a track and sector, return the sector offset into the image.

=cut
sub getSectorOffset
{
   my $model  = shift; # i.e. self
   my $track  = shift || 1;
   my $sector = shift || 0;
   my @zones  = $model->zones;

   return $sector if $track == 1;

   my $prevTrack = 0;

   for my $zone (@zones)
   {
      my $highTrack = $zone->{ 'highTrack' };
      my $spt       = $zone->{ 'sectorsPerTrack' };

      if ( $highTrack < $track )
      {
         $sector += ($highTrack-$prevTrack) * $spt;
         $prevTrack = $highTrack;
      }
      else
      {
         $sector += ($track-$prevTrack-1) * $spt;
         last;
      }
   }
   return $sector;
}

###############################################################
#
#  $model->trackCount() - returns number of tracks supported by
#  this model.
#
###############################################################
=head2 trackCount()

Return the number of tracks supported by this model.
If the caller asks for an array response, this method will
reply with the track count, AND the sectors per track in the FINAL zone.

=cut
sub trackCount
{
   my $model = shift; # i.e. self
   my @zones = $model->zones;

   my $trackCount = 0;
   my $spt        = 0;

   foreach my $zone (@zones)
   {
      $trackCount = $zone->{ 'highTrack' } if $zone->{ 'highTrack' };
      $spt        = $zone->{ 'sectorsPerTrack' } if $zone->{ 'sectorsPerTrack' };
   }

   $debug && Commodore::Util::log( 'Commodore::Disk::Model::trackCount', " $trackCount,$spt" );

   return wantarray? ($trackCount, $spt) : $trackCount;
}

###############################################################
#
#  $model->sectorCount() - returns number of sectors supported
#  by this model.
#
###############################################################
=head2 sectorCount

Returns the number of sectors supported by this model.

=cut
sub sectorCount
{
   my $model = shift; # i.e. self

   my ($highTrack, $sectorsPerTrack) = $model->trackCount();
   my $sectorOffset = $model->getSectorOffset( $highTrack, $sectorsPerTrack );

   $debug && Commodore::Util::log( 'Commodore::Disk::Model::sectorCount', $sectorOffset );

   return $sectorOffset;
}

###############################################################
#
#  $model->sectorsPerTrack( track )
#
#  Determine how many sectors this track has.
#
###############################################################
=head2 sectorsPerTrack( track )

Returns how many sectors this track has.

=cut
sub sectorsPerTrack
{
   my $model = shift; # i.e. self
   my $track = shift;
   my @zones = $model->zones;

   foreach my $zone (@zones)
   {
      return $zone->{ 'sectorsPerTrack' } if $track <= $zone->{ 'highTrack' };
   }

   return -1; # error
}

###############################################################
#
#  $model->maxSectorsInTrack() - returns the largest number of
#  sectors supported by this model.
#
###############################################################
=head2 maxSectorsInTrack

Returns the largest number of sectors supported by this model.

=cut
sub maxSectorsInTrack
{
   my $model = shift; # i.e. self
   my @zones = $model->zones;

   my $spt = 0;

   foreach my $zone (@zones)
   {
      $spt = $zone->{ 'sectorsPerTrack' } if $spt < $zone->{ 'sectorsPerTrack' };
   }

   #$debug && Commodore::Util::log( "Commodore::Disk::Model::maxSectorsInTrack", $spt );

   return $spt;
}

###############################################################
#
#  $model->HDRsectorOffset() - returns header sector number.
#
###############################################################
=head2 HDRsectorOffset

Returns the header sector number.

=cut
sub HDRsectorOffset
{
   my $model = shift; # i.e. self
   my $offset = $model->getSectorOffset( $model->HDR_DIR_track, 0 );
   $debug && Commodore::Util::log(  "Commodore::Disk::Model::HDRsectorOffset", $offset );
   return $offset;
}

=head2 DIRsectorOffset

Returns the first DIR sector number.

=cut
###############################################################
#
#  $model->BAMsectorOffset() - returns header sector number.
#
###############################################################
sub DIRsectorOffset
{
   my $model  = shift; # i.e. self
   my $sector = 1;
   $sector += $model->BAMsectors if $model->BAMlocation == 0x01;
   
   return $sector;
}

###############################################################
#
#  $model->BAMsectorBytes() - returns the number of sector-data
#  bytes per track in BAM (not including FSC).
#
###############################################################
=head2 BAMsectorBytes

Returns the number of sector-data bytes per track in BAM (not including FSC).

=cut
sub BAMsectorBytes
{
   my $model = shift; # i.e. self
  
   my $BAMsectorBytes = $model->maxSectorsInTrack()/8;
   $BAMsectorBytes = int($BAMsectorBytes+1)
      unless int($BAMsectorBytes) == $BAMsectorBytes;
   #$debug && Commodore::Util::log( "Commodore::Disk::Model::BAMsectorBytes", $BAMsectorBytes );
  
   return $BAMsectorBytes;
}

###############################################################
#
#  $model->BAMsize() - return the total number of bytes 
#  to store entries for all tracks handled by this image.
#
###############################################################
=head2 BAMsize

Returns the total number of bytes needed to store entries for all tracks handled by this image,
including the FSC.

=cut
sub BAMsize
{
   my $model = shift; # i.e. self
  
   my $bytesPerTrack = $model->BAMsectorBytes() + 1;
   my $tracks        = $model->trackCount; 
   my $total         = $tracks * $bytesPerTrack;
  
   $debug && Commodore::Util::log( "Commodore::Disk::Model::BAMsize", "$bytesPerTrack x $tracks = $total" );
   return $total;
}

###############################################################
#
#  $model->BAMposition() - return the first BAM track and sector
#
###############################################################
=head2 BAMposition

Returns the first BAM track and sector.

=cut
sub BAMposition
{
   my $model  = shift; # i.e. self
   my $track  = $model->HDR_DIR_track;

   my $sector = 0;                           # BAM on HDR sector
   $sector++ if $model->BAMlocation == 0x01; # sector(s) on HDR track
   $track--  if $model->BAMlocation == 0x5A; # precedes HDR track
   $track--  if $model->BAMlocation == 0x02; # precedes HDR track

   #$debug && Commodore::Util::log( "Commodore::Disk::Model::BAMposition", "$track,$sector" );
   return ($track, $sector);
}

###############################################################
#
#  $model->BAMsectorOffset() - returns the 1st BAM sector offset.
#
###############################################################
=head2 BAMsectorOffset

Returns the 1st BAM sector offset.

=cut
sub BAMsectorOffset
{
   my $model = shift; # i.e. self
   my ($track, $sector) = $model->BAMposition;
   my $offset = $model->getSectorOffset( $track, $sector );
   $debug && Commodore::Util::log( "Commodore::Disk::Model::BAMsectorOffset", $offset );
   return $offset;
}

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Model


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Commodore-Util>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Commodore-Util>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Commodore-Util>

=item * Search CPAN

L<http://search.cpan.org/dist/Commodore-Util/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Robert Eaglestone.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Commodore::Disk::Model
