# The FAT12 filesystem (readonly)  
A guide to writing a minimalistic FAT12 driver for the purpose of loading and executing a kernel file from within the bootloader. FAT16 filesystems follow a similar process and is discussed in this guide, but without examples. The driver could also become the base for creating a FAT12/16 kernel driver.  

# REWRITE AND CONVERSION TO MARKDOWN SYNTAX IN PROGRESS  

## Contents

This tutorial will cover the information in the order that you need to access the tables. This allows you to create functional code to test each stage before moving onto the next section.  
- Introduction
- **Creating a FAT12 compatible disk:** Howto ensure the disk is recognised as a FAT12 disk, allowing files to be loaded onto the disk by other operating systems. Describes the boot sector parameters table.  
- **Looking up a filename:** Querying the root directory table to get information on file.  
- **Loading a file:** Using the File Allocation Table to lookup each successive cluster to load.  
- Conclusion

## Introduction: FAT filesystems an overview  

The File Allocation Table, FAT, filesystem is the most commonly used filesystem for floppy disks and other small storage devices. Most operating systems will support the FAT filesystem and the principles are reasonably well documented which makes it one of the more common first filesystem drivers to implement. The number in the filesystem name, I.E. FAT12/FAT16/FAT32, indicates the number of bits used to store each FAT table entry. With increasing FAT table bit sizes more space on the disk can be addressed, so a FAT12 filesystem can address upto 4084 clusters while a FAT16 filesystem can address disk from 4085 upto 65524 clusters. In the FAT12 filesystem used here the term cluster can be replaced with the word sector, however keep in mind it is possible to define larger cluster sizes.  

FAT filesystems despite the name actually contain at least 3 tables of information followed by the disk data. These are the:
- **Boot sector parameter table:** Containing constants which describe the disk and the filesystem.  
- **File Allocation Table:** Indicates which cluster to load next, if any. Also records bad sectors.  
- **Root directory table:** A table of filenames, file information and the first FAT cluster to lookup.  

When accessing the filesystem the information within the boot sector parameter table is used to load the other two tables. The filename you want to access is looked up by performing a search of the root directory table for the given filename. This table contains various fields describing the file permissions, creation time, size etc. but importantly has a field which contains the location of the first cluster. This cluster number can then be looked up in the FAT table to check which cluster to load next, or if we have reached the last cluster.  

*NOTE: This guide uses the FAT12 filesystem, however the contents can be adapted for FAT16 filesystems with relatively minor modifications. FAT32 and exFAT (extended FAT) use the same principles but require more extensive changes.*  

This guide assumes that the previous tutorials on loading sectors and converting from logical to physical (CHS) addresses have already been read. Additionally, writing to the FAT filesystem and FAT directory structures will not be covered in this guide.  


############################### REMOVE
- Making your disk FAT12 compatible  
- - Disk preparation  
- - Boot sector parameters  
- Loading FAT12 files  
- Calculate some important FAT values:  
- - Root Directory Size - (Number of Root Entries * Bytes per entry) / Bytes per sector  
- - Root Directory Start Location - Reserved sectors + Fat sectors  
- - Data start location - Reserved sectors + FAT sectors + Root size  
- Load the root directory into memory  
- Scan through the root directory until the image is found (by 11 digit name)  
- FAT calculations  
- - Work out FAT size - Total FATs * Sectors per FAT  
- - Work out FAT start location - Number of reserved Sectors  
- Load FAT into memory  
- Aquire the FAT cluster based kernel location (using the root dir search as a pointer to the FAT)  
- Convert the FAT cluster address to LBA logical sector address  
- Convert the LBA logical sector address to CHS hard ware based address  
- Load kernel into memory  
##############################

## Creating a FAT12 compatible disk
The first task to implementing a FAT12 filesystem is to ensure your disk is recognised as containing a FAT12 filesystem, and ensuring your bootloader isn't overwritten by files loaded into the disk. The goal of this section is to be able to write files to the disk, or disk image, while preserving your bootloader code.  

### Disk preparation  
You should start with either a blank floppy disk, or a disk which contains no important information, as any data on the disk is likely to be corrupted by the following procedures. It is common to first format the floppy drive or image ('format a:' in DOS), to ensure the disk contains no data in the space used by the FAT filesystem tables. Formatting the disk is not required when working with newly created disk images and not strictly required in all situations when working with physical disks.  

### Boot sector parameters  
Your floppy disk, or disk image, requires a list of variables placed at the very start of the first sector of the drive to become FAT12 compatible. This list contains all the information needed for interacting with the filesystem and is used by both your code and other Operating Systems to access the contents of the disk. Because of the fixed position this information could be written as just "BYTE 0" however it is highly recommend you define the variables with names and comments to allow you to easily refer back to these values and identify their purpose. Including just this information is maybe sufficient to allow the disk to be used by other Operating Systems for saving or reading files.  

jmp EndFATInfo  
 OEM_ID                  db      "MYOS    "      ; 8 char ID of FAT software (I.E. MSDOS)  
 BytesPerSector          dw      512             ; Sector size in bytes  
 SectorsPerCluster       db      1               ; Sectors per cluster  
 ReservedSectors         dw      4               ; Reserved sectors (Sectors used by the bootloader)  
 TotalFATs               db      2               ; Number of FATs (two for redundancy)  
 MaxRootEntries          dw      224             ; Root directory entries  
 TotalSectors            dw      2880            ; Total Sectors  
 MediaDescriptor         db      0F0h            ; Format ID (0F0h = Removable FAT12)  
 SectorsPerFAT           dw      9               ; Sectors per File Allocation Table (FAT)   
 SectorsPerTrack         dw      18              ; Sectors per track  
 NumHeads                dw      2               ; Number of heads  
 HiddenSectors           dd      0               ; Hidden sectors (applicable for partitioned drives)  
 TotalSectorsLarge       dd      0               ; Alternative to TotalSectors for use with large drives  
 DriveNumber             db      0               ; Drive Number (Primary Floppy is usually 0)  
 Flags                   db      0               ; Reserved  
 Signature               db      41              ; Boot signature  
 VolumeID                dd      435101790       ; Volume serial number (date+time)  
 VolumeLabel             db      "NO NAME    "   ; Volume label (11 bytes)  
 SystemID                db      "FAT12   "      ; File system (8 bytes)  
