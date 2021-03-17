#!/usr/bin/perl
use Commodore::Disk::Mount;
use Commodore::Disk::Access;
use Commodore::Disk::Image;
use Commodore::Util;
################################################################
#
#  Purpose: Hexdump a Block (T,S) or entire file.
#
################################################################
my $track  = shift or die "SYNOPSIS: $0 <track> <sector> [device]\n";
dumpFile( $track ) unless $track =~ /^\d+$/;

my $sector = shift || 0;
my $device = shift || 8;
my $image  = Commodore::Disk::Mount::mount( $device );
my $block  = Commodore::Disk::Image::readBlock( $image, $track, $sector );
my $label  = Commodore::Disk::Access::getLabel( $image );
my $type   = $image->{ 'model' }->format;

print '%' x 74, "\n";
print "%\n";
print "%  ($type) Diskette Image $label, Track $track, Sector $sector\n";
print "%\n";
print '%' x 74, "\n";
print Commodore::Util::hexdump( $$block );


################################################################
#
#  My mistake - dump a file directly.
#
################################################################
sub dumpFile
{
   my $file = shift || die "SYNOPSIS: $0 <track> <sector> [device]\n";
   $/ = undef;
   open IN, $file;
   binmode IN;
   my $dat = <IN>;
   close IN;

   print '%' x 74, "\n";
   print "%\n";
   print "%  $file\n";
   print "%\n";
   print '%' x 74, "\n";
   print Commodore::Util::hexdump( $dat );
   
   exit;
}
