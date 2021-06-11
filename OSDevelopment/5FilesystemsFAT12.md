# The FAT12 filesystem (readonly)  
A guide to writing a minimalistic FAT12 driver for the purpose of loading and executing a kernel file from within the bootloader. FAT16 filesystems follow a similar process and is discussed in this guide, but without examples. The driver could also become the base for creating a FAT12/16 kernel driver.  

## Contents

This tutorial will cover the information in the order that you need to access the tables. This allows you to create functional code to test each stage before moving onto the next section.  
- Introduction
- **Creating a FAT12 compatible disk:** How to ensure the disk is recognised as a FAT12 disk, allowing files to be loaded onto the disk by other operating systems. Describes the boot sector parameters table.  
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

## Creating a FAT12 compatible disk
The first task to implementing a FAT12 filesystem is to ensure your disk is recognised as containing a FAT12 filesystem, and ensuring your bootloader isn't overwritten by files loaded into the disk. The goal of this section is to be able to write files to the disk, or disk image, while preserving your bootloader code.  

### Disk preparation  
You should start with either a blank floppy disk, or a disk which contains no important information, as any data on the disk is likely to be corrupted by the following procedures. It is common to first format the floppy drive or image ('format a:' in DOS), to ensure the disk contains no data in the space used by the FAT filesystem tables. Formatting the disk is not required when working with newly created disk images and not strictly required in all situations when working with physical disks.  

### Boot sector parameters  
Your floppy disk, or disk image, requires a list of variables placed at the very start of the first sector of the drive to become FAT12 compatible. This list contains all the information needed for interacting with the filesystem and is used by both your code and other Operating Systems to access the contents of the disk. Because of the fixed position this information could be written as just "BYTE 0" however it is highly recommend you define the variables with names and comments to allow you to easily refer back to these values and identify their purpose. Including just this information is maybe sufficient to allow the disk to be used by other Operating Systems for saving or reading files.  

```assembly
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
```

The inline comments in this example explain most of the fields. They can loosely be categorised into fields which describe the physical drive (BytesPerSector; TotalSectors; SectorsPerTrack; NumberOfHeads; DriveNumber) values with describe the file system (SectorsPerCluster; TotalFATs; MaxRootEntries; SectorsPerFAT) values for indicating reserved space (ReservedSectors; HiddenSectors) and a number of values which are either purely informational (eg. VolumeID) or defined to fixed values based on the FAT specification. The values which describe the physical disk generally take values which are consistent with those required by interrupt 0x13.  

The field you need to pay attention to is Reserved Sectors. The minimum value for this field is 1, but if your bootloader spans multiple sectors ensure you update this value to reflect the number of sectors reserved for your bootloader. This can easily be figured out by taking the size of your second stage binary in bytes, dividing by 512 and rounding up.  

*NOTE: The text fields are a fixed length. If you change the contents ensure you add or remove space characters to maintain the fields original length*  

### Initialising the FAT table  
Often just adding the boot sector parameters is enough to make the disk recognised. Especially if your bootloader is entirely contained within the first sector and you have pre-formatted the drive. Even when that is not the case I have usually found the disk to work without further steps provided the drive has been zeroed. However, officially the first two entries of the FAT table are used to store additional information by the filesystem. The start of the first entry describes the drive type, while the start of the second entry is used to indicate the filesystems status.  

Entry 1: Contains the media descriptor (as used in the boot sector parameter table)  
- Format: Media descriptor code, with all preceding bits set to 1 (F in hexadecimal).  
- *FAT16:* FFF0h or in binary 1111111111110000b  which is stored as 0000111111111111  
- *FAT12:* FF0h or in binary 111111110000b which is stored as 000011111111  
This inversion of the bit order is due to x86 computers being little endian. If you are not confident how this works I recommended pausing and looking up endianess. *NOTE: For FAT16 it is more likely the media descriptor F8 would be used, indicating a fixed, non removable, disk.*  

