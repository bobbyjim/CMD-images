package Commodore::Disk::Access;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Image;
use Commodore::Disk::Model;
use Commodore::Disk::BAM;
use Commodore::Disk::DIR;
use Commodore::Disk::HDR;
use Commodore::Util;

=head1 NAME

Commodore::Disk::Access - Methods for accessing files in Commodore disk images.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my  $debug = 1;

=head1 SYNOPSIS

General methods for
    creating images,
    loading and saving images,
    reading and writing to the header,
    reading the directory from an image,
    reading a particular directory entry,
    reading a file from an image,
    writing a file to an image,
    deleting a file from an image.

Here's a script for extracting a file from a disk:

#!/usr/bin/perl
use Commodore::Disk::Access;
################################################################
#
#  Saves a file from DIR index of the given image file.
#
################################################################
my $filename = shift || die "SYNOPSIS: $0 <index> [device]\n";
my $index    = shift || die "SYNOPSIS: $0 <index> [device]\n";
my $image    = Commodore::Disk::Access::load($filename);
Commodore::Disk::Access::readStoreProgramByIndex( $image, $index );


=head1 SUBROUTINES/METHODS

=head2 create( filename, label, ID )

Convenience method. Creates a new disk image.

=head2 load( filename )

Convenience method. Loads an image from a file.

=head2 save( image, filename ) 

Convenience method. Saves the image to its file.

=cut
#################################################################
#
#  create( filename, label, ID ) - Creates a new disk image
#  load( filename ) - Loads (and returns) an image from a file.
#  save( image, filename ) - Saves an image to a file.
#
#################################################################
sub create { return Commodore::Disk::Image::createImage( @_ ); }
sub load   { return Commodore::Disk::Image::loadImage( @_ );   }
sub save   { return Commodore::Disk::Image::saveImage( @_ );   }

=head2 summary( image )

Returns a string containing an image's header listing, BAM listing, and directory listing.

=cut
#################################################################
#
#   summary( $image ) - displays Hdr, BAM, and DIR.
#
#################################################################
sub summary
{
   my $image  = shift;
   my $hdrref = Commodore::Disk::HDR::hdr( $image );
   return ''
        . Commodore::Disk::HDR::dump( $image ) 
        . "\n\n"
        . $image->{ 'model' }->summary()
	. "\n\n"
	. Commodore::Disk::DIR::dump( $image )
	. "\n\n"
	. Commodore::Util::hexdump( $$hdrref )
        . "\n\n"
	. Commodore::Disk::BAM::dump( $image )
	. "\n";
}

=head2 hdr( image )

Convenience method. Returns a structure containing header data:
  {
     'dosType':     <dos type>    e.g. '2A'
     'diskLabel':   <label>       e.g. 'MYDISKáááááááááá'
     'diskLabelASCII': <label>    e.g. 'MYDISK'
     'diskId':      <ID>          e.g. 'AA'
  }

=cut
#################################################################
#
#  hdr( $image ) - Returns a structure containing header data:
#  {
#     'dosType':     <dos type>    e.g. '2A'
#     'diskLabel':   <label>       e.g. 'MYDISKáááááááááá'
#     'diskLabelASCII': <label>    e.g. 'MYDISK'
#     'diskId':      <ID>          e.g. 'AA'
#  }
#
#################################################################
sub hdr
{
   my $image = shift;
   return $image->{ 'hdr' };
}

=head2 setLabel( image, label, ID, dosType )

Convenience method. Sets header data.

=cut
#################################################################
#
#  setLabel( image, label, ID, dosType ) - Sets header data.
#
#################################################################
sub setLabel
{
   my $image   = shift;
   my $label   = shift;
   my $id      = shift || $image->{ 'diskId' };
   my $dosType = shift || $image->{ 'dosType' };

   Commodore::Disk::HDR::setHeaderLabel( $image, $label, $id, $dosType );
}

=head2 getLabel( image )

