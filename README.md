# CMD-images
Code for manipulating Commodore-style disk images.

# Scripts
There are utility scripts to list the contents of disk images, the BAM, 
the Header, to inject and extract files, create disk images, and so on.

# Formats Handled
1541 (D64)
1571 (D71) (read only, I think)
1581 (D81)
2040 (D67)
8050 (D80)
8250 (D82)

I have classes for the 9030, 9060, and 9090 series, but I don't think they work right.

There is also a way to create a non-standard image container format.
This is stored in an X64 file.  Some of the unused bytes in the X64 header
are re-purposed to store the image's structure so that it can be parsed.

# Image Parameters
Most (all?) Commodore disk images define their structure from these parameters:

filename
Label
ID
DOS Type
Header Track number
Header Label offset (in bytes)
Directory sector interleave
File sector interleave
BAM label offset (in bytes)
Zone 1 high track and sectors per track
Zone 2 high track and sectors per track
Zone 3 high track and sectors per track
Zone 4 high track and sectors per track
BAM sector interleave
BAM (re)location flag
BAM sector count
Tracks per BAM sector
Boot track #

Most of the above are literally individual bytes of data.  
The general solution, then, is to design an ENGINE and separate it from
the PARAMETERS.

