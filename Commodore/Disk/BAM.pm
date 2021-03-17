package Commodore::Disk::BAM;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Image;
use Commodore::Disk::Model;
use Commodore::Util;

=head1 NAME

Commodore::Disk::BAM - Block Allocation Map (BAM) read/write methods.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my $debug = 0;


=head1 SYNOPSIS

This module provides read/write access to the BAM of a Commodore disk image.

Here's a short script to mark a block used or free in the BAM:

#!/usr/bin/perl
use Commodore::Disk::Access;
use Commodore::Disk::BAM;
################################################################
#
#  Marks a specific block in BAM as 'used' or 'free'.
#
################################################################
my $file   = shift || die "SYNOPSIS: $0 <file> <track> <sector> [mark [device]]\n";
my $track  = shift || die "SYNOPSIS: $0 <file> <track> <sector> [mark [device]]\n";
my $sector = shift || 0;
my $mark   = shift || 0;

################################################################
#
#  Load the image.
#
################################################################
my $image  = Commodore::Disk::Access::load( $file );

################################################################
#
#  Mark the block as indicated, save, and print the BAM.
#
################################################################
Commodore::Disk::BAM::markBlocks( $image, [[$track, $sector]], $mark );
Commodore::Disk::Access::save( $image );
print Commodore::Disk::BAM::dump( $image );


=head1 SUBROUTINES/METHODS

=head2 BAM( image )

Returns the BAM as a list of allocations by track,
and inside that, allocations by sector within that track.

=cut
#################################################################
#
#  BAM( image ) - Returns the BAM as a list of allocations by track,
#  and inside that, allocations by sector within that track.
#
#################################################################
sub BAM
{
   my $image   = shift;
   my $model   = $image->{ 'model' };
   
   my $dataref = $image->{ 'data' };
   my $BAMsectorBytes = $model->BAMsectorBytes();
   
   my @bamout = ();
   
   #
   #  Read the BAM as a file!
   #
   my ($bamTrack,$bamSector) = $model->BAMposition();
   my $bamBlocks = Commodore::Disk::Image::readFileChain( $image, $bamTrack, $bamSector, $model->BAMsectors );
   my $blockCount = scalar @$bamBlocks;
   $debug && Commodore::Util::log( "BAM::BAM", "read $blockCount blocks of BAM from [$bamTrack,$bamSector]" );

   my $track = 1;
   my $BAMlabelOffset = $model->BAMlabelOffset;
   foreach my $block (@$bamBlocks)
   {
      my $blockData = substr( $$block, $BAMlabelOffset );
      for (1..$model->tracksPerBAMsector())
	  {
	     last if $track > $model->trackCount;
		 
#		 $debug && Commodore::Util::log( 'BAM::BAM', "Unpacking BAM for track $track of " . $model->trackCount );
	     my $bitlen = $model->sectorsPerTrack( $track );
	     my ($FSC, $bits) = unpack( "Cb$bitlen", $blockData );
		 $blockData = substr( $blockData, 1 + $BAMsectorBytes );
		 
		 my @entries = split '', $bits;

		 my $bamEntry = 
	     {
	        'track' => $track,    # this is for redundancy
		    'fsc'   => $FSC,      # Free Sector Count
		    'map'   => \@entries  # allocation bitmap for this track
	     };
	     
	     push @bamout, $bamEntry;

	     $track++;
	  }
   }

   return \@bamout;
}

=head2 dump( image )

Dumps the image's BAM to a printable string.

=cut
#################################################################
#
#  dump( image ) - dumps BAM to string.
#
#################################################################
sub dump
{
   my $image  = shift;
   my $bam    = $image->{ 'bam' };
   my $label  = $image->{ 'hdr' }->{ 'diskLabelASCII' };
   my $model  = $image->{ 'model' };
   my $type   = $model->format;
   my $disk   = $model->device;
      
   my $bamPos = join( ',', $model->BAMposition );
   
   my @out   = ();
   
   push @out,  '%' x 74;
   push @out,  "%";
   push @out,  "%  ($type) Diskette Image \"$label\" BAM Summary";
   push @out,  "%";
   push @out,  "%   - BAM offset      : \$" . sprintf( "%x", $model->BAMsectorOffset );
   push @out,  "%   - BAM position    : " . $bamPos;
   push @out,  "%   - BAM size        : " . $model->BAMsize;
   push @out,  "%   - BAM sector bytes: " . $model->BAMsectorBytes;
   push @out,  "%   - BAM map depth   : " . scalar @$bam;
   push @out,  "%";
   push @out,  '%' x 74;

   #$debug && print "BAM::dump() DEBUG:\n", join( "\n", @out ), "\n";
   
   my $total = 0;
   my $free  = 0;

   foreach my $be (@$bam)
   {
      my @salloc = @{$be->{ 'map'   }};
      my $track  = $be->{ 'track' };
      my $fsc    = $be->{ 'fsc'   };
   
      push @out, sprintf "Track %-3d  %3d  %s", $track, $fsc, join '', @salloc;
   
      $total += scalar @salloc;
      $free  += $fsc;
   }

   push @out,  "$total total blocks";
   push @out,  "$free blocks free";
   
   return join "\n", @out;
}

