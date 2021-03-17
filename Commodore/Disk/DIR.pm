package Commodore::Disk::DIR;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Image;
use Commodore::Disk::Access;
use Commodore::Disk::BAM;
use Commodore::Disk::Model;
use Commodore::Util;

=head1 NAME

Commodore::Disk::DIR - Directory access methods for Commodore disk images.

=head1 VERSION

Version 1.00 

=cut

our $VERSION = '1.00';
my $debug = 0;

=head1 SYNOPSIS

Provides access to the directory of Commodore disk images.

Example: to dump the directory of an image:

#!/usr/bin/perl
use Commodore::Disk::Image;
use Commodore::Disk::DIR;
################################################################
#
#  Prints the directory of the mounted image.
#
################################################################
my $filename = shift;
my $image    = Commodore::Disk::Image::loadImage( $filename );

print Commodore::Disk::DIR::dump( $image );

=head1 SUBROUTINES/METHODS

=head2 DIR( image [, track [, sector]] )

Reads and parses the image's Directory.

If the optional track and sector are passed in, it will read a 
directory structure starting from that location.  This is useful for 
parsing subdirectories.  **Note that the default sector is 1, not 0.

=cut
#################################################################
#
#  DIR( image [, track, sector] ) reads and parses the Directory
#
# If the optional track and sector are passed in, it will read a 
# directory structure starting from that location.  This is useful for 
# parsing subdirectories.  **Note that the default sector is 1, not 0.
#
#################################################################
sub DIR
{
   my $image    = shift;
   my $model    = $image->{ 'model' };
   my $track    = shift || $model->HDR_DIR_track;    
   my $sector   = shift || 0;

   $sector = $model->DIRsectorOffset if $track == $model->HDR_DIR_track; 
   $debug && Commodore::Util::log( "DIR::DIR", "reading DIR from [$track,$sector]" );
   my $dirref   = Commodore::Disk::Image::readFileChain( $image, $track, $sector );
   my @dir      = ();
   foreach my $dirBlock (@$dirref)
   {
      my @foo = parseDirectoryBlock( $dirBlock );
      push @dir, @foo;
   }

   return \@dir;
}

=head2 dump( image )

Dumps the directory to a string listing.

=cut
#################################################################
#
#  dump( image ) - dumps DIR to string.
#  dump( image, $dirref ) - dumps alternate DIR to string.
#
#################################################################
sub dump
{
   my $image  = shift;
   my $dirref = shift || $image->{ 'dir' };
   
   my @out   = ();
   
   return "No directory\n" unless $dirref;

   my $label  = $image->{ 'hdr' }->{ 'diskLabelASCII' } 
              . ', ' 
              . $image->{ 'hdr' }->{ 'diskId' };
   my $dtype  = $image->{ 'model' }->format;
   
   push @out, '%' x 64;
   push @out, "%";
   push @out, "%     ($dtype) Diskette Image \"$label\" Directory";
   push @out, "%";
   push @out, '%' x 64;
   
   my @entries = @$dirref;
   my @type    = qw/DEL SEQ PRG USR REL CBM DIR/;
   
   my $index = 0;

   push @out, sprintf( "%5s  %3s %-6s %-12s %-18s   %-7s",
	             qw/Entry Typ Bytes Created Filename Start/ );
	  
   push @out, sprintf( "%5s  %3s %-6s %-12s %-18s   %-7s",
	             qw/----- --- ----- ----------- ----------------- -----/ );
   
   foreach my $entry (@entries)
   {
	  $index++;
	  my $type = $type[ $entry->{ 'type' } - 0x80 ] 
	           || '-x-';
	  
	  my $lsu = '';
	  $lsu = '+' unless $entry->{ 'lsu' } && $entry->{ 'lsu' } == 0;
	  
      push @out, sprintf( "%4d:  %3s %5d%1s %12s %-18s  :%3d,%-3d", 
	               $index,
				   $type,
		           $entry->{ 'size' },
				   $lsu,
                   $entry->{ 'date' },
		           uc $entry->{ 'filenameASCII' },
                   @{$entry->{ 't,s' }} 
				   );				   
   }   
  
   push @out, "Blocks: " 
              . Commodore::Disk::Access::blocksTotal( $image ) 
			  . ' used: ' 
			  . (Commodore::Disk::Access::blocksTotal( $image ) - Commodore::Disk::Access::blocksFree( $image )) 
			  . ' free: ' 
			  . Commodore::Disk::Access::blocksFree( $image );
   
   return join "\n", @out;
}

