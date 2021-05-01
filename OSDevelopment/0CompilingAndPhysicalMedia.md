# Compiling code and installation to floppy disk  

A short guide on compiling the tutorials and optionally installing to a floppy disk. Alternatively the compiled code could be installed to an image and used with an emulator or converted for use with a CDROM or other device.  

## Requirements  
- NASM  
- Builtin DOS debug command (Windows)  
- Builtin dd command (Linux)  

The NASM assembly compiler can be downloaded for free from their [website](https://www.nasm.us/). The other tools for copying the file to the drive are usually preinstalled.  

*Other assembly compilers are availble, NASM is used by my examples but you may come across alternatives with slightly different commands and syntax.*  

## Compiling  
Compiling the assembly files with NASM is relatively easy. Simply type nasm followed by the filename. This will create a binary file without the extension which can be copied onto a physical disk or a disk image.  

>nasm <filename>.asm  

**Check file sizes:**  
The (first) bootloader file should be exactly 512 bytes. It is advisable to check this is the case before spending time copying the file to a physical drive. This can be easily done using builtin file listing utilities on both Windows and Linux.  

>dir (Windows)  
>ls -l (Linux)  

## Copying to floppy disk  

***WARNING: Defining the wrong drive with these commands can cause you to lose data.*** If you are at all unsure of what you are doing please ensure you have a complete backup of all your data and that you are able to reinstall your daily operating system before you continue.  

**Linux:**  
> dd if=BootloaderFile bs=512 of=/dev/fd0  
> dd if=BootloaderFilePart2 bs=512 seek=1 of=/dev/fd0  

The dd command requires the input file to be specified (if) the block, or sector, size which is 512 bytes for a floppy disk and an output location (of) which usually starts with /dev/.  

*On your system the floppy drive may not be located at /dev/fd0. Make sure to confirm the device location using other tools before using this command. The device location is not the same as the mount point.*  

This example shows the procedure to copy two files and the use of the seek option to skip a sector. If you only have the first 512 byte bootloader file you can ignore the second line.  

**Windows:**  
> debug BootloaderFile  
> w 100 0 0 1  
> q  

>debug BootloaderFilePart2  
>w 100 0 1 1  
>q  

The write command (w) uses takes the following arguments:  
<address> <drive> <firstsector> <number>  
- Address: Debug loads the file starting at position 100 by default.  
- Drive: 0='A', 1='B', 2='c'...  
- FirstSector: Where to start writing to disk  
- Number: How many sectors to write (for larger files this may need increasing)  

Further information available from [Microsoft Documentation](https://docs.microsoft.com/en-us/previous-versions/tn-archive/cc722863(v=technet.10)  

These instructions are to copy two files each of 512 bytes one after the other. Depending on the number of files and there size you may need to adjust (or omit) the second set of instructions.  

*Ensure you are writing to the correct drive and that this drive is blank, or contains no files you may later need.*  