=head2 initialize( image )

Resets an image's BAM to "factory settings"; that is, it sets
all sectors unallocated except for the header track and, potentially,
independent BAM sectors.

=cut
#################################################################
#
#  initialize( image ) - reset BAM to factory settings
#
#################################################################
sub initialize
{
   my $image = shift;
   my $model = $image->{ 'model' };
   
   my @bam = ();

   my ($trackCount) = $model->trackCount;
   
   for my $track ( 1..$trackCount )
   {
      my $FSC = $model->sectorsPerTrack( $track );
      $debug && Commodore::Util::log( 'BAM::initialize', "Track $track free sectors = $FSC" );
      my @entries = ( 1 ) x $FSC;
	  my $bamEntry = 
	  {
	     'track' => $track,    # this is for redundancy
		 'fsc'   => $FSC,      # Free Sector Count
		 'map'   => \@entries  # allocation bitmap for this track
	  };
	  
	  push @bam, $bamEntry;
   }
  
   $image->{ 'bam' } = \@bam;
   
   #
   #  Mark HDR, BAM.
   #
   my ($track,$sector) = $model->BAMposition();
   
   b_alloc( $image, [[ $track, $sector ]] );
      
   if ( $model->BAMlocation > 0x00 ) # separate BAM sectors
   {
      for ( 1..$model->BAMsectors )
      {
         $debug && Commodore::Util::log( 'BAM::initialize', "calling b_alloc: $_ [$track, $sector]" );

         b_alloc( $image, [[ $track, $sector ]] );
		 
         $sector += $model->BAMinterleave;
      }
   }
}

=head2 blockAvailable( image, track, sector [, value] )

Gets/sets the BAM bit for the given block.

=cut
#################################################################
#
#  blockAvailable( image, track, sector [, value] ) - gets/sets 
#  the BAM bit for the given block.
#
#################################################################
sub blockAvailable
{
   my $image = shift;
   my $track = shift;
   my $sector = shift;
		 
   return $image->{ 'bam' }->[ $track-1 ]->{ 'map' }->[ $sector ];
}

=head2 freeList( image )

Returns a list of free sectors in the form (@[t,s]).

=cut
#################################################################
#
#  freeList( image ) - returns a list of free sectors (@[t,s]).
#
#  DOES NOT INCLUDE THE HEADER TRACK.
#
#  *** DOES NOT USE FILE INTERLEAVE ***
#
#################################################################
sub freeList
{
   my $image    = shift;
   my $bam      = $image->{ 'bam' };
   my $model    = $image->{ 'model' };
   my @freeList = (); # [t,s] list

   #
   #  The BAM is ordered from track 1.
   #  Reorganize in a write-preferred order.
   #
   my @bam = @$bam;
   my $top = (scalar @bam)-1;
   my $mid = int($top/2)+1; # e.g. (35/2)+1 = 18
   my $q1  = int($mid/2);   # e.g. (18/2)   = 9
   my $q3  = int($q1*3);    # e.g. (3*9)    = 27
   
   #
   #  WHAT IT SHOULD DO is iterate using File Interleave
   #  through the sectors available.
   #
   #$debug && Commodore::Util::log( 'BAM::freeList', "q1[$q1] mid[$mid] q3[$q3] top[$top]" );
   my @writeOrderBam = 
   (
      @bam[ $q1  .. $mid-1 ],
	  @bam[ $mid .. $q3-1  ],
	  @bam[ 1    .. $q1-1  ],
	  @bam[ $q3  .. $top   ]
   );
   
   foreach my $be (@writeOrderBam)
   {
      my @map = @{$be->{ 'map' }};
      my $t = $be->{ 'track' };
	  
	  #
	  #  DO NOT PUT THE HEADER TRACK ON THE FREE LIST!!!
	  #
	  next if $t == $model->HDR_DIR_track;
	  
      for my $s (0..@map-1)
      {
         push @freeList, [ $t, $s ] if $map[$s] == 1;
      }
   }
      
   return \@freeList;
}

=head2 markBlocks( image, $tsRef [, mark] )

Marks block(s) as used or free.  The default is "used".

=cut
#################################################################
#
#  markBlocks( image, $tsRef [, mark] ) - marks block(s) used or free.
#
#  Operates on the image meta-data; actual changes are committed
#  at the same time the file is written.  $tsRef is an arrayref
#  of [t,s] pairs to mark.
#
#################################################################
sub markBlocks
{
   my $image  = shift;
   my $tsRef2 = shift;
   my $mark   = shift || 0; # default to 'used'
   $mark      = 1 if $mark != 0;
   
   my @tsRef = @$tsRef2;
   
   foreach my $locref (reverse @tsRef)
   {
      my ($track, $sector) = @$locref;
      #
      # Find the BAM segment 
      #
      my $status = $image->{ 'bam' }->[ $track-1 ]->{ 'map' }->[ $sector ];

      #
      # If its mark is different, then mark it and update FSC.
      #
      if ($status != $mark)
      {
         $image->{ 'bam' }->[ $track-1 ]->{ 'map' }->[ $sector ] = $mark;
         $image->{ 'bam' }->[ $track-1 ]->{ 'fsc' }-- if $mark == 0;
         $image->{ 'bam' }->[ $track-1 ]->{ 'fsc' }++ if $mark == 1;		 
      }
	  elsif ( $status == 0 ) # already allocated... danger.
	  {
	     return 0;
	  }
   }
   
   return 1;
}