=head2 parseDirectoryBlock( blockref )

Parses the file data from a reference to a directory block.

=cut
#################################################################
#
#  Parses the file data in a directory block
#
#################################################################
sub parseDirectoryBlock
{
   my $blockref = shift;

   my @dir;

   for (my $i=0; $i<length($$blockref); $i+=32)
   {
     my $entryref = readDiskDirectoryEntry( substr( $$blockref, $i, 32 ) );
     push @dir, $entryref;
   }

   return @dir;
}

=head2 formatDate( year, month, day, hour, minute )

Formats a date as a string.

=cut
sub formatDate
{
   my ($year, $month, $day, $hour, $minute) = @_;

   my ($s1, $m1, $h1, $d1, $m2, $yr) = localtime;
   
   unless ($year) # make up a date in the 80s.
   {
	   $year  = 82 + int(rand(5)) + int(rand(5));
	   $month = int(rand(12));
	   $day   = int(rand(30));
	   $hour  = int(rand(24));
	   $minute= int(rand(60));
   }

   my $date = '';
   my @month   = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec Err/; 
   
   if ( $year == $yr )
   {
	      $date = sprintf( "%3s %2d %2d:%02d", 
	                      $month[ $month ], 
						  $day,
						  $hour,
						  $minute )
   }
   else
   {
	      $date = sprintf( "%3s %2d %-5d",
	                      $month[ $month ], 
						  $day,
						  $year + 1900 )
   }

   return $date;
}


=head2 readDiskDirectoryEntry( bytes )

Unpacks a 32-byte directory entry and returns its constituent fields in the 
following structure:

{
        'dt,ds'  => [$dt,$ds],  # next directory track and sector, IF defined.
        'type'   => $ft,   # file type
        't,s'    => [$track,$sector],  # first track and sector of the file
        'filename' => $filename,  # file's name in PETSCII
		
		# REL field; for non-REL files, this may be the LSU byte.
		# if LSU is zero or undefined, then this field will not be present.
        'lsu'    => $lsu, 

        # The date string is a printable field with two possible formats:
		#
		# MMM DD HH:MM   if the date is this year
		# MMM DD YYYYY   if the date is > 12 months old
		#
        'date'   => $date,
        'year'   => $year,  
		'month'  => $month,
		'day'    => $day,
		'hour'   => $hour,
		'minute' => $minute,
        'blocks' => $blocks,  # size of file in blocks
        'filenameASCII'   => $ascii,   # file's name in ASCII
		
		# if the LSU exists, this is the actual size in bytes, 
		# otherwise it's an approximation:
        'size'   => $blocks * 254 + $lsumod,  
		
		# if the file is 0x84 (REL), then 'size' == LSU.
}

=cut
#################################################################
#
#  Unpacks a directory entry and returns its constituent fields.
#
#################################################################
sub readDiskDirectoryEntry
{
   my $dirEntryBytes = shift;

   my ($dt, $ds, $ft, $track, $sector, $filename,
       $junk1, $junk2,
       $lsu, # "last sector used" - to calculate exact file size
       $junk3,
       $year,      # 1900-2155   file creation timestamp:
       $month,     # 1-12
       $day,       # 1-31
       $hour,      # 0-23
       $minute,    # 0-59
       $fileSizeLo, 
       $fileSizeHi) = unpack "CCCCCa16CCCCCCCCCCC", $dirEntryBytes;

    $lsu ||= 0;
    $fileSizeLo ||= 0;
    $fileSizeHi ||= 0;

    my $blocks = $fileSizeLo + $fileSizeHi * 0x100;

    my $lsumod = 0;
    $lsumod = $lsu - 256 if $lsu > 0 && $ft != 0x84; # REL

	my $ascii = Commodore::Util::a0to32( $filename );
    
    srand( $dt * $ds + $track * $sector );
	
	my $date = formatDate( $year, $month, $day, $hour, $minute );
	
    my %entry = 
    (
        'dt,ds'  => [$dt,$ds],
        'type'   => $ft,
        't,s'    => [$track,$sector],
        'filename' => $filename,
        'lsu'    => $lsu,
        'date'   => $date,
        'year'   => $year,
		'month'  => $month,
		'day'    => $day,
		'hour'   => $hour,
		'minute' => $minute,
        'blocks' => $blocks,
        'filenameASCII'   => $ascii,
        'size'   => $blocks * 254 + $lsumod,
    );
	
	$entry{ 'size' } = $lsu if $ft == 0x84; # REL
	
	delete $entry{ 'dt,ds' } unless $entry{ 'dt,ds' }->[1];
	delete $entry{ 'lsu' } unless $lsu;

    return \%entry;
}