Convenience method.  Returns the disk header label in ASCII.

=cut
#################################################################
#
#  getLabel( image ) - just returns the disk header label in ASCII
#
#################################################################
sub getLabel
{
   my $image = shift;
   return $image->{ 'hdr' }->{ 'diskLabelASCII' };
}

=head2 bam( image )

Convenience method.  Returns an array of BAM data:
    Each element corresponds to a track, and contains the
    track number, the Free Sector Count (FSC), and a
    sub-array of sector allocations.

=cut
#################################################################
#
#  bam( $image ) - Returns an array of BAM data:
#    Each element corresponds to a track, and contains the
#    track number, the Free Sector Count (FSC), and a
#    sub-array of sector allocations.
#
#################################################################
sub bam
{
   my $image  = shift;
   return $image->{ 'bam' };
}

=head2 blocksTotal( image ) 

Calculates and returns the total number of blocks in the image.

=cut
#################################################################
#
#   blocksTotal( image ) - returns the total number of blocks
#
#################################################################
sub blocksTotal
{
   my $image = shift;
   my $bam   = $image->{ 'bam' };
   my $total = 0;
   
   foreach my $be (@$bam)
   {
      my @map = @{$be->{ 'map' }};
	  $total += scalar @map;
   }
   return $total;
}

=head2 blocksFree( image )

Calculates and returns the number of free blocks in the image.

=cut
#################################################################
#
#   blocksFree( image ) - returns the number of free blocks
#
#################################################################
sub blocksFree
{
   my $image = shift;
   my $bam   = $image->{ 'bam' };
   my $free  = 0;
   
   foreach my $be (@$bam)
   {
      my @map  = @{$be->{ 'map' }};
	  my $f1 = grep( /1/, @map );
	  my $f2   = $be->{ 'fsc' };
	  #print "FSC ERROR in BAM: $f1 <> $f2\n" if $f1 != $f2;
      $free += $be->{ 'fsc' };
   }
   return $free;
}

=head2 dir( image [, track [, sector]] ) 

Convenience method.  Returns directory entries as an array of
structures, in order of appearance in the directory.  If the optional
track (and optional sector) are supplied, a directory file is parsed
from that location instead of the system root location.

The entry structure is as follows:
  
  [   'dt,ds'          # directory track and sector (often 0,0)
      'type'           # file type
      't,s'            # file starting track and sector
      'filename'       # filename in PETSCII
      'filenameASCII'  # filename translated into ASCII
      'lsu'            # REL length or LSU
      'date'           # UNIX-style string representation of the date field
      'year'           # year field, from 1900
	  'month'          # month (1-12)
	  'day'            # month day (1-31)
	  'hour'           # hour (0-23)
	  'minute'         # minute (0-59)
      'blocks'         # file size in blocks
      'size'           # file size using LSU, *if available*
  ]

=cut
#################################################################
#
#  dir( image ) - Returns directory entries as an array of
#  structures, in order of appearance in the directory.  The
#  entry structure is as follows:
#  
#  [    'dt,ds'          # directory track and sector (often 0,0)
#       'type'           # file type
#       't,s'            # file starting track and sector
#       'filename'       # filename in PETSCII
#       'filenameASCII'  # filename translated into ASCII
#       'lsu'            # REL length or LSU
#       'date'           # UNIX-style string representation of the date field
#       'year'           # year field, from 1900
#		'month'          # month (1-12)
#		'day'            # month day (1-31)
#		'hour'           # hour (0-23)
#		'minute'         # minute (0-59)
#       'blocks'         # file size in blocks
#       'size'           # file size using LSU, *if available*
#  ]
#
#################################################################
sub dir
{
   my $image    = shift;
   my $track    = shift || -1;
   my $sector   = shift || 0;
   
   return $image->{ 'dir' } if $track == -1;
   return Commodore::Disk::DIR::DIR( $image, $track, $sector );
}

