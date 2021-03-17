package Commodore::Util;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Commodore::Util - Utility methods used by Commodore:: packages.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
my $debug = 1;

=head1 SYNOPSIS

Utility functions used by Commodore:: packages.

=head1 SUBROUTINES/METHODS

=head2 log( package, message )

Prints a very simple log message.

=head2 warn( package, message )

Prints a very simple warning message.

=head2 err( package, message )

Prints a very simple error message.

=cut
###############################################################
#
#  msg( severity, package, msg ) - print a message
#
###############################################################
sub msg
{
   my $svr = shift;
   my $pkg = shift;
   my $msg = shift;
   my ($s,$m,$h,$d,$mon,$yr,$wday) = localtime;
   my @day = qw/Sun Mon Tue Wed Thu Fri Sat/;
   my $day = $day[$wday];
   
   $yr %= 100;
   $mon++;
   # 2013-02-08 Fri 
   #printf "[%02d%02d%02d %02d%02d%02d $day]   $pkg: $msg\n", $yr, $mon, $d, $h, $m, $s;
   printf "%02d:%02d:%02d %-6s %-25s: $msg\n", $h, $m, $s, $svr, $pkg;
}

sub log  { msg( 'LOG',     @_ ) }
sub warn { msg( 'WARNING', @_ ) }
sub err  { msg( 'ERROR',   @_ ) }

=head2 a0to32

Translates PETSCII $A0 and $00 to ASCII space ($20).

=cut
###############################################################
#
#  Translates PETSCII $A0 and $00 to ASCII space.
#
###############################################################
sub a0to32
{
   my $string = shift || '';
   $string =~ s/\xa0/ /g;
   $string =~ s/\x00/ /g;
   $string =~ s/\s+$//;
   return $string;
}

=head2 toA0

Translates ASCII space to PETSCII $A0.

=cut
###############################################################
#
#  Translates ASCII space to PETSCII $A0.
#
###############################################################
sub toA0
{
   my $string = shift || '';
   my $len    = shift || 16;

   $string =~ s/ /\xa0/g;
   $debug && msg( 'LOG', 'Util::toA0', "string=[$string]" );

   $string .= pack( 'C', 0xa0 ) until length $string == $len;;
   $debug && msg( 'LOG', 'Util::toA0', "string=[$string]" );

   return $string;
}

=head2 padA0

Pads a string with $A0 to the specified length.

=cut
###############################################################
#
#  Pads a string with $A0 to the specified length.\
#
###############################################################
sub padA0
{
   my $string = shift || '';
   my $len    = shift || 16;

   $string .= pack( 'C', 0xa0 ) until length $string == $len;;
   $debug && msg( 'LOG', 'Util::toA0', "string=[$string]" );

   return $string;
}

=head2 basicdump( data )

Dumps a block of BASIC.

=cut
###############################################################
#
#  Returns a stringref of data bytes as a hex dump.
#
###############################################################
sub basicdump
{
   my $text = '';

   foreach my $block (@_)
   {
      my @block = unpack( "C*", $block );
      my %tokens = 
      (
         0x83 => 'data',
         0x8f => 'rem',
         0x97 => 'poke',
         0x99 => 'print',
         128  => 'end',
         129  => 'for',
         130  => 'next',
         132  => 'input#',
         133  => 'get',
 #       133  => 'input', ??
         134  => 'dim',
         135  => 'read',
         137  => 'goto',
         138  => 'run',
         139  => 'if',
         140  => 'restore',
         141  => 'gosub',
         142  => 'return',
         145  => 'on',
         147  => 'load',
         148  => 'save',
  #      149  => 'val',    ??
  #      149  => 'verify', ??
         150  => 'def',
         152  => 'print#',
         157  => 'cmd',
         158  => 'sys',
         159  => 'open',
         160  => 'close',
         164  => 'to',
         165  => 'fn',
         167  => 'then',
         169  => 'step',
         170  => '+',
         171  => '-',
         172  => '*',
         173  => '/',
         175  => 'and',
         176  => 'or',
         177  => '>',
         178  => '=',
         181  => 'int',
         182  => 'abs',
         184  => 'fre',
         186  => 'spc',
         187  => 'rnd',
         190  => 'cos',
         191  => 'sin',
         192  => 'tab',
 #            => 'peek', ??
         194  => 'poke',
         195  => 'len',
         196  => 'str$',
         198  => 'asc',
         199  => 'chr$',
         200  => 'left$',
         201  => 'right$',
         202  => 'mid$',
 #            => 'tan', ??
 #            => 'sqr', ??
 #            => 'list', ??
      ); 

      my $length = 0;
      my $linehi = 0;
      my $linelo = 0;
      my $whatever = 0;

      foreach (@block)
      {
         if ( $_ > 31 && $_ < 96 )
         {
            $text .= chr( $_ );
         }
         elsif ( $_ == 0x00 ) # statement terminator
         {
            $text .= "\n";
            # capture the next four bytes!
            $length = shift @block;
            $linehi = shift @block;
            $linelo = shift @block;
            $whatever = shift @block;
            $text .= sprintf "%03d %03d %03d %03d ", $length, $linehi, $linelo, $whatever;
         }
         else
         {
            $text .= $tokens{ $_ } || "<$_>";
         }
      }
   }

   return $text;
}

=head2 hexdump( data )

Dumps a block of data in hex.

=cut
###############################################################
#
#  Returns a stringref of data bytes as a hex dump.
#
###############################################################
sub hexdump
{
   my @text;
   my $text = '';

   foreach my $block (@_)
   {
      my @block = unpack( "C*", $block );

      my $i = 0;
   
      foreach (@block)
      {
         if ( $i % 256 == 0 )
	 {
	    push @text, "\n";
            push @text, "       0  1  2  3   4  5  6  7   8  9  a  b   c  d  e  f  Text\n";
            push @text, "      -- -- -- --  -- -- -- --  -- -- -- --  -- -- -- --  ----------------\n";
	 }
   
         push @text, sprintf("%04x: ", $i) if $i % 16 == 0;
         push @text, sprintf "%02x ", $_;
         ++$i;

         $text .= chr( $_ ) if $_ > 31 && $_ < 127;
         $text .= '.'       if $_ < 32 || $_ > 126;

	 push @text, ' '         if $i % 4 == 0;
         push @text, "$text\n"   if $i % 16 == 0;
         $text = ''              if $i % 16 == 0;
      }
      # if there is text left in the buffer, print it
      if ( $text ne '' )
      {
         # pad based on how many hex digits are missing
         push @text, '   ' x (16 - length( $text ));
         push @text, " $text";
      }
      push @text, "\n";
   }
   
   my $out = join "", @text;

   return $out;
}

sub hexdump1
{
   my $ref = hexdump( @_ );
   return $$ref;
}

=head1 AUTHOR

Robert Eaglestone, C<< <robert.eaglestone at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-commodore-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Commodore-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Commodore::Util


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

1; # End of Commodore::Util