Entry 2: Contains information on the filesystem condition  
- Format: First bit: 0=Dirty, did not unmount cleanly; Second bit:0=Errors found when last mounting disk; All other bits=1.  
- *FAT16:* FFFFh if clean; FF7Fh if not unmounted correctly; FFBFh if the filesystem has errors; FF3Fh if both.
- *FAT12:* FFFh (Note the filesystem condition flags aren't usually used for FAT12 filesystems)

These values can be easily added to an assembly file and compiled to create an empty FAT table ready for writing to a disk if you find it is required, or if you want to ensure you are adhering to the FAT standard. However, as their isn't a 12bit data type for FAT12 you will probably need to write the values using 3 8bit bytes.

```assembly
[BITS 16]       ; Informs the compiler that 16bit machine code is required.  
[ORG 0x0000]    ; Origin, informs the compiler where the code is going to be loaded in memory.  

MediaDescriptor  db  0xF0  ; Media descriptor (as used in the boot sector parameter table)  
FilesystenFlags  db  0xFF  ; FF for clean. F7 for not correctly mounted etc.  
Filler           db  0xFF  ; Always FF to set remaining bits in the second FAT entry to 1.  

times 512-($-$$) db 0 ; Fills the rest of the sector with zeros.  
```

*Note: This creates a single sector, the FAT table is likely larger than 1 sector. If you want to explicity zero out the rest of the FAT table space multiply the FAT size in sectors by the sector size (512) and use this value instead.*  

### Testing the disk  
First write your bootloader to the disk:
- Create a disk image or format a physical disk.  
- Compile and write to disk the bootloader file(s).  
- *If required* write the FAT table to the disk.  

Remount the disk, or disk image and try writing a file to the disk. In Linux with a disk image this can be done using:  
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
The first step in loading the root directory table is to first calculate it's position and size. This could be done once and hard coded, however it is relatively easy to calculate. Additionally by calculating this and similar values required later it will be easier to adapt the code to accommodate any changes later.  

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

```assembly
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
mov ax,[MaxRootEntries]         ; Move the first value to the arithmetic register (AX)  
mov cx, 32                      ; Move the multiplication factor (bytes per entry) into a register  
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
```

This is a comprehensive example storing the results into memory variables. If you are creating a minimalistic driver and don't anticipate the values in the boot sector parameter table to change you could calculate the values and write them into the code directly or perform the above calculation but exclude the lines which round up the sector number after the division.  

Finally the root table can be loaded into a free space in memory. The instructions for performing this is covered in the previous addressing sectors and loading sectors tutorials and won't be covered here. Because the code execution isn't moving to this memory location it's important to ensure you choose a memory offset that doesn't overlap with your executing code. To simplify the process I recommend keeping the segment registers the same where possible.  

```assembly
mov ax, [RootStart]            ; Move the LBA address to ax  
mov cx, [RootSize]             ; Move the table size into cx  
mov bx, 0x1000                 ; Memory offset to load sectors into  
call readsectors               ; Procedure to load the sectors into memory  
```

This example code doesn't perform any error checking but should demonstrate the procedures required to load multiple sectors into memory, utilising the functions described in the previous addressing sectors tutorial.  

### Looking up a filename in the root directory table  
With the root directory table loaded into memory it is now ready to be searched to find an entry that matches the filename of the kernel, or another file you want the details of. Each entry is 32 bytes with the filename taking up the first 11 of those bytes. *The period in the filenames is not stored and is only used to separate the filename from the extension. I.E. "FILE.TXT -> "FILE    TXT".* Which means a search can be done by comparing 11 bytes, moving along to the start of the next entry then comparing again until all entries have been checked.

An example of this is:  

```assembly
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
add di, 0x0020                  ; Add 32 to the value in DI (Start of next entry)  
loop SearchLoop                 ; Loop decreases cx by one and jmps, unless cx == 0 then it stops looping.  
; File has not been found, you may want to display an error message  
jmp End                         ; Ignore the code to run on success  
FoundFile:                      ; File has been found  
; Add code to display a message or load the file etc.  
End:  
```

*Note: replace the offset of the first entry to reflect the offset you have loaded the root directory table into.*

This example introduces a couple of new instructions like rep cmpsb and loop, with there use described in the comments. Otherwise the code is fairly self explanatory. This code snippet doesn't perform any action when a file is found, or not found. It is recommended that you take this code and experiment with adding success and failure messages. However take care to preserve the value in DI, as this contains the offset in memory for the matching root table entry and is needed to lookup additional details on the file.  

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

```assembly
FATSize dw 0             ; Variable to store the FAT size  

; Calculate the size of the FAT tables  
xor ax,ax                ; Zero AX to remove any values currently present    
mov al, BYTE [TotalFATs] ; Move the number of FAT tables into the arithmetic register (AL)  
mul WORD [SectorsPerFAT] ; Multiply the number of FAT tables by their size in sectors    
mov WORD [FATSize], ax	 ; Store the result in a memory variable  
```

In the example above the size of the FAT table region is stored in a variable, but it could be stored to the stack or in an unused register.

The FAT tables can then be loaded into memory in the same way as the root directory table.

```assembly
mov ax, [ReservedSectors]      ; Move the LBA address to ax  
mov cx, [FATSize]              ; Move the table size into cx  
mov bx, 0x1000                 ; Memory offset to load sectors into  
call readsectors               ; Procedure to load the sectors into memory  
```

The memory location used can be the same as the root directory table, when writing code for the bootloader, provided the number of the first cluster of the file has been already looked up and stored.

*The error handling of the readsectors code (from a previous guide) could be modified to take advantage of the redundant FAT table, if present, ensuring at least one FAT table is loaded if possible. However this is not covered as part of this guide.*

An alternative to loading the entire FAT region into memory is to only load up the sector containing the FAT entry needed. However this method of FAT loading requires additional calculations to determine which sector to load and the memory location of the FAT entry, additionally for larger files this may also require multiple disk reads to load different part of the FAT table. To keep this guide simple this approach isn't covered in this guide, preferring to instead load the entire table.

### Loading a file using the File Allocation Table
With the FAT table loaded into memory it can be accessed to identify the next cluster to load, or if the loading of the file should halt due to reaching the end of the file or encountering a bad sector. While the principles are the same for FAT12 and FAT16 filesystems the differences in entry size makes accessing the FAT table slightly different. Particularly for FAT12 filesystems, as there there isn't a 12bit data structure.  

The first cluster number has been provided by the root directory table, the first step is to load the contents of the associated FAT entry and check if the cluster is a bad sector. Depending on how your driver is configured you may want to either halt the loading of the file if a bad sector is indicated or displaying a warning before attempting to load the sector.

```assembly
; Load the contents of a FAT entry  
FATmemorylocation dw 0x1000   ; Change to reflect where the FAT is loaded in memory  
FileFirstCluster  dw 0        ; Memory variable storing the file's first cluster number  

...   ; Load the FAT table into memory (see previous section)  
...   ; Look up the Root Directory Entry value using the root directory table (covered previously)  
; The first cluster number is 2bytes (a word) stored 26 bytes into the entry (or 0x1A)  
mov ax, WORD [di + 0x001A]
mov [FileFirstCluster], ax

; Lookup the contents of the FAT entry  

mov ax, [FileFirstCluster]  ; Load into the arithmetic register the first cluster number  
LoadFATEntry:               ; Start of FAT entry checking loop  

; -- FAT16 --  
push ax                     ; Preserve the current cluster number  
mov cx, 2                   ; Bytes per cluster entry (2)  
mul cx                      ; Multiply the cluster by the bytes per cluster to calculate the offset  
mov bx, [FATmemorylocation] ; Load the memory location of the FAT into a register  
add ax, bx                  ; Add the offset to the FAT table start location in memory  
                            ; Alternative would be add ax, WORD [FATmemorylocation]  
mov dx, WORD [ax]           ; Read the contents of the FAT entry into a register  
pop ax                      ; Restore the current cluster number  

; -- FAT12 --  
push ax                     ; Preserve the current cluster number  
mov cx, ax                  ; Bytes per cluster entry (1.5), so  
shr cx, 0x0001              ; divide cx by 2 (could use div instruction instead of shirt right)  
add ax, cx                  ; Add the halved value of FileFirstCluster to ax to get 1.5 multiplcation  
mov bx, [FATmemorylocation] ; Load the memory location of the FAT into a register  
add ax, bx                  ; Add the offset to the FAT table start location in memory  
                            ; Alternative would be add ax, WORD [FATmemorylocation]  
mov dx, ax                  ; Read the contents of the FAT entry into a register  
                            ; Important: Check which bits contain the FAT content  
test ax, 0x0001             ; Test to see if the FAT entry was odd or even  
jnz .OddCluster             ; If odd jump to the OddCluster label  
.EvenCluster:               ; Even entries: FAT entry in bottom 12bits  
  and dx, 0x0fff            ; Mask out the top 4 bits (0000111111111111b)  
  jmp .Done                  ; Finished  
.OddCluster:                ; Odd entries: FAT entry in top 12bits  
  shr dx, 0x0004            ; Shift contents right by 4 bits. (1111111111110000b -> 0000111111111111b)  
.Done:   
pop ax                      ; Restore the current cluster number  

; -- FAT (both, with modifications to error codes) --  

; Check for invalid options or errors  
cmp dx,0000h                ; Check for free cluster (Empty)  
je EmptyError               ; Error message  
cmp dx,0ff7h                ; Check for bad cluster (change to fff7h for FAT16)  
je BadClusterError          ; Error message  
; Load the current cluster into memory  
...                         ; Call to a function to load the sector (covered later)  
; Check if the end of the file has been reached  
cmp dx,0x0fff               ; Check for end of chain (change to 0xffff for FAT16)  
je FinishedLoad             ; End FAT chain lookup  
; Reset and loop back round for the next cluster  
mov ax, dx                  ; Move the next cluster number into ax to reset for the next FAT entry  
jmp LoadFATEntry            ; Loop back to start  
FinishedLoad:               ; End of loop  
...  
EmptyError:                 ; Error handling  
...  
BadClusterError:  
...  
```

*Note: The number of the first file cluster doesn't need to be stored in a memory variable, it could be loaded into a register or retrieved from the stack. As before the choice of registers, except when AX is used for arithmetic instructions, is arbitrary. Due to the redundant tables, if present, any invalid FAT table entries, or even valid entries, could be compared with the redundant table to identify or resolve irregularities. However this topic is not covered as part of this guide.*

This code snippet shows the process of loading and checking File Allocation Table entries for both FAT12 and FAT16 filesystems. While the principles are the same the 12bit FAT entries require additional code to ensure the correct two bytes are loaded into a register and that only the 12bits relating to the FAT entry are examined. Loading the correct bytes requires multiplying the cluster number by the number of bytes per cluster:  
FAT12: |byte |byte |byte |byte |byte |byte |  
FAT12: |FATentry|FATentry|FATentry|FATentry|  
FAT16: |byte |byte |byte |byte |byte |byte |  
FAT16: |FATentry   |FATentry   |FATentry   |  

For FAT16 this is simple as FAT entry 0 start at 0x2, FAT entry 1 starts at 1x2 and so on, this is done using the 'MUL' instruction in the code example. FAT12 is marginally more complicated as the FAT entries don't line up with bytes, but the principle remains the same FAT entry 0 starts at 0x1.5, FAT entry 1 starts at 1x1.5 and so on. To ensure the correct bytes are included the multiplication should always round down for FAT12 entries. There are a couple of different ways of implementing this, however in the example here the cluster entry is divided by 2 using the shift right instruction 'SHR' which by moving all the bits in the register along 1 does the same as performing a division by 2, however 'DIV' could be used, and added back to the cluster value to get 1.5.  

With the correct bytes loaded into the register for FAT12 it is also a requirement to remove the bits that don't relate to the requested FAT entry:  
FAT12 Entres | 0000 0000 0000 | 1111 1111 1111 | 2222 2222 2222 | 3333 3333 3333 |  
FAT12 Bytes  | 00000000 | 1111 1111 | 22222222 | 33333333 | 4444 4444 | 55555555 |  
FAT12 Words  | 0000 0000  0000 0000 |  
                        | 1111 1111  1111 1111 |  
                                               | 2222 2222  2222 2222 |   
                                                          | 3333 3333  3333 3333 |  

Each even numbered cluster (FAT12 entry) is present in the first 12bits of the 2 bytes loaded into the 16bit register, while each odd cluster is loaded into the last 12bits of the 2 bytes loaded into the register. Therefore for even entries the bits need to be shifted to the right 4 places using the 'shr' instruction and odd entries need to have the first 4 bits set to zero using the 'and' instruction.

With the correct bytes loaded into a register and processed the values can be checked using the 'cmp' instruction, the example here only checks for empty or bad sectors instead of all invalid options but the principle is the same. If no errors are found and the end of the file hasn't been reached then the next cluster value is loaded into a register and the process loops back to the start.  


Loading the cluster is relatively easy but does require calculating the start position of the FAT filesystem data region, which comes immediately after the Root Directory table. The data region of the filesystem can be calculated by adding together the number of reserved sectors, the number of sectors used for the File Allocation Table and the number of sectors used for the Root directory table, all values calculated previously in this guide. Alternatively as we have already calculated the start position of the Root directory table and we know the data region starts after this table we can simply add the Root directory table size to it's start position.  

```assembly
; Calculate FAT data region  
DataStart dw 0                  ; Memory variable to store the start of the FAT data region  
mov ax,[RootStart]              ; Move into ax the start position  of the Root directory table  
mov cx,[RootSize]               ; Move into cx the root directory size  
add ax, cx                      ; Add ax (RootStart) to cx (RootSize)  
mov [DataStart], ax             ; Move the answer into the DataStart memory location  
```

With the start of the data region calculated the cluster numbers can be converted to sector addresses and loaded using the code described in previous guides on loading sectors using logical, LBA, addresses. The physical address for each cluster is easily calculated as they are simply addressed in order within the data region of the filesystem. However, it is important to remember the first 2 FAT entries are reserved and don't relate to physical clusters.

```assembly
; Load current cluster (provided in ax below)  
LoadLocation dw 0x1000              ; Set this variable to the desired memory location  
mov bx, [LoadLocation]              ; Memory location to load the file into  
...
LoadCluster:  
sub ax, 0x0002                      ; Subtract the 2 reserved clusters  
xor cx, cx                          ; Zero CX  
mov cl, BYTE [SectorsPerCluster]    ; Move the sectors per cluster value to cl  
mul cx                              ; Multiply AX by CX (ClusterNumber * SectorsPerCluster)  
add ax, WORD [DataStart]            ; Add the offset for the start of the data region  
...                                 ; Previously discussed code to load logical, LBA, sectors  
ret                                 ; Return to FAT entry loading loop  
```

This final small snippet of code converts the FAT cluster number into the logical, LBA, sector to load with the number of sectors to load present in cx or the memory variable SectorsPerCluster. Usually for FAT12 filesystems there is only 1 sector to load, but ideally the code should accommodate larger values. The memory location to load to would also need to be provided and incremented with each loaded sector, as discussed in the previous guides on loading sectors.  

This covers all the individual steps required to load a file from a FAT filesystem. Putting these code examples together with some of the previously covered guides should allow you to write a basic FAT driver to read files from the root directory of a FAT12 or FAT16 filesystem. A potential project to test this works would be to write a bootloader with a welcome message stored in a file and have this file opened, loaded into memory and the message displayed to the screen. However, you may need to take care to ensure your message uses characters compatible with the print function you are using to display the message.  

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
