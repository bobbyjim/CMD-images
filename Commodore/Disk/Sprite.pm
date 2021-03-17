package Commodore::Disk::Sprite;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Commodore::Disk::Access;

=head1 NAME

Commodore::Disk::Sprite - Methods for accessing sprite files in Commodore disk images.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my  $debug   = 1;

=head1 SYNOPSIS

Methods for extracting sprites from sprite files.

my $bytes   = Commodore::Disk::Sprite::readFileBytes( 'mydisk.d64', 'MYSPRITEFILE' );
my $pbm_ref = Commodore::Disk::Sprite::extractSpritesToPBM( $bytes );

foreach (@$pbm_ref) # dump PBM text to stdout for visual inspection
{
   print;
}

=head1 SUBROUTINES/METHODS

=head2 readFileBytes( imageName, fileName )

Convenience function.  Reads a file from the image named by
the indicated disk image and returns its data bytes, suitable for sending 
to one of the sprite extraction methods.

If you want metadata about the file, call this method instead:
Commodore::Disk::Access::readProgramByFilename().

=cut
#################################################################
#
#  readFileBytes( imageName, fileName ) - returns file byte data.
#
#################################################################
sub readFileBytes
{
   my $imageName = shift;
   my $fileName = shift;

   my $image   = Commodore::Disk::Access::load( $imageName );   
   my $fileref = Commodore::Disk::Access::readProgramByFilename( $image, $fileName );
   
   return undef unless $fileref;
   
   my $bytes = $fileref->{ 'program' };
   
   return \$bytes;
}
   
=head2 extractSprites( byteref )

Takes an arraryref of bytes and returns an array of 63-byte sprite data objects.

=cut
#################################################################
#
#  extractSprites( byteref ) - takes a sprite file and returns
#  an array of 63-byte sprite data objects.
#
#################################################################
sub extractSprites
{
   my $byteref = shift;
   my $buffer  = $$byteref;

   #my ($j1, $j2, @rest) = unpack( "CCC*", $buffer ); # block
   my @rest = unpack( "C*", $buffer );
   
   exit;
   
   my @sprites = ();

   while (@rest) #for (1..1)
   { 
      my @sprite = ();
      for (1..21)
      {
         my $a = shift @rest;
         my $b = shift @rest;
         my $c = shift @rest;
   
         push @sprite, [ $a, $b, $c ];
#		    sprintf "%08b %08b %08b", $a, $b, $c;
      }
	  push @sprites, \@sprite;
      shift @rest; # 64th byte
   }
   return \@sprites;
}

=head2 extractSpritesToPBM( byetref )

Takes a sprite file and returns an array of PBM image strings.

NOTE: compared with today, commodore sprites are absolutely tiny.
We're talking 24 x 21 pixels.  Just so you know.

=cut
#################################################################
#
#  extractSpritesToPBM
#
#################################################################
sub extractSpritesToPBM
{
   my $byteref = shift || return undef;
   my $buffer  = $$byteref;
#   my ($j1, $j2, @rest) = unpack( "CCC*", $buffer );
   my (@rest) = unpack( "C*", $buffer );
 
   $debug && Commodore::Util::log( "Sprite::extractSprites", "bytes=" . scalar @rest );
 
   my @sprites = '';
   while (@rest)
   {
      my $sprite = "P1\n24 21\n"; # PBM header: 24 x 21 pixels
      for (1..21)
      {
         my $a = shift @rest;
         my $b = shift @rest;
         my $c = shift @rest;
   
         $sprite .= sprintf "%08b %08b %08b ", $a, $b, $c;
		 $sprite .= "\n";
      }
      shift @rest; # 64th byte
	  
	  $sprite .= "\n\n";
	  push @sprites, $sprite;
   }
   
   return \@sprites;
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