=head2 b_alloc( image [[track, sector]] )

Marks blocks used.

=cut
#################################################################
#
#  b_alloc( image, [[track, sector]] ) - marks blocks used.
#
#################################################################
sub b_alloc
{
   markBlocks( @_ );
}

=head2 b_free( image [[track, sector]] )

Marks blocks free.

=cut
#################################################################
#
#  b_free( image, [[track, sector]] ) - marks blocks free.
#
#################################################################
sub b_free
{
   markBlocks( @_, 1 );
}

=head2 allocateSectors( image, count )

Allocates a number of blocks in the image and returns a T,S list.  
If there is an error or there are not enough blocks available, an empty list is returned.

=cut
#################################################################
#
#  allocateSectors( image, count ) - allocates a number of blocks
#  in the image and returns a T,S list.  If there is an error or
#  there are not enough blocks available, an empty list is returned.
#
#################################################################
sub allocateSectors
{
   my $image = shift;
   my $blockCount = shift || return [];

   #
   # Get $blockCount free sectors.
   #
   my $freeListRef = freeList( $image );   
   my @freeList    = @$freeListRef;
   return [] if @freeList < $blockCount;
   @freeList = @freeList[ 0..$blockCount-1 ];
   
   #
   # Mark them used.
   #
   my $ret = b_alloc( $image, \@freeList );
   
   return [] unless $ret; # error if return val is 0
   
   return \@freeList;
}

=head2 sync( image )

Writes BAM data to the buffer image.

=cut
#################################################################
#
#  sync( image ) - writes BAM data to the buffer image
#
#################################################################
sub sync
{
   my $image  = shift;
   my $model  = $image->{ 'model' };
   my $buffer = $image->{ 'data' };
   my $data   = $$buffer;
   
   my ($bamTrack,$prevSector) = $model->BAMposition();
   my $bamSector = $model->BAMsectorOffset(); # Byte Offset = 0x100 * $model->BAMsectorOffset();
   
   my $track = 1;

   my $BAMsectorBytes = $model->BAMsectorBytes(); 
   my $interleave = $model->BAMinterleave;
   my $BAMblocks = $model->BAMsectors;

   $BAMblocks = 1 if $BAMblocks == 0; # i.e. Header sector 

   my $tpbs = $model->tracksPerBAMsector;
   $debug && Commodore::Util::log( 'BAM::sync', "BAM sectors: $BAMblocks, Tracks per BAM sector: $tpbs"  );
   
   for ( 1..$BAMblocks )
   {
      my $bamSectorOffset = 0x100 * $bamSector;
	  #
      # write sector label ($bamSectorOffset + 2)
	  #
	  my $labelOffset = $bamSectorOffset + 2;

      # 
      # write BAM
      #	  
	  my $bamOffset = $bamSectorOffset + $model->BAMlabelOffset; # BAM starts here
	  
      for ( 1..$model->tracksPerBAMsector )
	  {
	     last if $track > $model->trackCount;
		 
	     my $bamEntry = $image->{ 'bam' }->[ $track-1 ];
		 my $fsc      = $bamEntry->{ 'fsc' };
		 my @map      = @{$bamEntry->{ 'map' }};
		 my $map      = join '', @map;		 	

         $debug && Commodore::Util::log( 'BAM::sync', "Track[$track], FSC[$fsc], $map" );
		 
		 my $entry    = pack( 'Cb*', $fsc, $map );
		 
		 Commodore::Disk::Image::writeBytes( $image, $bamOffset, \$entry );

         # next BAM entry			   
		 $bamOffset += 1 + $BAMsectorBytes; 
		 $track++;
	  }
	  
	  if ( $interleave > 0 )
	  {
	     #
	     #  advance to next BAM block
	     #
         $bamSector += $interleave;
	  
	     #
	     #  Write the T/S link for the *previous* BAM sector.
	     #
         
	     my $nextSector = $prevSector + $interleave;
	     $debug && Commodore::Util::log( 'BAM::sync', "[$bamTrack,$prevSector]->[$bamTrack,$nextSector]" );
	     Commodore::Disk::Image::writeTSLink( $image, $bamTrack, $prevSector, $bamTrack, $nextSector );
	     $prevSector = $nextSector; # now update the previous sector number.
	  }
   }
   
   #
   #  Wipe out the final T/S link for the last BAM block
   #
   if ( $interleave > 0 )
   {
      $prevSector -= $interleave; # back up one to the final block
      $debug && Commodore::Util::log( 'BAM::sync', "[$bamTrack,$prevSector]->[0,0]" );
      Commodore::Disk::Image::writeTSLink( $image, $bamTrack, $prevSector );
   }
   
   return $image->{ 'data' }; #done
}

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::BAM


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

1; # End of Commodore::Disk::BAM
