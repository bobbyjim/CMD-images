package Commodore::Disk::HDR;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Util;
use Commodore::Disk::Image;
use Commodore::Disk::Model;

=head1 NAME

Commodore::Disk::HDR - Commodore disk image header access methods.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my $debug    = 0;


=head1 SYNOPSIS

Provides access to the header data in a Commodore disk image.

For example, a short program which shows or changes the header:

#!/usr/bin/perl
use Commodore::Disk::Access;
use Commodore::Disk::HDR;
################################################################
#
#  Changes (or displays) the header.
#
################################################################
my $filename = shift || die "SYNOPSIS: $0 file [new-label [new-id]]\n";
my $label    = shift; # image label to set
my $id       = shift; # image ID to set
my $image    = Commodore::Disk::Access::load( $filename );

if ( $label && $id && $label ne '0' && $id ne '0' )
{
   Commodore::Disk::HDR::setHeaderLabel( $image, uc $label, uc $id );
   Commodore::Disk::Access::save( $image, $filename } );
   print $image->{ 'filename' }, ": Header changed.\n";
}
else # just dump header
{
   print $image->{ 'filename' }, " header:\n";
   print "Label: '", $image->{ 'hdr' }->{ 'diskLabelASCII' }, "', ID: '", $image->{ 'hdr' }->{ 'diskId' }, '\', DOS Type: \'', $image->{ 'hdr' }->{ 'dosType' }, "'\n";
}

=head1 SUBROUTINES/METHODS

=head2 HDR( image )

  Access HDR data.

  Returns a structure:
  {
     'dosType':     <dos type>    e.g. '2A'
     'diskLabel':   <label>       e.g. 'MYDISKáááááááááá'
     'diskLabelASCII': <label>    e.g. 'MYDISK'
     'diskId':      <ID>          e.g. 'AA'
  }

=cut
#################################################################
#
#  Access HDR data.
#
#  Returns a structure:
#  {
#     'dosType':     <dos type>    e.g. '2A'
#     'diskLabel':   <label>       e.g. 'MYDISKáááááááááá'
#     'diskLabelASCII': <label>    e.g. 'MYDISK'
#     'diskId':      <ID>          e.g. 'AA'
#  }
#
#################################################################
sub HDR
{
   my $image = shift;
   my $model = $image->{ 'model' };
   my $hdrref = Commodore::Disk::Image::readBlock( $image, $model->HDR_DIR_track, 0 );
 
   my $offset = $model->HDRlabelOffset;
   $$hdrref = substr $$hdrref, $offset, 23;
 
   my ($label, $id, $j2, $dosType)
   = unpack( "a18a2ca2", $$hdrref );

   $debug && Commodore::Util::log( "HDR::HDR", "hdr offset[$offset] \"$label\", \"$id\", \"$dosType\"" );
   
   return
   {
       'dosType'   => $dosType,
       'diskLabel' => $label,
	   'diskLabelASCII' => Commodore::Util::a0to32( $label ),
       'diskId'    => $id
   };
}

=head2 hdr( image )

Return the header block bytes (256 binary bytes).

=cut
#################################################################
#
#  hdr( image ) - return the header block bytes
#
#################################################################
sub hdr
{
   my $image = shift;
   my $model = $image->{ 'model' };
   return Commodore::Disk::Image::readBlock( $image, $model->HDR_DIR_track, 0 );
}

=head2 dump( image )

Dumps the header data as a string.

=cut
#################################################################
#
#  dump( $image ) - dumps the header as a string.
#
#################################################################
sub dump
{
   my $image = shift;
   my $model = $image->{ 'model' };
   my $hdr   = HDR( $image );
   my $label = $hdr->{ 'diskLabel' };
   my $ascii = $hdr->{ 'diskLabelASCII' };
   my $did   = $hdr->{ 'diskId' };
   my $dos   = $hdr->{ 'dosType' };

   my @zone  = $model->zones;
   my $z     = '';

   foreach my $zone (@zone)
   {
      $z .= sprintf( "[%d,%d] ", $zone->{ 'highTrack' }, $zone->{ 'sectorsPerTrack' } );
   }

   return sprintf( "Disk Label : %-16s  DOS Label: $dos\n", substr($label,0,16) )
        . sprintf( "ASCII Label: %-16s  Hdr Track: %s\n", $ascii, $model->HDR_DIR_track )
	. "Disk Type  : $did\n"
	. "Zone data  : $z"
	;
}

=head2 setHeaderLabel( image, label, ID, dosType )

Sets the header label data for an image.
NOTE: Saving the image or calling sync() commits changes.

=cut
#################################################################
#
#  setHeaderLabel( image, label, ID, dosType ) - Sets header data.
#
#################################################################
sub setHeaderLabel
{
   my $image   = shift;
   my $label   = shift;
   my $id      = shift;
   my $dosType = shift;

   $image->{ 'hdr' }->{ 'diskId'  } = $id      if $id;
   $image->{ 'hdr' }->{ 'dosType' } = $dosType if $dosType;
   
   if ( defined $label )
   {
	  my $ascii   = Commodore::Util::a0to32( $label );
	  my $petscii = Commodore::Util::toA0( $label, 16 );
	  
	  $image->{ 'hdr' }->{ 'diskLabel' } = $petscii;
	  $image->{ 'hdr' }->{ 'diskLabelASCII' } = $ascii;
   }
}

=head2 sync( image )

Writes header data to the buffer image.

=cut
#################################################################
#
#  sync( image ) - writes header data to the buffer image
#
#################################################################
sub sync
{
   my $image  = shift;
   my $model  = $image->{ 'model' };
   my $hdrSector = $model->HDRsectorOffset;
   my $offset = $hdrSector * 0x100 + $model->HDRlabelOffset;
   my $hdr = pack( 'a16CCa2Ca2', 
		           $image->{ 'hdr' }->{ 'diskLabel' },
                           0xa0, 0xa0,
				   $image->{ 'hdr' }->{ 'diskId' },
                           0xa0,
				   $image->{ 'hdr' }->{ 'dosType' } );
				   
   return Commodore::Disk::Image::writeBytes( $image, $offset, \$hdr );   
}



=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::HDR


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

1; # End of Commodore::Disk::HDR
