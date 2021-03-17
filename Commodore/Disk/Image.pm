package Commodore::Disk::Image;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Util;
use Commodore::Disk::DIR;
use Commodore::Disk::HDR;
use Commodore::Disk::BAM;
use Commodore::Disk::Model;
use Commodore::Disk::Format::C_ANY;

=head1 NAME

Commodore::Disk::Image - Essential access methods for Commodore disk images.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my  $debug   = 1;

=head1 SYNOPSIS

General methods for 
    allocating sectors,
    reading data from sectors,
    writing data to sectors,
    managing the HDR,
    managing the BAM,
    managing the DIR.

=head1 SUBROUTINES/METHODS

=head2 getModel( filename )

Creates the appropriate model to represent the given file.

=cut
#################################################################
#
#  getModel( filename ) 
#
#  Creates the appropriate model to represent the given file.
#
#################################################################
sub getModel { return new Commodore::Disk::Model( @_ ) }

=head2 createImage( filename, label, ID )

Creates a new disk image, using the filename's extension to 
determine the image model.

=cut
#################################################################
#
#  createImage( filename, label, ID ) - Creates a new image.
#
#################################################################
sub createImage
{
   my $filename = shift;
   my $label    = shift;
   my $id       = shift;

   $debug && Commodore::Util::log( "Image::createImage", "argv=($filename $label $id)" );
   my $model    = getModel( $filename );
   my $dosType  = $model->DOStype;

   #
   #  Initialize image
   #
   my $block    = pack( 'x256' );
   my $data     = $block x $model->sectorCount; # nulls

   my $image = 
   {
      'filename'  => $filename,
      'model'     => $model,
	  'data'      => \$data,
	  'dir'       => []
   };
   
   Commodore::Disk::BAM::initialize( $image );   
   Commodore::Disk::HDR::setHeaderLabel( $image, $label, $id, $dosType );
   
   return $image;
}

=head2 createCustomImage

Creates and initializes a custom disk image.  The image is stored in an
X64 file, with 32 bytes of parametric data to instruct the parser on 
specific details about the image's layout.

The parameters to this method are as follows.  Please refer to the various
formats, such as C1541.pm, for details on the meaning of these parameters.

    filename, 
	label, 
	ID,
    dos Type,
    hdr Track,
    hdr Label Offset,
    dir Interleave,
    file Interleave,
    BAM label offset,
    zone1highTrack, zone1sectorsPerTrack,
    zone2highTrack, zone2sectorsPerTrack,
    zone3highTrack, zone3sectorsPerTrack,
    zone4highTrack, zone4sectorsPerTrack,
    BAM Interleave,
    BAM (re)location,
    BAM sector count,
    tracks per BAM sector,
    Boot Track 

=cut
#################################################################
#
#  createCustomImage( filename, label, ID,
#                     dos Type,
#                     hdr Track,
#                     hdr Label Offset,
#                     dir Interleave,
#                     file Interleave,
#                     BAM label offset,
#                     zone1highTrack, zone1sectorsPerTrack,
#                     zone2highTrack, zone2sectorsPerTrack,
#                     zone3highTrack, zone3sectorsPerTrack,
#                     zone4highTrack, zone4sectorsPerTrack,
#                     BAM Interleave,
#                     BAM (re)location,
#                     BAM sector count,
#                     tracks per BAM sector,
#                     Boot Track )
#
#################################################################
sub createCustomImage
{
   my ( $filename, $label, $id, $dosType,
                     @rest ) = @_;
=pod
                     $hdrTrack,
                     $hdrLabelOffset,
                     $dirInterleave,
                     $fileInterleave,
                     $BAMlabelOffset,
                     $zone1highTrack, $zone1sectorsPerTrack,
                     $zone2highTrack, $zone2sectorsPerTrack,
                     $zone3highTrack, $zone3sectorsPerTrack,
                     $zone4highTrack, $zone4sectorsPerTrack,
                     $BAMinterleave,
                     $BAMlocation,
                     $BAMsectorCount,
                     $tracksPerBAMsector,
                     $BootTrack ) = @_;