=head2 mkdir( image, dirname [, parentTrack, parentSector] )

Adds a new file with type 0x86, a subdirectory described at baltissen.org.
It is, essentially, just a file with the structure of a directory.
If no parent track/sector is specified, the root directory is used.

Removing this subdirectory requires either:
(1) a subsequent validation of the disk BAM
or
(2) removal of the BAM allocations for files referenced by this subdir.

=cut
sub mkdir
{
   my $image        = shift;
   my $dirname      = shift;
   my $model        = $image->{ 'model' };
   my $parentTrack  = shift || $model->HDR_DIR_track;
   my $parentSector = shift || $model->DIRsectorOffset;
   my ($sec, $min, $hr, $day, $mo, $yr) = localtime;

   #
   #  Allocate one block of data for the subdirectory
   #
   my $subdirLoc = Commodore::Disk::BAM::allocateSectors( $image, 1 );
   return unless @$subdirLoc == 1; # FAIL if no free blocks.

   my ($track, $sector) = @{$subdirLoc->[0]}; # contents: one [t,s]
      
   #
   #  Allocate an entry off the root directory for the subdir.
   #
   my ($rootTrack, $rootSector, $entryIndex) = Commodore::Disk::DIR::allocDirEntry( $image, $dirname );
   
   my $data =
   {
		'type'     => 0x86, # 'DIR',
		't,s'      => [ $track, $sector ],
		'filename' => $dirname,
		'lsu'      => 254,
		'blocks'   => 1,
		'year'     => $yr,
		'month'    => $mo,
		'day'      => $day,
		'hour'     => $hr,
		'minute'   => $min
   };
   
   #print "Writing subdir into rootdir: $track, $sector, $yr, $mo, $day, $hr, $min\n";
   #
   # Write the subdirectory entry into the root directory at the allocated position
   #
   Commodore::Disk::DIR::writeDirEntry( $image, $rootTrack, $rootSector, $entryIndex, $data );

   #
   # Create the subdirectory file and write it to disk.
   # It has one entry: a reference back to the parent directory ** at the parent's starting position **
   #
   my $parentData = 
   {
		'type'     => 0x86, # 'DIR',
		't,s'      => [ $parentTrack, $parentSector ],
		'filename' => '..',
		'lsu'      => 254,
		'blocks'   => 1,
		'year'     => $yr,
		'month'    => $mo,
		'day'      => $day,
		'hour'     => $hr,
		'minute'   => $min
   };	
   
   #print "Writing back-reference into subdir\n";
   #
   # Write the back-reference to the root subdir into the subdirectory
   #
   Commodore::Disk::DIR::writeDirEntry( $image, $track, $sector, 0, $parentData );

   my $imgFile = $image->{ 'filename' };
   save( $image, $imgFile );

   # 
   # Refresh
   #
   $image->{ 'bam' } = Commodore::Disk::BAM::BAM( $image );
   $image->{ 'dir' } = Commodore::Disk::DIR::DIR( $image );

   $debug && Commodore::Util::log( 'Access::mkdir', "Added subdirectory '$dirname' at [$track, $sector]" );
}

=head2 readProgramByFilename( image, filename )

Finds a file by name on the image.

Returns a structure containing the program data from a specified directory index:

  [    'program'       # binary program data in bytes
       'type'          # file type
       'filename'      # file name in PETSCII
       'filenameASCII' # file name translated to ASCII
       'year'          # year (from 1900)
		'month'         # month (1-12)
		'day'           # month day (1-31)
		'hour'          # hour (0-23)
		'minute'        # minute (0-59)
       'blocks'        # file size in blocks
  ]

