# Robust sector loading - Converting from LBA to CHS addresses

This simple tutorial covers the conversion between the logical LBA and physical CHS disk sector addressing methods. This builds on the loading sectors tutorial which covers the basics of drive access.   
This tutorial also covers the storing of values as either variables or on a stack.  

## Contents  
Introduction  
Equations  
LBA to CHS Assembly Example  
Introduction  Stacking - Creating a place to store values temporarily  
Complete bootloader example  
Error checking  
Loading multiple sectors  

## Introduction  
A (mechanical) physical drive is made up of a magnetic platter (or disk) which stores the information and heads to read the information from the disk. To access data from the drive the BIOS needs to be informed where to position the head, and which head to use. This is the basis of the CHS address system.  

- Cylinder: Indicates how far from the centre to position the head.  
- Head: The top or bottom of the floppy disk.  
- Sector: A segment of the track (disk rotation).  
*Note: Track here refers to the sectors on one side of the disk at a set cylinder position.*  

When reading/writing to a disk by a physical, CHS, address the sector number is incremented until the end of the track is reached. At the end of the track the head is incremented to read/write to the track on the bottom of the floppy disk. The sector number is reset and increments until the end of the track is reached, at this point the cylinder number is incremented moving the head and the process starts again. I.E. (0,0,1)...(0,0,18),(0,1,0)...(0,1,18),(1,0,0)...  

When reading/writing to a disk by a logical, LBA, address only the sector number is used and goes from 0 up to the end of the disk. I.E. 0,1,2,3,4,5.....  

*Note when using a hard drive there maybe multiple platters and therefore multiple heads per cylinder.*  

## Equations  
The conversion between LBA and CHS can be performed with simple division. In the below formulas the '//' character represents the quotient and '%' represents the modulus, otherwise known as the remainder.  

As a quick example 11 divided by 4 = 2.75. The quotient is 2, the number of complete divisions and the remainder is 3.

