package Commodore::Disk::Format::C_ANY;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Util;

=head1 NAME

Commodore::Disk::Format::C_ANY - Interface object for all custom disk images.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my  $debug   = 0;

=head1 SYNOPSIS

Represents "custom" disk images, whose format differs from standard image types
in parametrically describable ways.

The X64 "Custom Image Parameter Block" specification consists of these 22 bytes,
starting at offset 0x0A in the X64 header.

NOTES:
* "Zero" for a high track means the zone is absent.
* "Zero" for sectors per track is interpreted as 256 sectors, NOT zero.

             0A: DOS type (In hex, i.e. 2A = '2A')
             0B: Header/Directory track (i.e. 0x12)
             0C: Header label offset (i.e. 0x90)
             0D: DIR interleave (i.e. 3)
             0E: FIL interleave (i.e. 11)
             0F: BAM label offset (i.e. 0x04)
          10-11: Zone 1 high track, sectors per track
          12-13: Zone 2 high track, sectors per track
          14-15: Zone 3 high track, sectors per track
          16-17: Zone 4 high track, sectors per track
             18: BAM interleave (i.e. 0)
             19: BAM location flag:
                 0x00: co-located on header block
                 0x01: immediately follows header block
                 0x02: sector 0 of preceding track
             1A: BAM sector count
             1B: Tracks per BAM sector
          1C-1E: $00
             1F: Boot track

=cut

my $doubleSided;
my $myFormat;
my $DOStype;
my $HDR_DIR_track;
my $HDRlabelOffset;
my $DIRinterleave;
my $FILinterleave;
my $BAMlabelOffset;
my @zones;
my $BAMinterleave;
my $BAMlocation;
my $BootTrack;
my $BAMsectors;
my $tracksPerBAMsector;

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new instance.

=cut

sub new { bless {}, shift; }

   ##################################
   #
   #  BAMlocation CONSTANTS
   #
   ##################################

   my $BAM_ON_HDR            = 0x00;
   my $BAM_FOLLOWS_HDR       = 0x01;
   my $BAM_TRACK_BEFORE_HDR  = 0x02;
   my $BAM_SPILLS_OVER       = 0x47; # 0x47 = decimal 71; i.e. "1571 mode"
   my $BAM_STEALS_FROM_ZONES = 0x5A; # = decimal 90; i.e. "90x0 mode"

=head2 init

Initializes a custom image from parametric data.  The parameters to this method are:

$doubleSidedFlag
$format
$dosType
$hdrTrack
$hdrLabelOffset
$directoryInterleave
$fileInterleave
$bamOffset
$z1t, $z1s,   # zone 1 high track (0=zone is absent), sectors per track (0=256 blocks, not 0)
$z2t, $z2s,   # zone 2 high track, sectors per track 
$z3t, $z3s,   # zone 3 high track, sectors per track
$z4t, $z4s,   # zone 4 high track, sectors per track
$bamInterleave 
$bam relocation ("magic" constant): one of

   - $BAM_ON_HDR            = 0x00;
   - $BAM_FOLLOWS_HDR       = 0x01;
   - $BAM_TRACK_BEFORE_HDR  = 0x02;
   - $BAM_SPILLS_OVER       = 0x47; # 0x47 = decimal 71; i.e. "1571 mode"
   - $BAM_STEALS_FROM_ZONES = 0x5A; # = decimal 90; i.e. "90x0 mode"

$bam sector count, 
$tracks per BAM sector,
$unused 1, 
$unused 2, 
$unused 3, 
$boot track
	   
