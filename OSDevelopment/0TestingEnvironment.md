# OS Image installation and testing

*NOTE: This tutorial assumes a Linux environment.*

## Introduction
One of the first tasks when developing your own Operating System is to establish a testing procedure which, at a minimum, should involve running the code to see the results. Ideally this should also contain some more detailed debugging tools. But as we are starting from the basics with this tutorial set I will just cover, in brief, how to create and run your own image file.

When first running through these steps it is often beneficial to use a known good Operating System image to ensure any difficulties are from the test environment and not the image file. Therefore you may want to start from the emulator section and then return to the topic of image creation.  

## Creating an image
Here I will cover how to create a floppy disk image, but the procedure is similar for other formats.  

**Generating an empty image file:**  
dd bs=512 count=2880 if=/dev/zero of=floppy.img  

This command instructs the dd utility to create 2880 blocks of 512 bytes and store this in floppy.img. Each block consists entirely of zeros and should come to 1.44Mb in total.  

**Install a bootloader:**  
dd if=bootloaderStage1 bs=512 of=floppy.img conv=notrunc  
*Optionally:*  
dd if=bootloaderStage2 bs=512 seek=1 of=floppy.img conv=notrunc  

These commands copy into the image a previously compiled bootloader. The conv=notrunc argument ensures this overwrites the zeros within the existing image instead of creating a new file.  

Because only the first 512bytes of a disk (or image) is read by the BIOS when booting it is common for bootloaders to be divided into two parts. If this is the case with your bootloader then the second part of the bootloader should be copied into the image using the seek=1 option to move 1 block into the image.  

*NOTE: On smaller hobby Operating Systems without a file system the second stage bootloader may be replaced with the kernel.*  

**Install a kernel:**
mkdir Temp  
sudo mount -o loop floppy.img Temp  
sudo cp kernel.com Temp  
sudo umount Temp  

If the operating system uses a file system you may need to mount the image as a disk to copy the kernel and any supporting files across. This can be done by mounting the image to a pre-existing location, or creating a new folder temporarily for this task. Following this the kernel can be copied using a file copy command. Here sudo is used to elevate the privileges of the user, depending on your setup this may not be required.  

*NOTE: Don't assume an image doesn't have a file system just because you haven't formatted it. Sometimes the required data to create a filesystem is included in larger bootloaders.*  

## Installing an emulator  
Various emulators can be used for this purpose. QEMU and Bochs are two popular options. Here I will discuss setting up Bochs. But any emulator capable of booting from a floppy image file should be compatible.  

Bochs is included in many Linux distributions and just requires the installation of the bochs, and possibly bochs-x packages. For other operating systems Bochs can be downloaded from their [website](https://bochs.sourceforge.io/).  

After installation create a file called bochsrc in the same location as your image file and copy into this file the following lines:  
floppya: 1_44=floppy.img, status=inserted  
boot: a  
log: bochsout.txt  

*NOTE: Ensure you change floppy.img to your image name if you are using a different filename.*

Then to start the emulator, ensuring your terminal is within the folder location containing the configuration file and disk image, type:
bochs

**IMPORTANT: Bochs starts emulation in a paused state- press 'c' to start loading your image file.**

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