=cut
#################################################################
#
#  readProgramByFilename - returns a structure 
#  containing the program data from a specified filename:
#
#  [    'program'       # binary program data in bytes
#       'type'          # file type
#       'filename'      # file name in PETSCII
#       'filenameASCII' # file name translated to ASCII
#       'year'          # year (from 1900)
#		'month'         # month (1-12)
#		'day'           # month day (1-31)
#		'hour'          # hour (0-23)
#		'minute'        # minute (0-59)
#       'blocks'        # file size in blocks
#  ]
#
#  Returns undef if file is not found.
#
#################################################################
sub readProgramByFilename
{
   my $image = shift;
   my $filename = shift;
   
   my $index = Commodore::Disk::DIR::findDirEntry( $image, $filename, 0, 0, -1 );
      
   if ( $index > -1 )
   {
      return readProgramByIndex( $image, $index );
   }
   
   return undef;
}

=head2 readProgramByIndex( image, index ) 

Returns a structure containing the program data from a specified directory index:

  [    'program'       # binary program data in bytes
       'type'          # file type
       'filename'      # file name in PETSCII
       'filenameASCII' # file name translated to ASCII
       'year'          # year (from 1900)
   	'month'         # month (1-12)
		'day'           # month day (1-31)
		'hour'          # hour (0-23)
		'minute'        # minute (0-59)
       'blocks'        # file size in blocks
  ]

=cut
#################################################################
#
#  readProgramByIndex( image, index ) - returns a structure 
#  containing the program data from a specified directory 
#  index:
#
#  [    'program'       # binary program data in bytes
#       'type'          # file type
#       'filename'      # file name in PETSCII
#       'filenameASCII' # file name translated to ASCII
#       'year'          # year (from 1900)
#		'month'         # month (1-12)
#		'day'           # month day (1-31)
#		'hour'          # hour (0-23)
#		'minute'        # minute (0-59)
#       'blocks'        # file size in blocks
#  ]
#
#################################################################
sub readProgramByIndex
{
   my $image  = shift;
   my $entry  = shift;
   
   $entry--; # entry is 1 based, but our arrays are 0 based.
   
   my $dir    = $image->{ 'dir' };
   my $prg    = $dir->[ $entry ];

   my ($track,$sector) = @{$dir->[ $entry ]->{ 't,s' }};
   
   my $chainref = Commodore::Disk::Image::readFileChain( $image, $track, $sector  );
   
   my $program;
   
   #print "Chain length: ", scalar @$chainref, " blocks\n";

   foreach my $block (@$chainref)
   {
      my ($t,$s) = unpack( "CC", $$block );
      my $len = 254;
      $len -= $s if $t == 0;

      $program .= substr( $$block, 2, $len );
   }
   
   my ($sec, $min, $hr, $day, $mo, $yr) = localtime;
   unless ( $prg->{ 'year' } )
   {
      $prg->{ 'year'   } = $yr+1900;
      $prg->{ 'month'  } = $mo+1;
      $prg->{ 'day'    } = $day;
      $prg->{ 'hour'   } = $hr;
      $prg->{ 'minute' } = $min;
   }

   return 
   {
      'program' => $program,
      'type'    => $prg->{ 'type' },
      'filename'=> $prg->{ 'filename' },
      'filenameASCII' => $prg->{ 'filenameASCII' },
      'year'    => $prg->{ 'year' },
      'month'   => $prg->{ 'month' },
      'day'     => $prg->{ 'day' },
      'hour'    => $prg->{ 'hour' },
      'minute'  => $prg->{ 'minute' },
      'blocks'  => $prg->{ 'blocks' },
   };
}

=head2 readStoreProgramByIndex( image, index, filename ) 

Extracts a file at a particular index in the directory, and saves it 
to its own file outside of the image.  This is useful for file transfer,
file access/dispatch, and for accessing sprite files (see extractSprites()
to actually extract sprites from a sprite file).

The file's name and extension are based on its actual name, date stamp,
and type; for example, a PRG file names "FOO" with a date stamp of Year=85, 
Month=00, Day=12, Hour=18, and Minute=46 
will be saved as "FOO.8500121846.PRG".  This convention preserves three
important pieces of data which would be otherwise lost.

