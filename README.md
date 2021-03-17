# CMD-images
A generic engine for manipulating Commodore-style disk images, and a set 
of specific parameter classes for accessing specific types.

# Scripts
There are utility scripts to list the contents of disk images, the BAM, 
the Header, to inject and extract files, create disk images, and so on.

Some test images are included, with some files injected.

# Formats Handled
- 1541 (D64)
- 1571 (D71) (read only, I think)
- 1581 (D81)
- 2040 (D67)
- 8050 (D80)
- 8250 (D82)

I have classes for the 9030, 9060, and 9090 series, but I don't think they work right.

There is also a way to create a non-standard image container format.
This is stored in an X64 file.  Some of the unused bytes in the X64 header
are re-purposed to store the image's structure so that it can be parsed.

# Image Parameters
Most (all?) Commodore disk images define their structure from these parameters:

* (16 chars) Label
* (2 chars) ID
* (2 chars) DOS Type
* (1 byte) Header Track number
* (1 byte) Header Label offset (in bytes)
* (1 byte) Directory sector interleave
* (1 byte) File sector interleave
* (1 byte) BAM label offset (in bytes)
* (2 bytes) Zone 1 high track and sectors per track
* (2 bytes) Zone 2 high track and sectors per track
* (2 bytes) Zone 3 high track and sectors per track
* (2 bytes) Zone 4 high track and sectors per track
* (1 byte) BAM sector interleave
* (1 byte) BAM (re)location flag
* (1 byte) BAM sector count
* (1 byte) Tracks per BAM sector
* (1 byte) Boot track #

Some of these fields aren't even a full byte.  But that's okay, the structure
above is theoretically **only 38 bytes**.

The general solution, then, is to design an ENGINE and separate it from
the PARAMETERS.