CHS addresses can be calculated using the following formulas  
- Cylinder = LBA // (SectorsPerTrack * NumberOfHeads)  
- Head = (LBA // SectorsPerTrack) % NumberOfHeads  
- Sector = (LBA % SectorsPerTrack) + 1  

The head and sector formulas are very similar in this example, performing the same first division but using either the quotient or the remainder. The plus 1 increment of the sectors value is required because sector numbering starts at 1.   

An alternative way of writing the above formulas is given below.  
Cylinder = LBA/(SectorsPerTrack*NumberOfHeads) (Take quotient value)  
Head = (LBA/SectorsPerTrack)/NumHeads (Take quotient value)  
Sector = (LBA/SectorsPerTrack) Remainder value + 1  

*There can be variations in how these formulas are written depending on the source used to take into account when comparing different guides.*  

CHS formulas are usually based around one of these intermediate stages:  
LBA / Sectors Per Track:  
Quotient % Number of Heads = Head  
Remainder + 1 = Sector  

(LBA % (Number of Heads * Sectors Per Track)) / Sectors Per Track:  
Quotient = Head  
Remainder + 1 = Sector  

Regardless of which variation you use the results should be the same.  

## LBA to CHS Assembly Example
This is a functional snippet of assembly code, written for readability. However your final LBA to CHS function is likely to look quite different.  

```assembly
; Basic LBA to CHS conversion  
jmp LBACHS               ; Define constants in a region that is not executed  
SectorsPerTrack  dw  18  ; Sectors per track  
NumberOfHeads    dw  2   ; Number of heads (2 as double sided floppy)  
LBA              dw  1   ; The logical sector address to access  
Cylinder         dw  0   ; Reserved locations for storing the conversion results
Head             dw  0  
Sector           dw  0  

LBACHS:  
; Calculate the cylinder  
MOV ax, [NumberOfHeads]    ; Calculate the sectors per cylinder  
MUL WORD [SectorsPerTrack] ;  Multiples the provided value by the value in ax, storing the result in ax  
DIV [LBA]                  ; Divide LBA by the sectors per cylinder to calculate the cylinder value  
                           ;  DIV stores the quotient in ax - Which is our cylinder number  
MOV [Cylinder], ax         ;  Store this value in the Cylinder variable   

; Calculate the head and sector (which start with the same division)  
MOV ax, [LBA]              ; Move the LBA value into the arithmetic register, ax  
DIV WORD [SectorsPerTrack] ; LBA/SectorsPerTrack = Track number (ax) and Sector number (dx)  

; Sector  
INC dx                     ; Add 1 to the remainder of the division, stored in dx  
MOV [Sector], dx           ; Store the value into the Sector variable  

; Head  
DIV WORD [NumberOfHeads]   ; ax still contains the track number (quotient) from the previous division  
MOV [Head], dx             ; Move the remainder value into the Head variable  
```

This example makes use of the mathematical operators MUL and DIV to perform multiplications and division. These instructions act on the value in the register ax (arithmetic register), using the register or value provided. The result of the multiplication, and the  quotient of the division are stored back into ax. With the remainder of the division stored in dx. If you need to perform multiple calculations on the same input ensure you copy the result from ax and reset ax to the starting value for each maths instruction.  

This example also makes extensive use of memory variables, to get around the limited number of registers, and performs some simple mathematical operations.  
As this is the first time variables are used to this extent I will include a quick summary below.  

>Variable dw 0x1234  
>MOV ax, [Variable]  

Using the square brackets copies the values in the variable to the register. I.E. ax = 0x1234  

>Variable dw 0x1234  
>MOV ax, Variable  

This nearly identical version without the brackets moves the position of the variable in memory into the register ax. I.E. if the variable containing 0x1234 starts at position 0x0005 ax = 0x0005.  

>Variable dw 0  
>MOV [Variable], ax  

This final example copies the value in ax to memory position with the label Variable. I.E. Variable = 0x1234.  

When working with memory variables and transferring values into registers ensure the variable and the register are of equal size. So if a memory variable is defined as a word, 'dw', this should be used with a 16 bit register, I.E. ax,bx,cx,dx. It the memory variable is defined as a byte, 'db', this should be used with either the upper or lower 8 bits of the register, I.E. ah,al,bh,bl...  

Even with these relatively simple calculations it is obvious that the number of registers can become a limiting factor. Creating variables is one method to get around the issue, but this is not an elegant solution. An ideal LBA to CHS converter for a bootloader would return the cylinder, head and sector address in the registers needed to load the sector using interrupt 0x13 without needing to create additional temporary variables. Fortunately this can be done through the use of a stack and the PUSH and POP instructions.  

## Stacking - Creating a place to store values temporarily  

The stack can store values temporarily while performing calculations or even to transfer values between functions. This is accessed using two commands. PUSH <item> places the value onto the top of the stack and POP <location> takes the top item in the stack and places in the given location.  

The stack requires 2 registers:  
- SS or Stack Segment: The top of the stack.  
- SP or Stack Pointer: The location of the current stack item.   
*Note: BP is also used as part of the stack. However I will leave this for the reader to research.*  

Once the SS and SP registers have been assigned values the PUSH and POP instructions can be safely used. The stack pointer is then decreased each time new items are added to the stack. For example:  

>8  -    
>16 -   
>24 -   
>32 - Stack Pointer = 32  

>8  -  
>16 - Stack segment = 16  
>24 - Item 2 (1 byte)  
>32 - Item 1 (1 byte)

This is a very stylised example, showing a small empty stack and a stack with two 1 byte items present. The memory addresses are given down the left side. This should illustrate how the stack pointer starts large and becomes smaller as items are added.  

**Setting up the stack:**  

```assembly
CLI             ; Clear interrupts while we setup a stack  
MOV ax,0x0000   ; Set a location for the stack segment  
MOV ss,ax       ; Remember the segment registers can't handle immediate data  
MOV sp,0xffff   ; Use the whole segment (by starting at the end)  
STI             ; Turn the interrupts back on  
```

In the example given above instructions CLI and STI are used to turn off and start the interrupts. This is likely not required, but is sometimes seen added to ensure an interrupt isn't trying to access the stack while it is being changed. Then the stack segment is set to 0x0000 and the stack pointer to the last position possible, 0xffff.  

**Other considerations:**  
For our basic bootloader this is all that is required. However when writing your kernel if you are loading a lot to data into memory or onto the stack you might be concerned about the data and stack overlapping. One option is to increase the stack segment to point to a position higher in the memory, however this may make storing and retrieving memory addresses (pointers) more complicated due to the differences between the data and segment stack values. An alternative is to reserve some space using the RESB <number of bytes> instruction, as below.  

```assembly
MOV AX, 0x0000       ; Setup the data and stack segments to the same value.
MOV DS. AX           ;
CLI                  ; Stop interrupts  
MOV SS, AX           ;
MOV SP, StackStart   ; Move the memory location of the StackStart label into the stack pointer  
STI                  ; Start interrupts  
StackEnd:            ; End of stack (lower memory address)  
RESB 4096            ; 4096 reserved bytes  
StackStart:          ; Start of stack (higher memory address)  
```

Using this arrangement you can ensure the memory space is reserved for the stack, providing it doesn't grow larger than the reserved space.  

## Complete bootloader example  

Here is a complete, if minimal, bootloader implementing the LBA to CHS formula. Including the use of a stack for storing variables temporarily.  

```assembly
[BITS 16]      ; 16 bit code generation  
[ORG 0x7C00]   ; Origin location  

; Main program  

; Setup the data segment  
MOV ax,0x0000   ; Set a location for the data and stack segments  
MOV ds, ax      ; Copy this location to the data segment  

; Setup the stack to enable use of the PUSH and POP instructions  
CLI             ; Clear interrupts while we setup a stack  
MOV ss,ax       ; Remember the segment registers can't handle immediate data  
MOV sp,0xffff   ; Use the whole segment (by starting at the end)  
STI             ; Turn the interrupts back on  

; Load a sector into memory using the LBA to CHS function  

MOV ax, [LBA]            ; Move the LBA address to ax  
CALL LBAtoCHS            ; Change the LBA addressing to CHS addressing  
                         ;  Sets CL, CH and DH  
MOV bx, 0x2000           ; Segment location to read into  
MOV es, bx               ; This value cannot be loaded directly in the es register  
MOV bx, 0                ; Offset to read into  
MOV ah, 02               ; BIOS read sector function  
MOV al, 01               ; Read one sector  
MOV dl,	[DriveNumber]    ; Drive to read  
INT 0x13                 ; Make the call to BIOS interrupt 0x13  

; Configure the registers and execute the loaded code  
MOV ax, 0x2000     ; Update the data segment register  
MOV ds, ax         ;  which cannot be performed directly  
JMP 0x2000:0x0000  ; CS becomes 0x2000 and IP becomes 0x0000.  

; Procedures  

; LBA to CHS converter  
; Input:  ax - LBA address  
; Output: cl - Sector  
;	        dh - Head  
;	        ch - Cylinder  

LBAtoCHS:  
 PUSH bx                    ; Copy the contents of bx to the stack to preserve the register state  
 MOV dx,bx                  ; Store the LBA number in bx while using ax for a multiplication  
 ; Calculate the cylinder  
 MOV ax, [NumberOfHeads]    ; Calculate the sectors per cylinder  
 MUL WORD [SectorsPerTrack] ;  Multiples the provided value by the value in ax, storing the result in ax  
 DIV bx                     ; Divide LBA by the sectors per cylinder to calculate the cylinder value  
                            ;  DIV stores the quotient in ax - Which is our cylinder number  
 MOV ch, al                 ; Store the lower byte, containing the cylinder number in ch  

 ; Calculate the head and sector (which start with the same division)  
 MOV ax, bx                 ; Move the LBA value into the arithmetic register, ax  
 DIV WORD [SectorsPerTrack] ; LBA/SectorsPerTrack = Track number (ax) and Sector number (dx)  

 ; Sector  
 INC dx                     ; Add 1 to the remainder of the division, stored in dx  
 MOV cl, dl                 ; Store the value into the cl register  

 ; Head  
 DIV WORD [NumberOfHeads]   ; ax still contains the track number (quotient) from the previous division  
 MOV dh, dl                 ; Move the remainder value into the register dl  

 POP bx                     ; Restore the value in bx  
 RET                        ; Return to the main program  

; Data  

SectorsPerTrack  dw  18  ; Sectors per track  
NumberOfHeads    dw  2   ; Number of heads (2 for a double sided floppy)  
DriveNumber      db  0   ; Drive to load the sector from    
LBA              dw  1   ; The logical sector address to access  
                         ; A word is used as there are 2880 sectors to a floppy disk, more than a byte can address  

; End Matter  
times 510-($-$$) db 0 ; Fill the rest with zeros  
dw 0xAA55             ; Boot loader signature  
```

The function used here for the LBA to CHS conversion is slightly different from the simple example first introduced, storing the values directly into the correct registers for interrupt 0x13. This makes use of the stack to preserve the value in bx, not essential in this situation but good practice. Some of the move instructions may look different as instead of storing the entire register (ax,bx etc.) only the lower byte of the register is being stored (al,bl etc.).  

## Error checking  

When reading from physical floppy drives on occasion it's possible the sector won't be read correctly from the floppy disk. This is indicated by interrupt 0x13 returning the carry flag, which allows you to handle the error by attempting to read the disk sector again. A short code snippet is included below.  

```assembly
...
readsector:
INT 0x13         ; Call to interuppt 0x13 to read a sector from the drive  
JC readsector    ; If the carry flag has been set by INT 0x13 retry  
...
```

However with this short example it is possible the code could end up stuck in a loop in the case of a drive error. To work around this you could set a counter and break out of the loop to handle the error after a preset number of attempts.  

```assembly
...
INT 0x13         ; Call to interuppt 0x13 to read a sector from the drive  
JC readerror     ; If the carry flag has been set by INT 0x13 retry  
...
readerror:       ; Handle read errors  
 PUSH di         ; Using the DI register as unused by INT 0x13, but preserving any values within  
 MOV di, 5       ; Number of attempts to try
 .readloop:       
  INT 0x13       ; Try to read the sector again  
  JNC .success   ; If there is a success go to the end of the function  
  DEC di         ; Else decrease the counter in di  
  JZ .fail       ; If the counter reaches zero and the Zero flag is set go to the failure code  
  JMP .readloop  ; Return to the start of the read loop  
 .fail:
  ; Add any error handling or error message processing here
 .success:
  POP di         ; Restore the di register  
  RET            ; Return to the main program  
```

This extended error checking example will try 5 times to run INT 0x13 before giving up.  

## Loading multiple sectors

These examples are all based around loading a single sector. If you are loading multiple sectors and want to apply this read error handling to each sector you could combine all of the above examples, into a loop incrementing the LBA address by one, the memory destination by 512 and decreasing the remaining sectors to load by one on each iteration of the loop.  

```assembly
...
; Setup registers as per the previou complete example  
; Including: bx = destination offset in memory, ax = logical address
; This example will store the number sectors to load in cx  
MOV cx, 5                      ; Number of sectors to load can instead be stored in cx  
CALL readsectors               ; Replace the call to INT 0x13 with a function call  
...
readsectors:                   ; Function to handle reads from multiple sectors  
 .start:
  PUSH cx                       ; Keep a record of the number of sectors to load
  PUSH ax                       ; Keep a record of the starting logical address  
  CALL LBAtoCHS                 ; Convert from logical to CHS addressing  
  MOV ah, 02                    ; Function to read a sector  
  MOV al, 01                    ; Only read one sector  
  INT 0x13                      ; Call to interrupt 0x13  
  JC readerror                  ; Handle any errors from the interrupt
  POP ax                        ; Restore the logical address
  POP cx                        ; Restore the number of sectors remaining  
  DEC cx                        ; Decrease the counter  
  JZ .end                       ; If the counter reaches zero end  
  INC ax                        ; Else: Increment the logical address  
  ADD bx,[BytesPerSector]       ; Increase the memory address for the next sector  
  JMP .start
 .end:
  RET                          ; Return to the main program  

BytesPerSector dw 512          ; Sector size in bytes
```

Combining the code snippets in this section with the previously given complete example should enable the creation of a robust method for reading data from a disk drive.  

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