=cut
sub init
{
   my $self = shift;
   my ($sides, $format, 
       $dosType, $hdrTrack, $hdrLabel, $dirInt, $filInt, $bamOffs,
       $z1t, $z1s, $z2t, $z2s, $z3t, $z3s, $z4t, $z4s,
	   $bamInt, $bamLoc, $bamSec, $tpBAM, $j1, $j2, $j3, $boot) = @_;

	$debug && Commodore::Util::log( 'Commodore::Disk::Format::C_ANY::init', 'Initializing' );
    $doubleSided       = $sides;
    $myFormat          = $format; # 'X64';
    $DOStype           = $dosType;
    $HDR_DIR_track     = $hdrTrack;
    $HDRlabelOffset    = $hdrLabel;
    $DIRinterleave     = $dirInt;
    $FILinterleave     = $filInt;
    $BAMlabelOffset    = $bamOffs;
	
	if ( $bamLoc == $BAM_STEALS_FROM_ZONES ) # i.e. 90x0 mode
	{
	   $zones[0] = unpackZone( $z1t, $z1s );
	   $zones[1] = unpackZone( $z2t, $z2s );
	   $zones[2] = unpackZone( $z3t, $z3s );
	   $zones[3] = unpackZone( $z4t, $z4s );
	}
	else # normal mode
	{
           $z1s = 256 unless $z1s;         # 0 blocks = 256 blocks
           $z2s = 256 unless $z2t && $z2s; # 0 blocks = 256 blocks
           $z3s = 256 unless $z3t && $z3s; # 0 blocks = 256 blocks
           $z4s = 256 unless $z4t && $z4s; # 0 blocks = 256 blocks

       $zones[0] = { 'highTrack' => $z1t, 'sectorsPerTrack' => $z1s };
	   $zones[1] = { 'highTrack' => $z2t, 'sectorsPerTrack' => $z2s };
	   $zones[2] = { 'highTrack' => $z3t, 'sectorsPerTrack' => $z3s };
	   $zones[3] = { 'highTrack' => $z4t, 'sectorsPerTrack' => $z4s };
	}

    if ( $debug )
    {	
	   foreach (@zones)
	   {
	      print $_->{ 'highTrack' }, ': ', $_->{ 'sectorsPerTrack' }, "\n";
	   } 
	}
	
    $BAMinterleave     = $bamInt;
    $BAMlocation       = $bamLoc;
    $BootTrack         = $boot;
    $BAMsectors        = $bamSec;
    $tracksPerBAMsector = $tpBAM;

    $debug && Commodore::Util::log( 'Commodore::Disk::Format::C_ANY::init', "Format = $myFormat" ); # - bam location = $bamLoc\n";

	return $self;
}

	#
	#  Unpack **Nontypical** Zone T/S values.	
	#
	#  DETAILS: Nontypical values steal the top 2 bits from the Sector Count
	#  and add them to the Track Index.  Thus a nontypical disk can reference
	#  up to Track 1023, and can't have more than 63 sectors per track.
	#
	sub unpackZone
	{
		my ($highTrack, $sectorsPerTrack) = @_;
		my $extraTracks = ($sectorsPerTrack >> 6) << 8;
		return 
		{
			'highTrack' => $highTrack + $extraTracks, 
			'sectorsPerTrack' => $sectorsPerTrack & 0x3f
		};
	}



=head1 PARAMETER ACCESS METHODS

These are the same as those from "standard" image classes, e.g. the C1541.

=head2 doubleSided (0=no)

=head2 format

=head2 DOStype

=head2 HDR_DIR_track

=head2 HDRlabelOffset

=head2 DIRinterleave

=head2 FILinterleave

=head2 BAMlabelOffset

=head2 zones

=head2 BAMinterleave

=head2 BAMlocation

=head2 BootTrack

=head2 BAMsectors

=head2 tracksPerBAMsector

=cut
   ######################################################
   #
   #  Format Specifics
   #
   #  In order to parse a Commodore disk image properly,
   #  you will need to know these things.
   #
   ######################################################
   sub doubleSided        { $doubleSided }
   sub format             { $myFormat }
   sub DOStype            { $DOStype }     
   sub HDR_DIR_track      { $HDR_DIR_track }
   sub HDRlabelOffset     { $HDRlabelOffset }
   sub DIRinterleave      { $DIRinterleave }
   sub FILinterleave      { $FILinterleave }
   sub BAMlabelOffset     { $BAMlabelOffset }
   sub zones              { @zones }
   sub BAMinterleave      { $BAMinterleave } 
   sub BAMlocation        { $BAMlocation }
   sub BootTrack          { $BootTrack } 
   sub BAMsectors         { $BAMsectors  }
   sub tracksPerBAMsector { $tracksPerBAMsector }
  
=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Format::C_ANY


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

1; # End of Commodore::Disk::Format::C_ANY
