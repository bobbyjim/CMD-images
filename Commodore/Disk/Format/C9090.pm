package Commodore::Disk::Format::C9090;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Commodore::Disk::Format::C9090 - D99 format file for the Commodore disk image reader.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

   ##################################
   #
   #  BAMlocation CONSTANTS
   #
   ##################################

   my $BAM_ON_HDR             = 0x00;
   my $BAM_FOLLOWS_HDR        = 0x01;
   my $BAM_TRACK_BEFORE_HDR   = 0x02;
   my $BAM_SPILLS_OVER        = 0x47; # 0x47 = decimal 71; i.e. "1571 mode"
   my $BAM_STEALS_FROM_ZONES  = 0x5A; # = decimal 90; i.e. "90x0 mode"

=head1 SYNOPSIS

This file contains parametric data needed for correctly reading to and writing from a D99 file.

D99 - Commodore emulator file of a CBM-9060 diskette 

The 9090 was an IEEE-488 hard drive with 7.5MB storage and Commodore DOS 3.0.

Unusual features of the 9060 and 9090 include:
 (1) the track layout, which is numbered from ZERO instead of ONE (the HEADER is on track 0).
 (2) the number of tracks, which exceeds 255, 
 leaving one to assume that two bits from the sector address are 
 used to shift the track number upwards.

Supporting this format requires adaptation of how T/S links are computed.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new instance.

=cut

sub new { bless {}, shift; }

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

   ######################################################
   #
   #  Format Specifics
   #
   #  In order to parse a Commodore disk image properly,
   #  you will need to know these things.
   #
   ######################################################
   sub doubleSided     { 0 }           # accounted for in X64 spec

   sub format          { 'D99' }  
   sub DOStype         { '3A' }                           # 1 byte
   sub HDR_DIR_track   { 0x00 }                           # 1 byte
   sub HDRlabelOffset  { 0x04 }                           # 1 byte
   sub DIRinterleave   { 1 }                              # 1 byte
   sub FILinterleave   { 11 }                             # 1 byte
   sub BAMlabelOffset  { 0x04 }                           # 1 byte

   sub zones
   {
      (
         { 'highTrack' => 153, 'sectorsPerTrack' => 32 },  
         { 'highTrack' => 306, 'sectorsPerTrack' => 32 }, 
         { 'highTrack' => 459, 'sectorsPerTrack' => 32 },  
         { 'highTrack' => 918, 'sectorsPerTrack' => 32 },  # 8 bytes (really!)
      );
   };

   sub BAMinterleave   { 1 }                              # 1 byte
   sub BAMlocation     { $BAM_STEALS_FROM_ZONES }         # 1 byte
   sub BootTrack       { 0x00 }                           # 1 byte

   sub BAMsectors        { 20 } # ?? Math.ceil( (TRACKS * BAM_BYTES_PER_TRACK)/(254-BAMlabelOffset) );
   sub tracksPerBAMsector{ 48 } # ?? Math.floor(TRACKS/bamSectors);

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Format::C2040


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

1; # End of Commodore::Disk::Format::C9060