=cut
#################################################################
#
#  readStoreProgramByIndex( image, index, filename ) - saves the
#  file to disk.  The file's name and extension are based on 
#  its actual name and type.
#      
#################################################################
sub readStoreProgramByIndex
{
   my $program = readProgramByIndex( shift, shift );

   my $outfile = $program->{ 'filenameASCII' };
   my @type    = qw/DEL SEQ PRG USR REL/;
   my $ext     = $type[ $program->{ 'type' } - 0x80 ] if $program->{ 'type' } > 0x80;
   $ext = 'DEL' unless $ext; # default

   my $extension = sprintf( "%04d-%02d-%02d-%02d-%02d",
             $program->{ 'year' },
             $program->{ 'month' },
             $program->{ 'day' },
             $program->{ 'hour' },
             $program->{ 'minute' },
             );

   $outfile =~ s|[\\/ ]|_|g; # convert slashes and white space to underscores, please.   
   $outfile = "$outfile.$extension.$ext";

   open OUT, ">$outfile" || return -1;
   binmode OUT;
   print OUT $program->{ 'program' };
   close OUT;
   print "$outfile created.\n";

   return $program;
}

=head2 writeProgram( image, bytes, name, type, year, month, day, hour, minute ) 

Saves bytes to the image:
     * allocates free sectors from the BAM
     * builds the T/S chain into the allocated blocks
     * breaks the file up into 254-byte chunks
     * writes the data into the allocated blocks.
	 * stores the filetype and timestamp in the directory.
	 
*** NOTE *** Underscores in the filename are converted to space characters.

=cut
#################################################################
#
#  writeProgram( image, program, etc ) - saves the bytes in the program
#  to the image.  Does all the work:
#     * allocates free sectors from the BAM
#     * builds the T/S chain into the allocated blocks
#     * breaks the file up into 254-byte chunks
#     * writes the data into the allocated blocks.
#
#################################################################
sub writeProgram
{
   my $image   = shift;
   my $program = shift;
   my $name    = shift;
   my $type    = shift || 'PRG';
   my $year    = shift;
   my $month   = shift;
   my $day     = shift;
   my $hour    = shift;
   my $minute  = shift;
   my $sec;
   
   unless ($year)
   {
      ($sec, $minute, $hour, $day, $month, $year) = localtime;
   }
   #
   # Massage name.
   #
   $name =~ s/_/ /g; # underscores to whitespace
   $name .= pack( 'C', 0xa0 ) while length $name < 16;
   
   #
   # Find or allocate a directory entry
   #
   my ($track, $sector, $entryIndex) = Commodore::Disk::DIR::allocDirEntry( $image, $name );
   if ( $track == -1 )
   {
      return; # error
   }
   $debug && Commodore::Util::log( 'Access::writeProgram', "DIR entry $entryIndex (\"$name\", type $type) allocated" );

   #
   # Split up file into array of 254-byte blocks
   #
   my $blockref = Commodore::Disk::Image::createFileChain( $program );
   my $blocks   = scalar @$blockref;
   my $lsu      = length $blockref->[-1]; # last block
   $debug && Commodore::Util::log( 'Access::writeProgram', "Blocks=$blocks, LSU=$lsu" );
      
   #
   # Allocate free sectors from the BAM (and mark them)
   #
   my $sectorref = Commodore::Disk::BAM::allocateSectors( $image, $blocks );
    
   if ( $sectorref == 0 ) # error
   {
      print "Access::writeProgram() ERROR - cannot allocate sectors\n";
	  return;
   }
   $debug && Commodore::Util::log( 'Access::writeProgram', "BAM sectors allocated" );
      
   my $model = $image->{ 'model' };
   
   my $tsref = shift @$sectorref;
   my ($startTrack, $startSector) = @$tsref;
   my ($t, $s) = ($startTrack, $startSector);
   
   $debug && Commodore::Util::log( 'Access::writeProgram', "Start location: [$t,$s]" );
   
   #	
   # Assign T,S *CHAIN* to blocks and write.
   #   
   foreach my $block (@$blockref)
   {	  
      my ($oldT,$oldS) = ($t,$s);
      #print "$t, $s -> ";
      my $offset = 0x100 * $model->getSectorOffset( $t, $s );

	  #
	  #  Write "Next T", "Next S" chain
	  #
      my $next = shift @$sectorref;
	  ($t, $s) = (0, length( $block ) );
	  ($t, $s) = @$next if $next;

      #print "$t, $s\n";
	  
	  my $data = pack( 'CC', $t, $s ) . $block;
	  my $length = length $data;
	  
	  $debug && Commodore::Util::log( 'Access::writeProgram', "[$oldT,$oldS] $length bytes, link=[$t,$s]" );
	  Commodore::Disk::Image::writeBytes( $image, $offset, \$data );	  
   }   

   #
   # Figure out remaining data
   #
   $type = 0x80 if $type eq 'DEL';
   $type = 0x81 if $type eq 'SEQ';
   $type = 0x82 if $type eq 'PRG';
   $type = 0x83 if $type eq 'USR';
   $type = 0x84 if $type eq 'REL';
   $type = 0x85 if $type eq 'CBM';
   $type = 0x86 if $type eq 'DIR'; # Ruud's suggestion

   #
   # Write entry in directory
   #
   my $data = 
   {
	  'type'     => $type,
      't,s'      => [$startTrack, $startSector],
	  'filename' => $name,
	  'lsu'      => $lsu,
	  'year'     => $year,
	  'month'    => $month,
	  'day'      => $day,
	  'hour'     => $hour,
	  'minute'   => $minute,
	  'blocks'   => $blocks
   };
   
   Commodore::Disk::DIR::writeDirEntry( $image, $track, $sector, $entryIndex, $data );
   
   return ($startTrack, $startSector, $data);
}