=cut

   $filename =~ s/\.\w\w\w$//;
   $filename .= ".X64";
   $debug && print "Commodore::Disk::Image::createCustomImage - filename = $filename\n";
   
   my $device = new Commodore::Disk::Format::C_ANY;
   my $doubleSided = 0; # ??
   splice( @rest, 17, 0, (0,0,0) ); # add junk to @rest to satisfy $device->init()
   $device->init( $doubleSided, 'X64', $dosType, @rest );
   my $model  = new Commodore::Disk::Model( $filename, $device ); # X64
   #$model->setDevice( $device );
   
   #
   #  Initialize image
   #
   my $block    = pack( 'x256' );
   my $data     = $block x $model->sectorCount; # nulls

   my $image = 
   {
      'filename'  => $filename,
      'model'     => $model,
	  'data'      => \$data,
	  'dir'       => []
   };
   
   Commodore::Disk::BAM::initialize( $image );
   Commodore::Disk::HDR::setHeaderLabel( $image, $label, $id, $dosType );
   
   return $image;
}

=head2 loadImage( filename )

Parses the contents of a binary file and returns the resulting image.

=cut
#################################################################
#
#  Parses the contents of a binary file.
#
#################################################################
sub loadImage
{
   my $filename = shift;
   
   my $model = getModel( $filename );
   my $image = 
   {
      'model' => $model
   };

   my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size) = stat $filename;
   my $buffer;
   open IN, $filename or die "Couldn't open $filename : $!\n";
   binmode IN;   
   my $rv = read(IN, $buffer, $size)  or die "Couldn't read $filename : $!\n";
   close IN;
   
   $image->{ 'filename' } = $filename;
   # 
   #  Set the data using the Model.
   #
   $image->{ 'data' } = $model->init( $image, \$buffer );
   
   $debug && Commodore::Util::log( "Commodore::Disk::Image::loadImage", "Data length = " . length($buffer) );
   $debug && Commodore::Util::log( "Commodore::Disk::Image::loadImage", "Reading HDR" );
   $image->{ 'hdr' } = Commodore::Disk::HDR::HDR( $image );
   $debug && Commodore::Util::log( "Commodore::Disk::Image::loadImage", "Reading BAM" );
   $image->{ 'bam' } = Commodore::Disk::BAM::BAM( $image );
   $debug && Commodore::Util::log( "Commodore::Disk::Image::loadImage", "Reading DIR" );
   $image->{ 'dir' } = Commodore::Disk::DIR::DIR( $image );
   
   return $image;
}

=head2 sync( image )

Synchronizes changes to the header, directory, and BAM from the image
data to the underlying byte data.

=cut
sub sync
{
   my $image = shift;
   my $model = $image->{ 'model' };

   if ( $model->BAMlocation == 0x47 )
   {
      Commodore::Util::warn( "WILL NOT SAVE 1571 BAM CORRECTLY" );
   }

   Commodore::Disk::HDR::sync( $image ); 
   Commodore::Disk::DIR::sync( $image );
   Commodore::Disk::BAM::sync( $image ); # sync this one last.
}

=head2 saveImage( image [, filename] )

Saves an image to file.

=cut
#################################################################
#
#  saveImage( image [, filename] ) - Saves an image to a file
#
#################################################################
sub saveImage
{
   my $image    = shift;
   my $filename = shift || $image->{ 'filename' };
   
   sync($image);
   
   #
   #  AFTER sync'ing the data to the image, then we can
   #  build our byte image.
   #
   my $model = $image->{ 'model' };
   my $data = $model->buildByteImage( $image );
   
   #
   #  Save to file.
   #
   open OUT, ">$filename";
   binmode OUT;
   print OUT $$data;
   close OUT;
}