=head2 findDirEntry( image, name [, dirref [, lowFileType]] )

Returns the directory index (numbered from 1, not 0) 
of the file with the given name.  
Returns -1 if filename is not found.

=cut
#################################################################
#
#  Returns the file's directory index, or -1 if not found.
#
#################################################################
sub findDirEntry
{
   my $image   = shift;
   my $name    = shift;
   my $dirref  = shift;
   my $lowType = shift || 0x80;
   
   $debug && Commodore::Util::log( "DIR::findDirEntry", "Seeking [\'$name\']" );
   my $entryIndex = 0;

   $dirref = $image->{ 'dir' } if $dirref;
   
   # Check for a program with the same name.
   my @dir = @$dirref;
   
   foreach (0..@dir-1)
   {
      my $entry = $dir[ $entryIndex ];
      #print "Index = $entryIndex\n";
	  
	  #$debug && Commodore::Util::log( "DIR::findDirEntry", '[' . $entry->{ 'filenameASCII' } . ']' );
      if ( $entry->{ 'type' } > $lowType 
	     && ( ($entry->{ 'filename' } eq $name) || ($entry->{ 'filenameASCII' } eq $name) ) )
      {
    	 return $entryIndex;
      }
      $entryIndex++;
   }
   return -1;
}

=head2 rename( image, filename, newname )

Renames a file in the image, if found.

=cut
#################################################################
#
#  Renames a file in the root directory, if found.
#
#################################################################
sub rename
{
   my $image   = shift;
   my $name    = shift;
   my $newname = shift;

   my $index = findDirEntry( $image, $name );
   return unless $index > 0;

   my @dir = @{$image->{ 'dir' }};

   $dir[ $index ]->{ 'filename' } = $newname;
}

=head2 allocDirEntry( image, name [, dirtrack [, dirsector]] )

Allocate a directory entry, if possible.
If an active program with the same name exists, fail.
If there is no room left for directory entries, fail.

=cut
#################################################################
#
#  Allocate a directory entry, if possible.
#  If an active program with the same name exists, fail.
#  If there is no room left for directory entries, fail.
#
#################################################################
sub allocDirEntry
{
   my $image  = shift;
   my $name   = shift;
   my $track  = shift || -1;
   my $sector = shift || 0;
   
   my $dirref = $image->{ 'dir' };
   $dirref = DIR( $image, $track, $sector ) if $track > 0;
   
   my $entryIndex = 0;

   #
   # Check for a program with the same name.
   #
   if ( findDirEntry( $image, $name, $dirref ) > 0 ) # found
   {
      Commodore::Util::err( 'DIR::allocDirEntry', "'$name' exists.\n" );
      return (-1,-1,-1);
   }

   #
   # Find the first empty slot.
   #
   my @dir = @$dirref;
   
   foreach (0..@dir-1)
   {
      my $entry = $dir[ $entryIndex ];
      #print "Index = $entryIndex\n";

      last if $entry->{ 'type' } == 0 && $entry->{ 'blocks' } == 0;
      $entryIndex++;
   }

   $debug && Commodore::Util::log( 'DIR::allocDirEntry', "entry index found = $entryIndex" );
   
   # Check for room left on the disk for a new DIR entry.
   # Expand the DIR and update BAM if need be.
   my $model  = $image->{ 'model' };
   
   $track  = $model->HDR_DIR_track unless $track > 0;
   
   $sector = (1 + int( $entryIndex / 8 ) * $model->DIRinterleave) 
              % $model->sectorsPerTrack( $track );
   
   $sector += $model->BAMsectors if $model->BAMlocation == 0x01;
   
   #
   #  If this is a new directory sector, attempt to allocate it.
   #
   if ( ($entryIndex % 8 == 0) && Commodore::Disk::BAM::blockAvailable( $image, $track, $sector ) )
   {
      $debug && Commodore::Util::log( 'DIR::allocDirEntry', "calling b_alloc ($track,$sector)" );
      Commodore::Disk::BAM::b_alloc( $image, [[$track, $sector]] );
   }
   
   return ($track, $sector, $entryIndex);
}