EndFATInfo:  

The inline comments in this example explain most of the fields. They can loosely be categorised into fields which describe the physical drive (BytesPerSector; TotalSectors; SectorsPerTrack; NumberOfHeads; DriveNumber) values with describe the file system (SectorsPerCluster; TotalFATs; MaxRootEntries; SectorsPerFAT) values for indicating reserved space (ReservedSectors; HiddenSectors) and a number of values which are either purely informational (eg. VolumeID) or defined to fixed values based on the FAT specification. The values which describe the physical disk generally take values which are consistant with those required by interrupt 0x13.  

The field you need to pay attention to is Reserved Sectors. The minimum value for this field is 1, but if your bootloader spans multiple sectors ensure you update this value to reflect the number of sectors reserved for your bootloader. This can easily be figured out by taking the size of your second stage binary in bytes, dividing by 512 and rounding up.  

*NOTE: The text fields are a fixed length. If you change the contents ensure you add or remove space characters to maintain the fields original length*  

### Initialising the FAT table  
Often just adding the boot sector parameters is enough to make the disk recognised. Especially if your bootloader is entirely contained within the first sector and you have preformatted the drive. Even when that is not the case I have usually found the disk to work without further steps provided the drive has been zeroed. However, offically the first two entries of the FAT table are used to store additional information by the filesystem. The start of the first entry describes the drive type, while the start of the second entry is used to indicate the filesystems status.  

Entry 1: Contains the media descriptor (as used in the boot sector parameter table)  
- Format = Media descriptor code, with all preceeding bits set to 1 (F in hexadecimal).  
- *FAT16:* FFF0h or in binary 1111111111110000b  which is stored as 0000111111111111  
- *FAT12:* FF0h or in binary 111111110000b which is stored as 000011111111  
This inversion of the bit order is due to x86 computers being little endian. If you are not confident how this works I recommended pausing and looking up endianess. *NOTE: For FAT16 it is more likely the media descriptor F8 would be used, indicating a fixed, non removable, disk.*  