=head2 writeProgramFromFile( image, filename )

Saves the bytes in the program contained in the file to the image.
NOTE: the filename MUST be of the form "<filename>.YYMMDDHHmm.<file type>",
where "file type" is one of DEL|SEQ|PRG|USR|REL, and YYMMDDHHmm is a SERIES OF HEX VALUES
for year, month, day, hour, and minute.

=cut
#################################################################
#
#  writeProgramFromFile( image, filename ) - saves the bytes in 
#  the program contained in the file to the image.
#
#################################################################
sub writeProgramFromFile
{
   my $image = shift;
   my $filename = uc shift;
   my ($name, $yr, $mo, $da, $hr, $mi, $type) = $filename =~ /^(.*?)\.(.+)-(..)-(..)-(..)-(..)\.(.*)$/;
   $yr -= 1900;
   $mo--;

   unless(defined($type))
   {
      ($name, $type) = $filename =~ /^(.*?)\.(DEL|SEQ|PRG|USR|REL)$/;
      my $sec;
      
      ($sec, $mi, $hr, $da, $mo, $yr) = localtime(time);
   }

   unless(defined($type))
   {
      print "ERROR: the filename MUST be of the form <filename>.YY-MM-DD-HH-mm.<file type>\n";
      print "       or <filename>.<file type>\n";
      print "       where <file type> is one of DEL|SEQ|PRG|USR|REL, and YY-MM-DD-HH-mm are values for\n";
      print "       year, month, day, hour, and minute.\n";
      die;
   }

   $debug && Commodore::Util::log( 'Access::writeProgramFromFile', "Injecting $type: $name, date: $yr-$mo-$da $hr:$mi\n" );
   
   $/ = undef; # slurp
   open IN, $filename || return -1;
   binmode IN;
   my $program = <IN>;
   close IN;
   
   writeProgram( $image, $program, $name, $type, $yr, $mo, $da, $hr, $mi );
}

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk::Access


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

1; # End of Commodore::Disk::Access