=head2 createDirEntry( t, s, name, blocks, [type, lsu, year, month, day, hour, minute] )

Returns a binary-packed structure with the given data.

=cut
#################################################################
#
#  createDirEntry - creates a binary dir entry.
#
#################################################################
sub createDirEntry
{
   my $t      = shift;
   my $s      = shift;
   my $name   = shift;
   my $blocks = shift;
   my $type   = shift || 'PRG';
   my $lsu    = shift;
   my $yr     = shift;
   my $mo     = shift || 0;
   my $day    = shift || 1;
   my $hr     = shift || 0;
   my $min    = shift || 0;
   my $sec;

   ($sec, $min, $hr, $day, $mo, $yr) = localtime unless $yr;

#   my $data =
#   {
#		'type'     => $type,
#		't,s'      => [ $t, $s ],
#		'filename' => $name,
#		'lsu'      => $lsu,
#		'blocks'   => $blocks,
#		'year'     => $yr,
#		'month'    => $mo,
#		'day'      => $day,
#		'hour'     => $hr,
#		'minute'   => $min
#   };
     
   my $data = pack( 'CCCa16xxCxCCCCCCC', 
                     $type,
                     $t,$s,
					 $name,
					 $lsu || 0,
					 $yr,
					 $mo,
					 $day,
					 $hr,
					 $min,
					 $blocks % 256,
					 $blocks / 256 );

   return $data;
}

=head2 writeDirEntry( image, track, sector, entryNum, data )

Writes a 30-byte directory entry into a particular position in a particular block.

=cut
#################################################################
#
#  writeDirEntry( image, track, sector, entryNum, data )
#  Writes a 30-byte directory entry into the given track, sector, and entry.
#
#################################################################
sub writeDirEntry
{
   my $image  = shift;
   my $track  = shift;
   my $sector = shift;
   my $entry  = shift; # 0 to 7
   my $data   = shift; # a structure
   my $model  = $image->{ 'model' };
   
   my $year = $data->{ 'year' };
   $year -= 1900 if $year > 255;

   #$debug && Commodore::Util::log( 'DIR::writeDirEntry', join ' ', sort keys %$data ) ;
   
   my $newDirEntry = pack( 'CCCa16xxCxCCCCCCC', 
                     $data->{ 'type' },
                     @{$data->{ 't,s' }},
					 $data->{ 'filename' },
					 $data->{ 'lsu' } || 0,
					 $year,
					 $data->{ 'month' },
					 $data->{ 'day' },
					 $data->{ 'hour' },
					 $data->{ 'minute' },
					 $data->{ 'blocks' } % 256,
					 $data->{ 'blocks' } / 256 );
   
   my $offset = 0x100 * $model->getSectorOffset( $track, $sector );   
   $offset += 2 + $entry * 32;

   $debug && Commodore::Util::log( 'DIR::writeDirEntry', 
              "writing " . length($newDirEntry)
			. " bytes to $entry [$track,$sector], offset \$"
			. sprintf( "%x", $offset ) );

   #$debug && Commodore::Util::hexdump( $newDirEntry );
   return Commodore::Disk::Image::writeBytes( $image, $offset, \$newDirEntry );
}

=head2 getNextDirSector( image, t, s )

Calculates the next directory sector, using DIR interleave.
BEWARE!  
This method does NOT check for used sectors!  (It probably should)
This method does NOT leave the directory track!  (There should probably be an option)