=head2 writeBytes( image, offset, byteref )

Writes bytes into the image data at the given offset.

=cut
#################################################################
#
#  writeBytes( image, offset, byteref ) - writes bytes into
#  the image data at the given offset.
#
#################################################################
sub writeBytes
{
   my $image      = shift;
   my $offset     = shift;
   my $byteref    = shift;
   my $bytestring = $$byteref;
   
   my $buffer     = $image->{ 'data' };
     
   my $data = substr( $$buffer, 0, $offset )
            . $bytestring
		    . substr( $$buffer, $offset + length($bytestring) );
      
   $image->{ 'data' } = \$data;
   
   return $image->{ 'data' };
}

=head2 readBlock( image, track, sector )

Returns a single blockref at the given location.

=cut
#################################################################
#
#  Returns a single blockref at the given location.
#
#################################################################
sub readBlock
{
   my $image        = shift;
   my $track        = shift;
   my $sector       = shift;
   my $model        = $image->{ 'model' };
   my $dataref      = $image->{ 'data' };

   my $offset = 0x100 * $model->getSectorOffset( $track, $sector );
 
   $debug && Commodore::Util::log( "Commodore::Disk::Image::readBlock", sprintf( "%3d,%-3d \$%x", $track,$sector, $offset ) );

   my $block = substr( $$dataref, $offset, 256 );

   return \$block;
}

=head2 writeBlock( image, blockref, track, sector )

Writes a single block to the given location.

=cut
#################################################################
#
#  Writes a single block to the given location.
#
#################################################################
sub writeBlock
{
   my $image    = shift;
   my $blockref = shift;
   my $track    = shift;
   my $sector   = shift;
   my $model    = $image->{ 'model' };

   my $offset = 0x100 * $model->getSectorOffset( $track, $sector );
 
   writeBytes( $image, $offset, $blockref );
}

=head2 writeTSLink( image, track, sector, nextTrack, nextSector )

Writes the next Track / next Sector link to the given track and sector.

=cut
#################################################################
#
#  A convenience method to write the T/S link of a block.
#
#################################################################
sub writeTSLink
{
   my $image = shift;
   my $track = shift;
   my $sector = shift;
   my $nextTrack = shift || 0;
   my $nextSector = shift || 0;
   
   if ($image->{ 'model' }->BAMlocation == 0x5A ) # && $s > 63) # "steals from zones"
   {
      #
      #  Don't know if this is correct, but...
      #
      $nextTrack  >>= 2; 
      $nextSector &= 0x1f; # 0 to 31

      $nextTrack &= 0xff;
   }

   my $bytes = pack( 'CC', $nextTrack, $nextSector );
   writeBlock( $image, \$bytes, $track, $sector );
}

=head2 buildChain( image, track, sector [, maxBlocks] )

Takes a starting track and sector and returns its chain of T/S links.
If 'maxBlocks' exists and is nonzero, the process will read a maximum 
of that many blocks.

=cut
#################################################################
#
#  Takes a starting track and sector and returns
#  its chain of T/S links.
#
#################################################################
sub buildChain
{
   my $image        = shift;
   my $track        = shift;
   my $sector       = shift;
   my $maxBlocks    = shift || 0;
   my $model        = $image->{ 'model' };
   my $dataref      = $image->{ 'data' };

   my @chain = ();
   my $offset = 0;

   while( $track > 0 )
   {
       # add block to chain
       push @chain, [ $track, $sector ];

       # do we have enough blocks?
       last if $maxBlocks > 0 && @chain == $maxBlocks;
	   
       # calc the position of this sector
       $offset = 0x100 * $model->getSectorOffset( $track, $sector );

#       $debug && Commodore::Util::log( $$, "OFFSET: $offset\n" );

       # load the next T/S link from this sector
       ($track, $sector) = unpack "CC", substr( $$dataref, $offset, 2 );
	   
       #
       # TODO: ADJUST THE T/S LINK IF WE HAVE A 90x0 IMAGE
       #
       ($track, $sector) = adjustLink($image, $track, $sector);
   }

   return \@chain;
}

