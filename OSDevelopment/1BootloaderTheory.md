# Bootloader overall theory

The BIOS (Basic Input Output System) of your computer loads the first 512 bytes from a disk and executes this when starting the computer, providing it ends with a bootloader signature. Because it would be impossible to write a complete operating system within such a small file this first 512 bytes (historically the first sector of a disk) contains the code to execute either the operating system kernel directly or will load an intermediate stage to execute the kernel.  

A functional bootloaders usually performs the basic actions given below to prepare, load and execute a kernel.

**Essential actions:**  
Set up the segment registers  
Set up the stack  
Print Message procedure  

**Almost essential actions:**  
Load sectors from a disk/secondary storage device.  
	- CHS (Essential)  
	- LBA (Important if you plan to load more than a few sectors)  
(Setup the segment registers to the loaded location recommended)  
Transfer control to the kernel/loaded sectors.  

**Common actions:**  
Protected Mode  
File System  
	- FAT12 is commonly used on floppy drives  
	- FAT16 is commonly used on small hard drives  
	- FAT32 is commonly used on larger hard drives  
	- Ext2 is commonly used all so.  
	- Or you can make your own or use a less common file system.  

These actions are discussed in the following tutorials in greater depth.

*This is not a complete list and only provided as a starting point.*

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
