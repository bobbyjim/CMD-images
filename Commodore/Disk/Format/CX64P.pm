package Commodore::Disk::Format::CX64P;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Util;
use Commodore::Disk::Model;
use Commodore::Disk::Format::C1541;
use Commodore::Disk::Format::C1571;
use Commodore::Disk::Format::C1581;
use Commodore::Disk::Format::C2040;
use Commodore::Disk::Format::C8050;
use Commodore::Disk::Format::C8250;
use Commodore::Disk::Format::C9030;
use Commodore::Disk::Format::C9060;
use Commodore::Disk::Format::C9090;
use Commodore::Disk::Format::C_ANY;

=head1 NAME

Commodore::Disk::Format::CX64P - Extended support for the X64 image standard. 

=head1 VERSION

Version 1.00

=cut

our $VERSION     = '1.00';
my  $device;
my  $debug       = 0;
my  $maxTracks   = 0;
my  $doubleSided = 0;
my  $errorData   = 0;

=head1 SYNOPSIS

  CX64P

  This module is for accessing device data embedded into the
  X64 image format.  This format has been extended by assigning
  a set of unused data bytes in the signature for defining 
  custom image formats.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new CX64P.

=cut

sub new { bless {}, shift; }

=head2 buildCustomX64data( image ) 

Returns the image data with the custom X64(P) 64-byte signature prepended.

=cut
###############################################################
#
#  buildCustomX64data( image ) - returns the image data with the
#  custom X64(P) 64-byte signature prepended.
#
###############################################################
sub buildCustomX64data
{
   my $image   = shift;
   my $model   = $image->{ 'model' };
   my $dataref = $image->{ 'data'  };
   
   my $dosType = hex $model->DOStype;

   #
   #  DOSType seems to not be working right.
   #
   
   my $version  = 1;
   my $revision = 1;
   my @zones    = $model->zones;

   my $signature = pack( 'C11',
          ord('C'), 0x15, 0x41, 0x40,
	  $version,
	  $revision,
	  0xff,                          # device
	  $maxTracks,
	  $doubleSided,
	  $errorData,
	  $dosType );

   $signature .= pack( 'C5',
	  $model->HDR_DIR_track,
	  $model->HDRlabelOffset,
	  $model->DIRinterleave,
	  $model->FILinterleave,
	  $model->BAMlabelOffset );
  
  
   if ( $model->BAMlocation == 0x5A ) # i.e. 90x0 mode
   {
      $signature .= packZone( $zones[0]->{ 'highTrack' }, $zones[0]->{ 'sectorsPerTrack' } )
	              . packZone( $zones[1]->{ 'highTrack' }, $zones[1]->{ 'sectorsPerTrack' } )
				  . packZone( $zones[2]->{ 'highTrack' }, $zones[2]->{ 'sectorsPerTrack' } )
				  . packZone( $zones[3]->{ 'highTrack' }, $zones[3]->{ 'sectorsPerTrack' } )
				  ;
   }
   else
   {
     $signature .= pack( 'C8', 
		$zones[0]->{ 'highTrack' } & 0xff, $zones[0]->{ 'sectorsPerTrack' } & 0xff,
		$zones[1]->{ 'highTrack' } & 0xff, $zones[1]->{ 'sectorsPerTrack' } & 0xff,
		$zones[2]->{ 'highTrack' } & 0xff, $zones[2]->{ 'sectorsPerTrack' } & 0xff,
		$zones[3]->{ 'highTrack' } & 0xff, $zones[3]->{ 'sectorsPerTrack' } & 0xff );
   }
   
	$signature .= pack( 'CCCCxxxC',
	  $model->BAMinterleave,
	  $model->BAMlocation,
	  $model->BAMsectors,
	  $model->tracksPerBAMsector,
	  0x00,
	  0x00,
	  0x00,
	  $model->BootTrack );
   
   $signature .= pack( 'x32' );

   $signature .= $$dataref;
   
   #
   #  There.  That should do it for the X64.
   #
   return \$signature;
}