=cut
#################################################################
#
#  getNextDirSector( image, t, s ) - figure out where we are.
#
#  Beware -- does NOT check for used sectors!
#
#################################################################
sub getNextDirSector
{
   my $image = shift;
   my $track = shift;
   my $sector = shift;
   my $model = $image->{ 'model' };
   my $dirSector = 1;
   
   return ($model->HDR_DIR_track, $dirSector) if $track == 0;
   
   # else...
   
   my $maxSectors = $model->sectorsPerTrack( $track );
   
   $sector += $model->DIRinterleave % $maxSectors; # wrap track
   
   return ($track, $sector); # ($model->HDR_DIR_track, $sector);
}

=head2 clear( image )

Wipes out DIR in the BAM.
Sets all the sectors in the header track to 1 (free), 
EXCEPT for sector 0 (reserved for header) and BAM sectors, 
(regardless of where they are located).

=cut
#################################################################
#
#  clear( image ) - wipes out DIR in the BAM.  sets all the 
#  sectors in the header track, to 1 (free), EXCEPT for 
#  sector 0 (reserved for header) and BAM sectors, (regardless
#  of wherever they are located).
#
#################################################################
sub clear
{
   my $image = shift;
   my $model = $image->{ 'model' };
   
   for my $sector ( 1..$model->sectorsPerTrack( $model->HDR_DIR_track )-1 )
   {
      my $track = $model->HDR_DIR_track;
      #$debug && Commodore::Util::log( "DIR::clear()", "calling b_free: [$track, $sector]" );
      Commodore::Disk::BAM::b_free( $image, [[$track, $sector]] );
   }
   
   #$debug && Commodore::Util::log( "DIR::clear()", "4 calling b_alloc" );
   Commodore::Disk::BAM::b_alloc( $image, [[$model->HDR_DIR_track, 0]] ); # just in case
   
   my ($bamTrack, $bamSector) = $model->BAMposition;
#   my $bamTrack = $model->HDR_DIR_track;
#   $bamTrack-- if $model->BAMlocation == 0x02; # precedes header   
#   my $bamSector = 0;
#   $bamSector++ if $model->BAMlocation == 0x01; # follows header
   
   for ( 1..$model->BAMsectors )
   {
      $debug && Commodore::Util::log( "DIR::clear()", "allocating BAM sectors" );
      Commodore::Disk::BAM::b_alloc( $image, [[$bamTrack, $bamSector]] );
	  $bamSector += $model->BAMinterleave;
   }
   $debug && Commodore::Util::log( "DIR::clear()", "Done." );
}

=head2 sync( image [, dirref, track, sector] )

Commits directory changes to the underlying byte buffer image.
If no directory reference is provided, the root directory is assumed.
If no track (or sector) is provided, the root directory location
is assumed.

=cut
#################################################################
#
#  sync( image [, dirref, track, sector] ) - writes DIR to the buffer image
#
#################################################################
sub sync
{
   my $image  = shift;
   my $dirref = shift;
   my $track  = shift || 0;
   my $sector = shift || 0;

   my $model  = $image->{ 'model' };
   my $buffer = $image->{ 'data' };
   my $data   = $$buffer;
   
   $dirref = $image->{ 'dir' } unless $dirref;
   my @entries = @$dirref;
   
   clear( $image );
   
   while (@entries)
   {
 	  ($track, $sector) = getNextDirSector( $image, $track, $sector );
	  $debug && Commodore::Util::log( "DIR::sync()", "DIR sector [$track/$sector]" );
      for my $entryIndex ( 0..7 )
	  {
	     last unless @entries;
		 my $entry = shift @entries;
		 
		 my $name = $entry->{ 'filename' };
		 my $blocks = $entry->{ 'blocks' };
		 
		 $debug && Commodore::Util::log( "DIR::sync()", "writing DIR entry $entryIndex (\"$name\", $blocks blocks)" );
		 writeDirEntry( $image, $track, $sector, $entryIndex, $entry )
		    if $entry->{ 'blocks' } > 0;
	  }
   } 
   
   return $image->{ 'data' }; # done
}



=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::DIR


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

1; # End of Commodore::Disk::DIR
