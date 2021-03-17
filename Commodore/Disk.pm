package Commodore::Disk;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Image;
use Commodore::Disk::Access;

=head1 NAME

Commodore::Disk - Commodore disk image reader.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my %data;

=head1 SYNOPSIS

This file contains methods needed for reading to and writing from Commodore disk image files.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new instance.

=cut

sub new 
{ 
	my $type = shift;
	my $self = {};
	bless $self, $type;
}

=head2 $self->create( filename, label, ID )

Convenience method. Creates a new disk image.

=head2 $self->load( filename )

Convenience method. Loads an image from a file.

=head2 $self->save( filename ) 

Convenience method. Saves the image to its file.

=cut
#################################################################
#
#  create( filename, label, ID ) - Creates a new disk image
#  load( filename ) - Loads (and returns) an image from a file.
#  save( filename ) - Saves an image to a file.
#
#################################################################
sub create 
{ 
    my $self = shift;
	$data{$self} = Commodore::Disk::Image::createImage( @_ ); 
}

sub load 
{ 
    my $self = shift;
	$data{$self} = Commodore::Disk::Image::loadImage( @_ );   
}

sub save   
{ 
	my $self = shift;
	$data{+$self} = Commodore::Disk::Image::saveImage( $self, @_ );   
}

=head2 $self->createCustomImage

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
sub createCustomImage 
{
   $data{+shift} = Commodore::Disk::Image::createCustomImage( @_ );
}

=head2 $self->summary

Returns a string containing an image's header listing, BAM listing, and directory listing.

=cut
sub summary { return Commodore::Disk::Access::summary( $data{ +shift } ); }

=head2 $self->hdr

Convenience method. Returns a structure containing header data:
  {
     'dosType':     <dos type>    e.g. '2A'
     'diskLabel':   <label>       e.g. 'MYDISKáááááááááá'
     'diskLabelASCII': <label>    e.g. 'MYDISK'
     'diskId':      <ID>          e.g. 'AA'
  }

=cut
sub hdr { return Commodore::Disk::Access::hdr( $data{ +shift } ); }

=head2 $self->setLabel( label, ID, dosType )

Convenience method. Sets header data.

=cut
sub setLabel { return Commodore::Disk::Access::setLabel( $data{ +shift }, @_ ); }

=head2 $self->getLabel

Convenience method.  Returns the disk header label in ASCII.

=cut
sub getLabel { return Commodore::Disk::Access::getLabel( $data{ +shift } ) }

=head2 $self->bam

Convenience method.  Returns an array of BAM data:
    Each element corresponds to a track, and contains the
    track number, the Free Sector Count (FSC), and a
    sub-array of sector allocations.

=cut
sub bam { return Commodore::Disk::Access::bam( $data{+shift} ) }

=head2 blocksTotal

Calculates and returns the total number of blocks in the image.

=cut
sub blocksTotal { return Commodore::Disk::Access::blocksTotal( $data{+shift} ) }

=head2 blocksFree

Calculates and returns the number of free blocks in the image.

=cut
sub blocksFree { return Commodore::Disk::Access::blocksFree( $data{+shift} ) }

=head2 dir( [track [, sector]] ) 

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
sub dir { return Commodore::Disk::Access::dir( $data{+shift}, @_ ) }


=head2 $self->mkdir( dirname [, parentTrack, parentSector] )

Adds a new file with type 0x86, a subdirectory described at baltissen.org.
It is, essentially, just a file with the structure of a directory.
If no parent track/sector is specified, the root directory is used.

=cut
sub mkdir { return Commodore::Disk::Access::mkdir( $data{ +shift }, @_ ) }

=head2 $self->readProgramByFilename( filename )

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
sub readProgramByFilename { return Commodore::Disk::Access::readProgramByFilename( $data{+shift}, @_ ) }

=head2 $self->readProgramByIndex( index ) 

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
sub readProgramByIndex { return Commodore::Disk::Access::readProgramByFilename( $data{+shift}, @_ ) }

=head2 $self->readStoreProgramByIndex( index, filename ) 

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
sub readStoreProgramByIndex { return Commodore::Disk::Access::readStoreProgramByIndex( $data{+shift}, @_ ) }

=head2 $self->writeProgram( bytes, name, type, year, month, day, hour, minute ) 

Saves bytes to the image:
     * allocates free sectors from the BAM
     * builds the T/S chain into the allocated blocks
     * breaks the file up into 254-byte chunks
     * writes the data into the allocated blocks.
	 * stores the filetype and timestamp in the directory.
	 
*** NOTE *** Underscores in the filename are converted to space characters.

=cut
sub writeProgram { return Commodore::Disk::Access::writeProgram( $data{+shift}, @_ ) }

=head2 $self->writeProgramFromFile( filename )

Saves the bytes in the program contained in the file to the image.
NOTE: the filename MUST be of the form "<filename>.YYMMDDHHmm.<file type>",
where "file type" is one of DEL|SEQ|PRG|USR|REL, and YYMMDDHHmm is a date stamp.

=cut
sub writeProgramFromFile { return Commodore::Disk::Access::writeProgramFromFile( $data{+shift}, @_ ) }

=head2 $self->readBlock( track, sector )

Returns a single blockref at the given location.

=cut
sub readBlock { return Commodore::Disk::Image::readBlock( $data{+shift}, @_ ) }

=head2 $self->writeBlock( blockref, track, sector )

Writes a single block to the given location.

=cut
sub writeBlock { return Commodore::Disk::Image::writeBlock( $data{+shift}, @_ ) }

=head2 $self->model

Returns the structural disk model backing this image.

=cut
sub model { return $data{+shift}->{'model'} }

=head2 $self->image

Returns the raw image data.

=cut
sub image { return $data{+shift}->{'data'} }

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Disk


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

1; # End of Commodore::Disk