=head2 adjustLink( image, T, S ) 

The T/S link, when first unpacked from its byte values, needs
adjustment under one condition:

If the image is a 90x0 image, then the top 2 bits of the sector 
are really 2 MSBs for the track number.  This means the track
number is actually a 10 bit number (up to 1023) and the sector
number is actually a 6 bit number (up to 63).  This method takes
that into account when given the two bytes which usually 
represent a track number (one byte) and a sector number (one byte).

=cut
#################################################################
#
#  adjustLink( image, T, S ) - adjusts T,S for 90x0 image.
#
#################################################################
sub adjustLink
{
   my $image = shift;
   my $t = shift;
   my $s = shift;
   
   if ($image->{ 'model' }->BAMlocation == 0x5A ) # && $s > 63) # "steals from zones"
   {
      #
      # This is a 90x0 image, which means the top 2 bits of the sector 
      # actually refer to the track number.  So, let's steal those 2 bits,
      # shift them upwards, and add them to the track number.  Then we
      # truncate the sector number to 6 bits.
      #
      #my $extraTrackNumber = ($s >> 6) << 8;
      #my $newt = $t + $extraTrackNumber;
      #my $news = $s & 0x3f; # 0 to 63

      #
      # Actually, the scheme is different than that.  Let's try to figure it out.
      #
      my $newt = $t >> 2;
      my $news = $s & 0x1f; # 0 to 31

      $debug && Commodore::Util::log( $$, "90x0 T/S DETECTED: [$t,$s]->[$newt,$news]" );

      return ($newt, $news);
   }
   else
   {
      return ($t,$s);
   }
}

=head2 readFileChain( image, track, sector )

Reads a file chain of blocks with T/S links, stopping with the first block encountered
where the track pointer reads zero (and only reading S bytes from that final block).

=cut
#################################################################
#
#  readFileChain( image, track, sector ) - Reads a file chain
#
#################################################################
sub readFileChain
{
   my $image        = shift;
   my $track        = shift;
   my $sector       = shift;
   my $maxBlocks    = shift;
   my $model        = $image->{ 'model' };
   my $dataref      = $image->{ 'data' };

   # follow the directory chain
   my $chainRef = buildChain( $image, $track, $sector, $maxBlocks);

   my @file = ();

   foreach my $obj (@$chainRef)
   {
      my $objTrack  = $obj->[0];
      my $objSector = $obj->[1];
	  
      $debug && Commodore::Util::log( "Commodore::Disk::Image::readFileChain", "$objTrack, $objSector" );

      my $blockref = readBlock( $image, $objTrack, $objSector );

      # if this is the last block, truncate it accordingly
      if ( $objTrack == 0 )
      {
         $$blockref = substr $$blockref, 0, $objSector+1; # i.e. up to 256 bytes.
      }

      push @file, $blockref;
   }
   
   return \@file;
}

=head2 createFileChain( data )

Splits a (binary) string into an arrayref of blocks containing:
      - data bytes up to 254 bytes
      - final block usually has < 254 bytes

=cut
#################################################################
#
#  Splits a (binary) string into blocks containing:
#      - data bytes up to 254 bytes
#      - final block usually has < 254 bytes
#
#################################################################
sub createFileChain
{
   my $in    = shift;
   my $count = length($in)/254;
   
   $count++ if length($in) % 254 > 0;

   my @out = ();
   
   for (1..$count)
   {
      my $bytes = 254;
	  $bytes = length($in) if length($in) < 254;
	  
      my $data	.= substr( $in, 0, $bytes );              # data bytes
      push @out, $data;
	  
	  $in = substr( $in, $bytes);
   }

   return \@out;
}



=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Image


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

1; # End of Commodore::Disk::Image
