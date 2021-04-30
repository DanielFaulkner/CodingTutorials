## A small disk sector addressing converter for illustrating, and testing LBA to CHS conversions and vice versa.
##
## Written by Daniel R Faulkner

## Disk addressing converter

# Drive variables:
SectorsPerTrack = 18	# Number of sectors per track (for a standard floppy disk set to 18)
HeadsPerCylinder = 2	# Number of tracks per cylinder location (for a standard floppy disk set to 2)

# Note in python '//' = quotient and '%' = remainder or modulus.

# LBA to CHS
def LBAtoCHS(LBA):
	"""Converts a logical disk address (LBA) into the physical (CHS) address. Returns 3 values: Cylinder, Head and Sector."""

	### Cylinder
	# Each head can read (SectorsPerTrack) sectors before needing the cylinder to move.
	# Therefore every (Number Of Heads * Sectors Per Track) sectors the cylinder needs to move.
	Cylinder = LBA // (HeadsPerCylinder * SectorsPerTrack)

	### Head
	# Calculates the number of tracks (total) into the disk the position is then divides by the number of heads and takes the remainder.
	Head = (LBA // SectorsPerTrack) % HeadsPerCylinder

	### Sector
	# Divides the logical number by the number of sectors in a track. The remainder(+1) indicates how many sectors into a cylinder we are.
	Sector = (LBA % SectorsPerTrack) + 1

	### Alternative formulas to achieve the same result
	# These alternative formulas first calculate the sector position in the cylinder (across all heads, ie. for a floppy between 1-36).
	# Sector alternative formula, taking the above and dividing by the number of sectors per track +1 (remainder)
	#Sector = (LBA % (HeadsPerCylinder * SectorsPerTrack)) % SectorsPerTrack + 1

	# Head alternative formula, taking the above and then dividing by the number of sectors per track (quotient)
	#Head = (LBA % (HeadsPerCylinder * SectorsPerTrack)) // SectorsPerTrack

	return Cylinder, Head, Sector


# CHS to LBA
def CHStoLBA(Cylinder,Head,Sector):
	"""Converts a physical (CHS) address into a logical disk address (LBA)."""

	### LBA conversion
	# For every cylinder position add the number of sectors per track multiplied by the number of tracks (indicated by the number of heads) per cylinder
	# For every head (track) multiply this by the number of sectors per track
	# For every sector add the number of sectors (-1)
	LBA = (((Cylinder*HeadsPerCylinder)+Head)*SectorsPerTrack)+(Sector-1)

	# Alternative (expanded) version, present for readability reasons:
	#LBA = (Cylinder*HeadsPerCylinder*SectorsPerTrack)+(Head*SectorsPerTrack)+(Sector-1)

	return LBA

# Run this test loop if this python file is run instead of imported
if __name__ == "__main__":
	# Loop from 1 to 1000 testing the conversion to a physical address and back to a logical address
	for i in range(1,1000):
		print(LBAtoCHS(i))
		C, H, S = LBAtoCHS(i)
		print(CHStoLBA(C,H,S))