#
#  Pack Nontypical Zone T/S into two 8-bit values.
#
#  DETAILS: Nontypical values steal the top 2 bits from the Sector Count
#  and add them to the Track Index.  Thus a nontypical disk can reference
#  up to Track 1023, and can't have more than 63 sectors per track.
#
sub packZone
{
   my ($highTrack, $sectorsPerTrack) = @_;   
   my $spareTrackBits = ($highTrack >> 8) << 6;
   return pack( 'C2', $highTrack & 0xff, $sectorsPerTrack + $spareTrackBits );
}

###############################################################
#
#  extractData( image, bytes ) - gets true image data from
#  an X64 file.
#
###############################################################
sub extractData
{
   my $self = shift;
   my $image = shift;
   my $dataref = shift; 
   
   # Set the true image data
   $dataref = substr( $$dataref, 64 );
   
   return \$dataref;
}

=head2 extractDevice( image, bytes ) 

Gets true device from an X64 file.

=cut
###############################################################
#
#  extractDevice( image, bytes ) - gets true device from
#  an X64 file.
#
###############################################################
sub extractDevice
{
   my $self = shift;
   my $image = shift;
   my $dataref = shift; 
   
   # Bytes:$00-03: This is the "Magic header" ($43 $15 $41 $64)
   #          04: Header version major ($01)
   #          05: Header version minor ($01, now its up to $02)
   #          06: Device type:
   #          07: Maximum tracks in image 
   #          08: Number of disk sides in image.
   #          09: Error data present.
   my $sig  = substr( $$dataref, 0, 32 );
   my ($h0,$h1,$h2,$h3,$ver,$rev,$dev,$trk,$sides,$err)
   = unpack( 'CCCCCCCCCC', $sig );
   
   if ( $debug )
   {
      my $hdr = Commodore::Util::hexdump( $sig );
	  $debug && Commodore::Util::log( 'Commodore::Disk::Image::CX64P::extractDevice', "Header:\n" . $hdr );  
   }

   $maxTracks   = $trk;
   $doubleSided = $sides;
   $errorData   = $err;
   
   # Set the true model.
   $device = Commodore::Disk::Model::get1540() if $dev == 0x00;
   $device = Commodore::Disk::Model::get1541() if $dev == 0x01;
   $device = Commodore::Disk::Model::get1542() if $dev == 0x02;
   $device = Commodore::Disk::Model::get1551() if $dev == 0x03;
   $device = Commodore::Disk::Model::get1570() if $dev == 0x04;
   $device = Commodore::Disk::Model::get1571() if $dev == 0x05;
   $device = Commodore::Disk::Model::get1572() if $dev == 0x06;
   $device = Commodore::Disk::Model::get1581() if $dev == 0x08;
   $device = Commodore::Disk::Model::get2031() if $dev == 0x10; # and 4031
   $device = Commodore::Disk::Model::get2040() if $dev == 0x11; # and 3040
   $device = Commodore::Disk::Model::get2041() if $dev == 0x12; 
   $device = Commodore::Disk::Model::get4040() if $dev == 0x18;
   $device = Commodore::Disk::Model::get8050() if $dev == 0x20;
   $device = Commodore::Disk::Model::get8060() if $dev == 0x21;
   $device = Commodore::Disk::Model::get8061() if $dev == 0x22;
   $device = Commodore::Disk::Model::getSFD()  if $dev == 0x30;
   $device = Commodore::Disk::Model::get8250() if $dev == 0x31;
   $device = Commodore::Disk::Model::get8280() if $dev == 0x32;
   $device = Commodore::Disk::Model::get9030() if $dev == 0x40; # new
   $device = Commodore::Disk::Model::get9060() if $dev == 0x41; # new
   $device = Commodore::Disk::Model::get9090() if $dev == 0x42; # new
   
   if ( $dev == 0xff || !defined $device )
   {
      $device = new Commodore::Disk::Format::C_ANY;
	  $device->init( $doubleSided, 'X64', unpack( 'C22', substr( $sig, 0x0a ) ) );
   }

   $debug && Commodore::Util::log( 'Commodore::Disk::Format::CX64P::extractDevice', "Device $dev (" . ref($device) . ')' );
   $debug && Commodore::Util::log( 'Commodore::Disk::Format::CX64P::extractDevice', "Format is " . $device->format() );
   
   # OK, the true model is ready for use.
   return $device;
}

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Format::CX64P


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

1; # End of Commodore::Disk::Format::CX64P
