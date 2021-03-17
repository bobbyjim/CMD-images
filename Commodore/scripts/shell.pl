# Purpose: Wraps Commodore functions in a REPL.

my %registry = menu();

{
   prompt();
   my $in = <STDIN>;  
   chomp $in;
   exit if $in =~ /^exit|bye$/;

   print "?\n" unless $registry{ $in };
   redo unless $registry{ $in };
   
   print `$in.pl`;
   
   redo;
}

sub prompt
{
   print "64> ";
}

sub menu
{
   foreach my $file (sort {$a cmp $b} <*.pl>)
   {
      open IN, $file;
	  my ($purpose) = grep( /purpose/i, <IN> );
	  close IN;
	  
	  chomp $purpose;
	  $purpose = '' unless $purpose;
	  $purpose =~ s/^.*purpose: //i;
	  
	  $file =~ s/\.pl$//;
	  
      printf '%20s : %s', $file, $purpose;
	  print "\n";
	  
	  $registry{ $file } = $purpose;
   }
   
   return %registry;
}