Entry 2: Contains information on the filesystem condition  
- Format = <0=Dirty, did not unmount cleanly>,<0=Errors found when last mounting disk>,<All other bits = 1>
- *FAT16:* FFFFh if clean; FF7Fh if not unmounted correctly; FFBFh if the filesystem has errors; FF3Fh if both.
- *FAT12:* FFFh (Note the filesystem condition flags aren't usually used for FAT12 filesystems)

These values can be easily added to an assembly file and compiled to create an empty FAT table ready for writing to a disk if you find it is required, or if you want to ensure you are adhering to the FAT standard. However, as their isn't a 12bit data type for FAT12 you will probably need to write the values using 3 8bit bytes.

[BITS 16]       ; Informs the compiler that 16bit machine code is required.  
[ORG 0x0000]    ; Origin, informs the compiler where the code is going to be loaded in memory.  

MediaDescriptor  db  0xF0  ; Media descriptor (as used in the boot sector parameter table)  
FilesystenFlags  db  0xFF  ; FF for clean. F7 for not correctly mounted etc.  
Filler           db  0xFF  ; Always FF to set remaining bits in the second FAT entry to 1.  

times 512-($-$$) db 0 ; Fills the rest of the sector with zeros.  

*Note: This creates a single sector, the FAT table is likely larger than 1 sector. If you want to explicity zero out the rest of the FAT table space multiply the FAT size in sectors by the sector size (512) and use this value instead.*  

### Testing the disk  
First write your bootloader to the disk:
- Create a disk image or format a physical disk.  
- Compile and write to disk the bootloader file(s).  
- *If required* write the FAT table to the disk.  

Remount the disk, or disk image and try writing a file to the disk. In linux with a disk image this can be done using:  
mkdir Temp  
sudo mount -o loop floppy.img Temp  
sudo cp filename.txt Temp  
sudo umount Temp  

If this has worked you should now be able to use the floppy disk, or disk image, for storing files just like any other floppy disk.  

## Looking up a filename
Now the disk can be used as a FAT12 device, the next step is to perform a search of the root directory table to find out where a specific file is located.

### Root directory table
This table is located immediately after the File Allocation Tables and contains an entry for each file in the root directory. Each entry is 32bytes and is contains the following fields:  
- Filename (8 bytes) + extension (3 bytes)
- Permissions and attributes (1 byte)
- Reserved, set to 0 (1 byte)
- Creation timestamp, tenths of a second (1 byte)
- Creation timestamp time (2 bytes) - *Optional*
- Creation timestamp date (2 bytes) - *Optional*
- Last access date (2 bytes) - *Optional*
- Reserved for FAT32, set to 0 (2 bytes)
- Write time (2 bytes)
- Write date (2 bytes)
- Starting cluster number (2 bytes)
- File size (4 bytes)

The optional fields should be set to zero if unused. The field reserved for FAT32 stores part of the more significant part of the cluster number in FAT32 filesystems as the FAT12/16 field isn't large enough alone.  *Note: The root directory table also contains entries for directories. But this guide assumes the file is located in the root directory.*

### Loading the root directory table  
The first step in loading the root directory table is to first calculate it's position and size. This could be done once and hard coded, however it is relatively easy to calculate. Additionally by calculating this and similar values required later it will be easier to adapt the code to accomodate any changes later.  

Using the values from the boot sector parameter table described earlier the root table starting position and size in logical sectors can be calculated as:  

Root table position = Number of reserved sectors + (Number of File Allocation Tables * Sectors per FAT)  
Root table size = (Maximum number of root entries * bytes per root table entry) / bytes per sector  

The only value not present in the boot sector parameters table is the bytes per root table entry, which is specified as 32. *It is important to round up the route table size to ensure the entire table is loaded.*  

Using the example boot sector parameter table used previously this would give the values:  

RootPosition = ReservedSectors + (TotalFATs * SectorsPerFAT)  
RootPosition = 4 + (2 * 9) = 22
RootSize = (MaxRootEntries * 32) / BytesPerSector  
RootSize = (224 * 32) / 512 = 14  
***This is only provided as an example the values you need may be different, for example by using a different number of reserved sectors.***  

In assembly theses calculations become:

RootStart dw 0                  ; Optionally create some variables to store the results
RootSize  dw 0

; Calculate root directory start position  
xor ax,ax                       ; Zero AX  
mov al, BYTE [TotalFATs]        ; Load up number of FAT tables (/info) into AL  
mul WORD [SectorsPerFAT]        ; Multiply AL by the number of sectors per File Allocation Table  
add ax, WORD [ReservedSectors]  ; Add to the FAT total (AX) the number of reserved sectors  
mov [RootStart], ax             ; Store the root table position in a variable  
                                ; Or alternatively store to the stack or unused register  

; Calculate root directory size  
xor ax, ax                      ; Zero registers  
xor cx, cx                      ; Alternative to CX could be used here  
mov ax,[MaxRootEntries]         ; Move the first value to the arithmatic register (AX)
mov cx, 32                      ; Move the multiplcation factor (bytes per entry) into a register  
mul cx                          ; Multiply the number of root entries by the entry size  
xor dx, dx                      ; Zero DX incase a remainder is generated by the division  
div WORD [BytesPerSector]       ; Divide by the bytes per sector to get the size in sectors
; If DX is not zero one needs to be added to AX (round up)  
test dx,dx                      ; Test the value in dx (could also use 'cmp, dx,0' here)  
jz rootsizeend                  ; If the value is zero jump past the AX increment  
inc ax                          ; Add one to AX to round up  
rootsizeend                     ; Label to jump to if there was no remainder  
mov [RootSize], ax              ; Store the root table position in a variable  
                                ; Or alternatively store to the stack or unused register  

This is a comprehensive example storing the results into memory variables. If you are creating a minimalistic driver and don't anticipate the values in the boot sector parameter table to change you could calculate the values and write them into the code directly or perform the above calculation but exclude the lines which round up the sector number after the division.  

Finally the root table can be loaded into a free space in memory. The instructions for performing this is covered in the previous addressing sectors and loading sectors tutorials and won't be covered here. Because the code execution isn't moving to this memory location it's important to ensure you choose a memory offset that doesn't overlap with your executing code. To simplify the process I recommend keeping the segment registers the same where possible.  

mov ax, [RootStart]            ; Move the LBA address to ax  
mov cx, [RootSize]             ; Move the table size into cx  
mov bx, 0x1000                 ; Memory offset to load sectors into  
call readsectors               ; Procedure to load the sectors into memory  

This example code doesn't perform any error checking but should demonstrate the procedures required to load multiple sectors into memory, utilising the functions decribed in the previous addressing sectors tutorial.  

### Looking up a filename in the root directory table  
With the root directory table loaded into memory it is now ready to be searched to find an entry that matches the filename of the kernel, or another file you want the details of. Each entry is 32 bytes with the filename taking up the first 11 of those bytes. *The period in the filenames is not stored and is only used to separate the filename from the extension. I.E. "FILE.TXT -> "FILE    TXT".* Which means a search can be done by comparing 11 bytes, moving along to the start of the next entry then comparing again until all entries have been checked.

An example of this is:  

KernelName db "KERNEL  COM"     ; File name to search for  

mov cx, WORD [MaxRootEntries]   ; Number of entries to check  
mov di, 0x1000                  ; First root entry (Offset)  
SearchLoop:  
push cx                         ; Preserve the counter for the number of entries remaining  
mov cx, 0x000B                  ; Eleven character name (Num of times for rep to repeat)  
mov si, KernelName              ; Filename for comparison (Load into SI the string to compare to DI)  
push di                         ; Save DI (Modified by cmpsb command)  
rep cmpsb                       ; Repeat internally the compare string block instruction (DS:SI to ES:DI) CX times  
pop di                          ; Restore DI  
je FoundFile                    ; If equal the file has been found, jump to FoundFile label.  
pop cx                          ; Restore the counter value  
add di, 0x0020                  ; Add 32 to the value in DI (Next FAT block start)  
loop SearchLoop                 ; Loop decreases cx by one and jmps, unless cx == 0 then it stops looping.
; File has not been found, you may want to display an error message  
jmp End                         ; Ignore the code to run on success  
FoundFile                       ; File has been found
; Add code to display a message or load the file etc.
End

*Note: replace the offset of the first entry to reflect the offset you have loaded the root directory table into.*

This example introduces a couple of new instructions like rep cmpsb and loop, with there use described in the comments. Otherwise the code is fairly self explainatory. This code snippet doesn't perform any action when a file is found, or not found. It is recommended that you take this code and experiment with adding success and failure messages. However take care to preserve the value in DI, as this contains the offset in memory for the matching root table entry and is needed to lookup additional details on the file.  

## Loading a file
Each root directory table entry has a field for the first FAT filesystem cluster to load. Looking up this cluster in the File Allocation Table will identify if this is the last cluster, or provide the address of the next cluster to load.

### File Allocation Table structure
The structure of the file allocation table was briefly covered earlier in this tutorial. The purpose of this table is to identify the next cluster to load when accessing a file. The size of each table entry is given in the FAT filesystem name. A FAT12 filesystem uses 12bits per entry while a FAT16 filesystem uses 16 bits (2 bytes) per entry. The FAT table has the following structure:

- Entry 1 - Reserved, contains Media Descriptor.
- Entry 2 - Reserved, contains flags on filesystem condition.
- Entry 3 - Associated with cluster 1.
- Entry 4 - Associated with cluster 2.
- ...

The contents of the first two reserved table entries is covered in the earlier section on creating a FAT compatible disk. Entries 3 onwards are associated with FAT filesystem clusters, starting with the first cluster.

The valid values for these entries are:
- 0x0000: Free cluster
- 0xFFF7: Bad sector in cluster
- 0xFFF8 to 0xFFFF: End of file
- 0x0003 to maximum cluster number: Number of the next cluster to load

These values are for FAT16, but can be converted to FAT12 by removing the first 4 bits. ***The maximum cluster number is two higher than the physically available clusters to account for the two FAT table entries reserved for other uses at the start of the table.***

*Note: Values 0x0001 and 0x0002 are not permitted as those entries are reserved and do not form part of a cluster chain. The cluster chain must not loop back on itself.*

Therefore the process of accessing a file is as follows:
- Lookup the files first cluster number in the root directory table. (I.E. 5)
- Lookup the associated FAT entry
- - If the FAT entry contains 0xFFF7 stop with an error message, bad sector in cluster
- - Else Load the cluster
- - If the FAT entry contains a value between 0xFFF8 and 0xFFFF stop, end of file reached.
- - Else goto the FAT cluster number contained in the current FAT cluster entry
- - Loop back to the bad sector check

Additional checks could also be included to ensure the value in the FAT table entry is valid and doesn't exceed the available number of clusters.

*Note: The cluster number provided in the root directory table should contain a value for a valid FAT entry, between 3 and number of maximum cluster number. However there are exceptions, as the 'Volume Label' is a special FAT entry which uses cluster number 0 and has the same name as given in the boot sector parameters, however this guide will ignore these exceptions and assume an unlabelled disk with 'no name'.*

**Often a FAT disk will contain two File Allocation Tables for redundancy.** They should contain the same information, so if there is an issue reading one table the second table can be used instead.  

### Loading the File Allocation Table
As with the root directory table the first step is to load the File Allocation Table. This requires calculating the FAT position and size. As with the root directory table these values could be calculated before and added to the code as constants, however it is more versatile to calculate these values from the parameters at the beginning of the boot sector.  

The File Allocation Table starts immediately after the reserved sectors therefore the number of reserved sectors value is also the first FAT sector, as the boot sector is located at logical sector 0. The size can be calculated by taking the number of File Allocation Tables and multipling them by the size of each table, in sectors. All these values are present in the boot sector parameter block.

Using the example boot sector parameter table used previously this would give the values:  

FATPosition = ReservedSectors  
FATPosition = 4  
FATSize = TotalFATs * SectorsPerFAT  
FATSize = 2 * 9 = 18  
***This is only provided as an example the values you need may be different.***  

The FAT position doesn't need calculation, but below is an example of how to calculate the FAT table size, utilising the boot sector parameters.

FATSize dw 0             ; Variable to store the FAT size  

; Calculate the size of the FAT tables  
xor ax,ax                ; Zero AX to remove any values currently present    
mov al, BYTE [TotalFATs] ; Move the number of FAT tables into the arithmatic register (AL)  
mul WORD [SectorsPerFAT] ; Multiply the number of FAT tables by their size in sectors    
mov WORD [FATsize], ax	 ; Store the result in a memory variable

In the example above the size of the FAT table region is stored in a variable, but it could be stored to the stack or in an unused register.

The FAT tables can then be loaded into memory in the same way as the root directory table.

mov ax, [ReservedSectors]      ; Move the LBA address to ax  
mov cx, [FATSize]              ; Move the table size into cx  
mov bx, 0x1000                 ; Memory offset to load sectors into  
call readsectors               ; Procedure to load the sectors into memory  

The memory location used can be the same as the root directory table, when writing code for the bootloader, provided the number of the first cluster of the file has been already looked up and stored.

*The error handling of the readsectors code (from a previous guide) could be modified to take advantage of the redundant FAT table, if present, ensuring at least one FAT table is loaded if possible. However this is not covered as part of this guide.*

An alternative to loading the entire FAT region into memory is to only load up the sector containing the FAT entry needed. However this method of FAT loading requires additional calculations to determine which sector to load and the memory location of the FAT entry, additionally for larger files this may also require multiple disk reads to load different part of the FAT table. To keep this guide simple this approach isn't covered in this guide, prefering to instead load the entire table.

### Loading a file from the File Allocation Table
With the FAT table loaded into memory it can be accessed to identify the next cluster to load, or if the loading of the file should halt due to an error or the end of the file. While the principles are the same for FAT12 and FAT16 filesystems the differences in entry size makes accessing the FAT table slightly different. Particularly for FAT12 filesystems, as there there isn't a 12bit data structure.  

The first cluster number has been provided by the root directory table, the first step is to load the contents of the associated FAT entry and check if the cluster is a bad sector. Depending on how your driver is configured you may want to either halt the loading of the file if a bad sector is indicated or displaying a warning before attempting to load the sector.

; Load the contents of a FAT entry  
FATmemorylocation dw 0x1000   ; Change to reflect where the FAT is loaded in memory  
FileFirstCluster  dw 0        ; Memory variable storing the file's first cluster number  

...                           ; Look up the FileFirstCluster value using the root directory table

; Lookup the contents of the FAT entry
; FAT16
mov ax, [FileFirstCluster]  ; Load into the arithmatic register the cluster number  
mov cx, 2                   ; Bytes per cluster entry  
mul cx                      ; Multiply the cluster by the bytes per cluster to calculate the offset  
mov bx, [FATmemorylocation] ; Load the memory location of the FAT into a register
add ax, bx                  ; Add the offset to the FAT table start location in memory
                            ; Alternative would be add ax, WORD [FATmemorylocation]

; FAT12
mov ax, [FileFirstCluster]  ; Load into the arithmatic register the cluster number  
mov cx, [FileFirstCluster]  ; Bytes per cluster entry  

*Note: The number of the first file cluster doesn't need to be stored in a memory variable, it could be loaded into a register or retrieved from the stack.*

Loading the FAT





########## CURRENT POINT OF REWRITE PROGRESS ###########


- - Data start location - Reserved sectors + FAT sectors + Root size

        mov cx,[RootSize]               ; Mov the root size into CX
        add ax, cx			; Add ax (RootStart) to cx (RootSize)
	mov [DataStart], ax             ; Move the answer into DataStart

  - Calculate the next cluster and get the cluster details from the FAT (This is a procedure used
    else where)

  NextCluster:
  	mov cx, ax			; Copy current cluster
  	mov dx, ax			; Ditto again
  	shr dx, 0x0001			; Divide dx by 2
  	add cx, dx			; CX = 1.5
  	mov bx, 0x1000			; Load the FAT location
  	add bx, cx			; Add the calculated offset to the FAT location (Index into FAT) bx = FAT+calculated offset
  	mov dx, WORD [bx]		; Read two bytes from FAT (a word)
  	; Odd even test
  	test ax, 0x0001			; Test to see if the cluster was odd or even (Seems to be the old cluster rather than the just calculated value!)
  	jnz .OddCluster			; If not a zero ending cluster:
  	.EvenCluster:
  		and dx, 0x0fff		; Mask out the top 4 bits (0000111111111111b)
  		jmp .Done		; Carry on to next section
  	.OddCluster:
  		shr dx, 0x0004		; So shift right by 4 bits. (1111111111110000b -> 0000111111111111b)
  	.Done:
  		mov ax, dx		; Move result to ax
  		ret			; Return


  - Calculate the LBA address from the FAT address (Procedure)

  FATtoLBA:
  	sub ax, 0x0002				; Subtract 2 from ax (Not sure why yet)
  	xor cx, cx				; Zero CX
  	mov cl, BYTE [SectorsPerCluster]	; Move SPC to cl
  	mul cx					; Multiply AX by CX (FAT*SectorsPerCluster)
  	add ax, WORD [DataStart]		; Base data sector
  	ret					; Return

    - Load kernel into memory (Combines all this)
    	push es		; Save es
    	mov bx, 0x3000	; Destination location
    	mov es, bx	; Segment
    	mov bx, 0x0000	; Offset
    	push bx		; Save bx
    	LoadKernelImage:
    	xor ax, ax
            mov     ax, WORD [KernelAddress]                  ; cluster to read
            pop     bx                                  ; buffer to read into
            call    FATtoLBA                          ; convert cluster to LBA
    	mov [KernelAddressLBA], ax
    	mov ax, [KernelAddressLBA]
            xor     cx, cx
            mov     cl, BYTE [SectorsPerCluster]        ; sectors to read
            call    ReadSectors
            push    bx
         	; compute next cluster
    	; Reading the FAT
    	xor ax, ax
    	mov ax, WORD [KernelAddress]	; Current Location
    	call NextCluster		; Work out the next cluster
    	mov WORD [KernelAddress], ax		; The new cluster value is stored in the variable.
    	; Test to see what value the next cluster contains.
    	cmp ax,0000h		; Free cluster (Empty)
            je .EmptyError          ; Error message
    	cmp ax,0ff7h		; Is it a bad cluster?
            je .BadClusterError     ; Error message
    	; Test to see if this is the end of the cluster chain:
    	cmp ax,0x0fff		; End of chain? (0fff)
    	je KernelJmp		; Jump to the loaded kernel
    	jmp LoadKernelImage	; Loop back round to start
            .BadClusterError:               ; Short jumps needed initally.
                    jmp BadClusterError     ; Jump to error handler
            .EmptyError:
                    jmp EmptyError          ; Jump to error handler


*Due to the redundant tables, if present, any invalid FAT table entries, or even valid entries, could be compared with the redundant table to identify or resolve irregularities. However this topic is not covered as part of this guide.*


########## CURRENT POINT OF REWRITE PROGRESS ###########


## Root directory calculations  
These calculations are quite important in loading and using the FAT table and will certainly
be needed if you plan to implement a FAT file system. I personally put the results of the
3 formulas into there own variables for refering to them: DataStart, RootStart and RootSize
Though some people may prefer to play around with the stack and/or registers rather than storing
the values in variables. Variables make it easier to read and understand and allows changes to
be made easier. Hence the reasons I recommend using them regularly. But it does use up disk
space!
- The root directory size can be calculated by values within the FAT table, the values used for
this calculation would be: Number of Root Entries, Bytes per entry and Bytes per sector.
The formula is: (NumOfRootEntries * BytesPerEntry) / BytesPerSector
In words: Times Number of root enters by the bytes per entry, then divide that value by bytes
per sector. (Ignore any remainder, that is used later)
- The root directory start location is calculated using values within the FAT table also, the
values used are: Number of reserved sectors, Total FATs and Sectors per FAT.
The formula is simply: NumReservedSectors + (TotalFATs * SectorsPerFAT)
(TotalFATs * SectorsPerFAT) equals the total number of FAT sectors.
- The data start location can be (yet again) calculated by values within the FAT table (by now
you should be relising how much easier it is to refer to the values by name than position).
The values used are: Reserved sectors, Total FATs, Sectors per FAT
Also the value of Root size aquired from an earlier calculation is needed.
The formula is: Reserved sectors + (Total FATs * Sectors per FAT) + Root size
(Total FATs * Sectors per FAT) is equal to The total number of FAT sectors.

## Loading the root directory  
The next stage is to load the root directory into memory. I assume that you know about loading
sectors and LBA to CHS addressing from earlier documents I've written so I'll skip the details.
The values to input are simply to start loading from "RootStart" calculated in the earlier step
and to load the number of sectors calculated by the other calculation. ("RootSize" sectors)
So this stage if you understand my earlier documents should be quite easy.
The location to load the root directory into though can be of your own choosing (within reason).
As long as it doesn't disrupt the running of the boot loader or any important data previously
written to memory by your boot loader.

## Browse the root directory  
In this stage, which is quite a bit harder you have to browse/search/scan (or what ever you want
to call it) the root directory for the entry corresponding to the kernel file name you have will
defined. It searchs by file name, an 11 digit name. Unlike DOS it is not a nice "kern.com"
style string but "KERN    COM", it HAS to be 11 digits long and the '.' is removed.
The search should have a fail safe so that it searchs a few times in case of a floppy error
during the first try to read the disk.
What is normally done is:
- Read 11 bytes into memory from start of Root Dir.
- Compare with the 11 digit file name string hard set in the boot loader code as a variable.
- If the compare is equal then stop and save the current Root Dir offset.
- Else add 20h (or 32 bytes I think), 11 bytes name then other details of the file filling the
  rest of the entry. Then loop round to the start, repeat until you run out of root dir.
Once the search has ended save/store the offset of how far into the root directory the file entry
was found for future reference/use.

## FAT calculations  
These claculations are needed in order to load the FAT and load anything from the FAT file
system, if you per chance just wanted to get a list of files or search for a file but nothing
more you can get away with out implementing this section or anything more.
I recommend that you store these values into variables if you have the space, if not make sure
not to accidently delete them! (I use FATsize and FATstart in this document and my code)
- The FAT size is equal to (as I have mentioned before in a couple of places) the number of FATs
  (Yes there can be more than 1, but we won't be dealing with anything complicated) times by the
  number of sectors per FAT.
  So NumFATs * SectorsPerFAT equals Total number of FAT sectors aka FAT size.
  The values NumFATs and SectorsPerFAT you define in the FAT table at the start of the boot
  sector normally.
- The FAT start location is also very simple. It starts after any reserved sectors. Number of
  reserved sectors is defined in the FAT table at the start of the boot loader also.
  So formula wise: FATstart = NumReservedSectors
  (Yes that easy) Why the reserved sectors? Well some boot loaders may load up multiple stages
  so using more than the normal 1 sector of disk. There may be other things that could reserve
  sectors at the start but mostly it will be by elaborate boot loaders.

## Loading the FAT  
Now we need to load the FAT into memory so we can look up the address of the entry in the root
directory. This is a very simple overlay style lookup (for lack of a better term). The offset
in the root directory when applied to the FAT will give the address of the root entry in FAT
format. (This later will need converting)
I will again assume that you have read the earlier documents on boot loaders and so understand
the principles of loading sectors from a disk using LBA format. (So read up on loading sectors
and LBA to CHS addressing conversion if you haven't done so yet, or if you need reminding)
You will have to load the sectors starting at FATstart (defined by the earlier stage) and of
FATsize (again defined by the earlier stage).
You propbably could load the FAT into any unused memory location but it is a bit wasteful of
memory and a lot more complicated, where as the easiest place to load it is over the top of the
root directory location. As we no longer will be needing the root directory in the boot loader.
If we did it would only take a second to reload it. This way though you save a lot of hassle with
trying to make pointers point to the right places.

## Looking up the FAT cluster  
By following the previous stages correctly this stage is not really even needed! You don't have
to look up the cluster till the actual loading of the kernel. The offset into the root directory
is the first cluster! This makes things far easier, as there is no calculations needed here,
you just need to understand how important the offset into the root directory really is.
The root directory entry location offset is equal to the offset needed for the FAT address and
details.

## Converting a FAT cluster to a LBA logical sector address  
This converts the FAT cluster based addressing into LBA based addressing. The difference is that
clusters can be of different sizes on different FAT based implementations where as LBA
addressing deals only with sectors, and CHS addressing deals with sectors, heads and tracks.
Formula to get the data location offset: LBA = (Cluster - 2) * sectors per cluster
Then also you have to add to this the datastart location to get the actual file data/content
address. This is done in an earlier stage in a calculation, DataStart.

## Converting LBA addressing to CHS addressing  
This I have convered in an earlier document/tutorial. I recommend starting off by refering to
things by CHS addressing (Approx 18sectors per track normally), then LBA addressing then moving
onto filesystems. At least until you get the hang of how it all works and fits together. Also in
my opinion FAT12 is the easiest file system to start with (other than a custom made one) which
also has among the largest amount of support. So with the end product you will be able to read
and write to the disk like you would any other using a FAT12 driver. (Standard in microsoft OS's)

## Loading the kernel  
This is by far among the harder sections, and not as easy as reading the FAT or root directory.
There are no calculations working out the size of the kernel. The start of the kernel though
has just been calculated by the earlier set of formulas.
So to work out the last cluster you have too look up each cluster in the FAT table to see if it
is the end cluster of the current chain or if it is data or if it is an unexpected empty cluster
(an empty cluster would mean that the file would probably be corrupted or similar).
The basic steps are:
- Move to the next cluster (Harder than it sounds, formula is: (Current*1.5) read FAT table,
  if odd shift right 4 bits, if even mask out top 4 bits)
- Check FAT cluster details: (The data just read from the FAT)
- - If Empty code and display a corrupted/incomplete file message (Code num: 0000h)
- - If Bad cluster code display an error message (Code num: 0ff7h)
- - If End of chain/file code display a complete/loaded file message (Code num: 0fffh)
- - If Data code move onto the next cluster (Code num: Address to next cluster)
- Convert FAT to LBA addressing
- Load the number of bytes per cluster (BytesPerCluster defined in the FAT table)
- Jump round to the start
This is more complicated in the implementation than it sounds here (at least when you are trying
to fit it all into 1 sector normally) but that is the simple version which should get the major
implementation points across.

In all the above detailed descriptions it goes into varying depths and the code behind it is
either easier or harder to understand than the description of the process.
By following those points though you should get pretty near to a working implementation. If not
a working implementation.

I don't intend you to learn purely from here but to use this as a guide line to know what is
needed to implement a FAT12 system.

## Examples  

All the examples are simple cut's and pastes from my own boot loaders. The source of my
boot loaders contain extra comments with the input and output of each procedure/section.
The source to look at is: Bootloader Ver 0.5
This code may be dependant upon earlier code or values stored else where in my bootloader.
The general idea is not to cut and paste my code unless you understand what it does properly.
And remember I prefer it if you don't steal my code without notifying me.

- FAT12 table:

        OEM_ID                  db      "DFOS    "      ; 8 char sys ID
        BytesPerSector          dw      512             ; Sector size in bytes
        SectorsPerCluster       db      1               ; Sector per cluster
        ReservedSectors         dw      4               ; Reserved sectors (This I think for this should become 2 for the boot strap, was 1)
        TotalFATs               db      2               ; Number of fats
        MaxRootEntries          dw      224             ; Root directory entries
        TotalSectorsSmall       dw      2880            ; Total Sectors
        MediaDescriptor         db      0F0h            ; Format ID (FAT12 ID number)
        SectorsPerFAT           dw      9               ; Sectors per FAT
        SectorsPerTrack         dw      18              ; Sectors per track
        NumHeads                dw      2               ; Number of heads (2 as double sided floppy)
        HiddenSectors           dd      0               ; Special hidden sectors
        TotalSectorsLarge       dd      0               ; More sectors
        DriveNumber             db      0               ; Drive Number (Primary Floppy is normally 0)
        Flags                   db      0               ; Reserved
        Signature               db      41              ; Boot signature
        VolumeID                dd      435101793       ; Volume serial number
        VolumeLabel             db      "NO NAME    "   ; Volume label (11 bytes)
        SystemID                db      "FAT12   "      ; File system (8 bytes)

- Calculate some important FAT values:
- - Root Directory Size - (Number of Root Entries * Bytes per entry) / Bytes per sector

	xor ax, ax			; Zero registers
	xor cx, cx
        mov ax,[MaxRootEntries] 	; Move value to register to work on. ax=Arithmatic
        mov cx, 32      		; Move value to multiply into register
        mul cx          		; Multiply
        div WORD [BytesPerSector]    	; Divide
        mov [RootSize], ax      	; Put the value into a nice storage area for a bit

- - Root Directory Start Location - Reserved sectors + Fat sectors

	xor ax,ax			; Zero AX for next calculation
        mov al, BYTE [TotalFATs]        ; Load up number of FAT tables (/info) into AL
        mul WORD [SectorsPerFAT]        ; Multiply AL by the number of sectors per FAT table (/info)
        add ax, WORD [ReservedSectors]  ; Add to the FAT total (AX) the number of reserved sectors
        mov [RootStart], ax             ; Put the start of the root address into RootStart variable

- - Data start location - Reserved sectors + FAT sectors + Root size

        mov cx,[RootSize]               ; Mov the root size into CX
        add ax, cx			; Add ax (RootStart) to cx (RootSize)
	mov [DataStart], ax             ; Move the answer into DataStart

- Load the root directory into memory

	mov ax,[RootStart]		; Start location of the root directory
	mov cx,[RootSize]		; Number of sectors to load
	mov bx,0x1000			; Offset of location to write to (es:bx)
	call ReadSectors		; <- Read root directory sectors

- Scan through the root directory until the image is found (by 11 digit name)

	mov cx, WORD [MaxRootEntries]	; Load the loop counter
	mov di, 0x1000			; First root entry (Offset)
	SearchLoop:
	push cx				; Save counter value
	mov cx, 0x000B			; Eleven character name (Num of times for rep to repeat)
	mov si, KernelName		; Kernel image to find (Load into SI the string to compare to DI)
	push di				; Save DI (Modified by cmpsb command)
	rep cmpsb			; Repeat internally the compare string block instruction (DS:SI to ES:DI) CX times
	pop di				; Restore DI
	je FoundKernel			; If equal jump to load kernel.
	pop cx				; Restore the counter value
	add di, 0x0020			; Add 32 to the value in DI (Next FAT block start)
	loop SearchLoop			; Loop dec's cx by one and jmps, unless cx == 0 then it stops looping.
	jmp SearchError			; Jump to the search error message

	FoundKernel:
        mov     dx, WORD [di + 0x001A]
        mov     WORD [KernelAddress], dx                  ; files first cluster

- FAT calculations
- - Work out FAT size - Total FATs * Sectors per FAT

	xor ax,ax		; Zero AX
	mov al, BYTE [TotalFATs]; Move TotalFAT's into position
	mul WORD [SectorsPerFAT]; Multiply by SectorsPerFAT
	mov WORD [FATsize], ax	; Move into memory variable

- - Work out FAT start location - Number of reserved Sectors

	xor ax,ax			; Zero AX
	mov ax, WORD [ReservedSectors]	; Move ReservedSectors into ax (This is the FATstart location)

- Load FAT into memory

	mov cx, WORD [FATsize]	; FAT table size
	mov bx,0x1000		; Offset of memory location to load to
	call ReadSectors	; Read sectors procedure

- Calculate the next cluster and get the cluster details from the FAT (This is a procedure used
  else where)

NextCluster:
	mov cx, ax			; Copy current cluster
	mov dx, ax			; Ditto again
	shr dx, 0x0001			; Divide dx by 2
	add cx, dx			; CX = 1.5
	mov bx, 0x1000			; Load the FAT location
	add bx, cx			; Add the calculated offset to the FAT location (Index into FAT) bx = FAT+calculated offset
	mov dx, WORD [bx]		; Read two bytes from FAT (a word)
	; Odd even test
	test ax, 0x0001			; Test to see if the cluster was odd or even (Seems to be the old cluster rather than the just calculated value!)
	jnz .OddCluster			; If not a zero ending cluster:
	.EvenCluster:
		and dx, 0x0fff		; Mask out the top 4 bits (0000111111111111b)
		jmp .Done		; Carry on to next section
	.OddCluster:
		shr dx, 0x0004		; So shift right by 4 bits. (1111111111110000b -> 0000111111111111b)
	.Done:
		mov ax, dx		; Move result to ax
		ret			; Return


- Calculate the LBA address from the FAT address (Procedure)

FATtoLBA:
	sub ax, 0x0002				; Subtract 2 from ax (Not sure why yet)
	xor cx, cx				; Zero CX
	mov cl, BYTE [SectorsPerCluster]	; Move SPC to cl
	mul cx					; Multiply AX by CX (FAT*SectorsPerCluster)
	add ax, WORD [DataStart]		; Base data sector
	ret					; Return

- Convert the LBA logical sector address to CHS hard ware based address
Please look at one of my earlier documents on this.

- Load kernel into memory (Combines all this)
	push es		; Save es
	mov bx, 0x3000	; Destination location
	mov es, bx	; Segment
	mov bx, 0x0000	; Offset
	push bx		; Save bx
	LoadKernelImage:
	xor ax, ax
        mov     ax, WORD [KernelAddress]                  ; cluster to read
        pop     bx                                  ; buffer to read into
        call    FATtoLBA                          ; convert cluster to LBA
	mov [KernelAddressLBA], ax
	mov ax, [KernelAddressLBA]
        xor     cx, cx
        mov     cl, BYTE [SectorsPerCluster]        ; sectors to read
        call    ReadSectors
        push    bx
     	; compute next cluster
	; Reading the FAT
	xor ax, ax
	mov ax, WORD [KernelAddress]	; Current Location
	call NextCluster		; Work out the next cluster
	mov WORD [KernelAddress], ax		; The new cluster value is stored in the variable.
	; Test to see what value the next cluster contains.
	cmp ax,0000h		; Free cluster (Empty)
        je .EmptyError          ; Error message
	cmp ax,0ff7h		; Is it a bad cluster?
        je .BadClusterError     ; Error message
	; Test to see if this is the end of the cluster chain:
	cmp ax,0x0fff		; End of chain? (0fff)
	je KernelJmp		; Jump to the loaded kernel
	jmp LoadKernelImage	; Loop back round to start
        .BadClusterError:               ; Short jumps needed initally.
                jmp BadClusterError     ; Jump to error handler
        .EmptyError:
                jmp EmptyError          ; Jump to error handler

All of my examples are cuts and pastes from version 0.5 of my bootloader. This is probably not
an ideal example as I have implemented some things in odd ways. But my bootloader does work
which is the important thing. If you do use any of my code (no matter how small) I would
appreciate being notified and my name mentioned with the source next to my code with a link to
my website/details. To use any of my code in a commercial product requires my permission however!

I hope this has helpped you with implementing FAT12 in a bootloader. (Though it can also with
some small changes be used within a kernel as a FAT12 driver)

If this has helpped you please send me an e-mail saying so. (I like compliments)

If you want to see new things in here please say, if you want to translate this into an other
language please send me the new version so I can host that as an alternative. (I can translate
copy's of this if requested but the altavista/google/etc translaters aren't quite perfected for
large documents like this, and I would rather spend my time working on something else)

If you change this or make a copy on your website could you please keep my details with the file
and could you please notify to me some how.

Daniel Rowell Faulkner
