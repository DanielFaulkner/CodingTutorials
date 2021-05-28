# Loading sectors

This tutorial provides instructions on how to load sectors from a floppy disk drive into memory for execution. While this guide is for use with a floppy disk drive, real or as an image, the procedure is similar for other storage devices.  

The BIOS contains an interrupt which can be called to perform the task of loading sectors from a disk into memory. However the BIOS addresses each sector by it's physical position I.E. head, cylinder and sector. The logical position can be converted into the physical address and is covered in another tutorial.  

## Disk addressing systems
**LBA:**  
Logical Block Addressing. This addressing system numbers each sector from 0 onwards, until the end of the disk. LBA addresses are commonly used because they don't require any knowledge of the physical disk layout and for their simplicity, with only one number to increment.  

**CHS:**  
Cylinder, Head and Sector addressing. This is a form of physically addressing the disk and is how the BIOS function interacts with the disk drive. However this requires an understanding of how the disk is constructed. How many sectors to a cylinder and how many heads etc.  
CHS addressing can be broken down into:  
- Sector = Block of data on the disk, other terms for this is a segment or track. This indicates where the disk should be rotated to.  
- Cylinder = This is represents how far in or out from the centre the data is.  
- Head = Which side of the disk the data is located. On hard drives their maybe multiple disk platters.  
*Note: Another common term is tracks. This is the data present in at a cylinder position that can be accessed by one head.*  

Our floppy disk contains sectors of 512bytes, there are 18 sectors to a track, 2 tracks to a cylinder accessed using 2 heads and 80 cylinders (head positions).  

This makes addressing the first 18 sectors reasonably easy as we are loading from the first cylinder and head and only incrementing the sector number. This allows smaller hobby operating systems which use less than 18 sectors to ignore the challenges of physical addressing, though it is not recommended.  

## Interrupt 0x13 - Loading from storage  
We will be using BIOS interrupt 0x13 to load the sectors from the disk into memory. This requires some values to be loaded into registers to instruct the interrupt function. They are described below.  

Which interrupt function:
- ah = 2, The interrupt function for reading a sector into memory.
Disk addressing registers:
- al = Number of sectors to read (To be safe I wouldn't cross the cylinder boundary)
- cl = Sector to start reading from  
- ch = Cylinder (aka track) to read from  
- dh = Head to read from  
- dl = Drive to read from  
Memory addressing registers:  
- bx = Offset to put the loaded data into  
- es = Segment to put the loaded data into  

One way of thinking of these values is like a postal address with a house number (sector), street name (cylinder), city (head) and country (drive).  

An example to load the first sector of a floppy disk would be:  
ah=2(Function number),  
al=1(1 sector to read),cl=1(First sector),ch=1(First cylinder),dh=1(First head),dl=0(default for floppy drive),  
bx=0(Offset of 0),es=1000h(Put the output at 1000h in memory)  

Upto sector 18 the only change required is to the register cl, after this sector you will need to start adjusting the other values related to the disk address.  

## Basic example
```assembly
; Code to load the second sector on the disk into memory location 0x2000:0x0000  
mov bx, 0x2000  ; Segment location to read into  
mov es, bx      ; This value cannot be loaded directly in the es register  
mov bx, 0	      ; Offset to read into  
mov ah, 02      ; BIOS read sector function  
mov al, 01      ; Read one sector  
mov cl,	02		  ; Sector to read  
mov ch,	01		  ; Track to read  
mov dh,	01		  ; Head to read  
mov dl,	00		  ; Drive to read  
int 0x13        ; Make the call to BIOS interrupt 0x13  
```

I recommend combining this interrupt with a function to convert LBA addresses to CHS addresses to avoid getting caught up with the more complicated physical disk addressing system, covered in a later tutorial.  

## Executing the loaded sector

Once you have the data loaded into memory you are likely to want to execute this code.  
In assembly language you do this by using the jmp instruction to set the registers (CS and IP) which instruct processor which instruction to execute next. It is also advisable you update the ds register with the new location before the jmp instruction.  
```assembly
mov ax, 0x1000     ; Update the data segment register  
mov ds, ax         ;  which cannot be performed directly  
jmp 0x1000:0x0000  ; CS becomes 0x1000 and IP becomes 0x0000.  
```
Normally for simple kernels you will leave the second part as 0x0000 and the first address should be equal to where you loaded the kernel in memory.  

## Complete bootloader
```assembly
[BITS 16]      ; 16 bit code generation  
[ORG 0x7C00]   ; Origin location  

; Main program  

; Load a sector into memory  
mov bx, 0x2000  ; Segment location to read into  
mov es, bx      ; This value cannot be loaded directly in the es register  
mov bx, 0       ; Offset to read into  
mov ah, 02      ; BIOS read sector function  
mov al, 01      ; Read one sector  
mov cl,	02      ; Sector to read  
mov ch,	01      ; Track to read  
mov dh,	01      ; Head to read  
mov dl,	00      ; Drive to read  
int 0x13        ; Make the call to BIOS interrupt 0x13  

; Configure the registers and execute the loaded code  
mov ax, 0x2000     ; Update the data segment register  
mov ds, ax         ;  which cannot be performed directly  
jmp 0x2000:0x0000  ; CS becomes 0x2000 and IP becomes 0x0000.  

; End Matter  
times 510-($-$$) db 0 ; Fill the rest with zeros  
dw 0xAA55             ; Boot loader signature  
```

Testing this code requires a something to be present in the sector being loaded. The hello world boot loader can be modified for this purpose.  
```assembly
[BITS 16]      ; 16 bit code generation  
[ORG 0x0000]   ; ORiGin location is 0000  

; Main program  
main:          ; Main program label  

mov ah,0x0E    ; Int 0x10 teletype function
mov bh,0x00    ; Page number
mov bl,0x07    ; Text attribute
mov al,65      ; This should places the ASCII value of a character into al.  
int 0x10       ; Call the BIOS video interrupt.  

jmp $          ; Start a continuous loop to stop code execution.  
```
The important change is to ensure the ORG value is updated to reflect the memory offset the code has been loaded into. Another change is the removal of the boot signature, which is not required after the first sector. The call to interrupt 0x10 will print the 'A' character to the screen (ASCII 65).  

Congratulations on getting to the point where your bootloader is now loading something into memory. Combining this tutorial with the Hello World bootloader you should now be able to have the bootloader display a message and load another sector which can also display a message.  

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
