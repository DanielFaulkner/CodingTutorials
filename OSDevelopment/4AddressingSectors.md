# Robust sector loading - Converting from LBA to CHS addresses

This simple tutorial covers the conversion between the logical LBA and physical CHS disk sector addressing methods. This builds on the loading sectors tutorial which covers the basics of drive access.   
This tutorial also covers the storing of values as either variables or on a stack.  

## Contents  
Introduction  
Equations  
LBA to CHS Assembly Example  
Introduction  Stacking - Creating a place to store values temporarily  
Actual Assembly example  

## Introduction  
A (mechanical) physical drive is made up of a magnetic platter (or disk) which stores the information and heads to read the information from the disk. To access data from the drive the BIOS needs to be informed where to position the head, and which head to use. This is the basis of the CHS address system.  

- Cylinder: Indicates how far from the centre to position the head.  
- Head: The top or bottom of the floppy disk.  
- Sector: A segment of the track (disk rotation).  
*Note: Track here refers to the sectors on one side of the disk at a set cylinder position.*  

When reading/writing to a disk by a physical, CHS, address the sector number is incremented until the end of the track is reached. At the end of the track the head is incremented to read/write to the track on the bottom of the floppy disk. The sector number is reset and increments until the end of the track is reached, at this point the cylinder number is incremented moving the head and the process starts again. I.E. (0,0,1)...(0,0,18),(0,1,0)...(0,1,18),(1,0,0)...  

When reading/writing to a disk by a logical, LBA, address only the sector number is used and goes from 1 up to the end of the disk. I.E. 1,2,3,4,5.....  

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
MOV ax, [NumberOfHeads]  ; Calculate the sectors per cylinder  
MUL [SectorsPerTrack]    ;  Multiples the provided value by the value in ax, storing the result in ax  
DIV [LBA]                ; Divide LBA by the sectors per cylinder to calculate the cylinder value  
                         ;  DIV stores the quotient in ax - Which is our cylinder number  
MOV [Cylinder], ax       ;  Store this value in the Cylinder variable   

; Calculate the head and sector (which start with the same division)  
MOV ax, [LBA]            ; Move the LBA value into the arithmetic register, ax  
DIV [SectorsPerTrack]    ; LBA/SectorsPerTrack = Track number (ax) and Sector number (dx)  

; Sector  
INC dx                   ; Add 1 to the remainder of the division, stored in dx  
MOV [Sector], dx         ; Store the value into the Sector variable  

; Head  
DIV [NumberOfHeads]      ; ax still contains the track number (quotient) from the previous division  
MOV [Head], dx           ; Move the remainder value into the Head variable  

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


CLI             ; Clear interrupts while we setup a stack  
MOV ax,0x0000   ; Set a location for the stack segment  
MOV ss,ax       ; Remember the segment registers can't handle immediate data  
MOV sp,0xffff   ; Use the whole segment (by starting at the end)  
STI             ; Turn the interrupts back on  


In the example given above instructions CLI and STI are used to turn off and start the interrupts. This is likely not required, but is sometimes seen added to ensure an interrupt isn't trying to access the stack while it is being changed. Then the stack segment is set to 0x0000 and the stack pointer to the last position possible, 0xffff.  

**Other considerations:**  
For our basic bootloader this is all that is required. However when writing your kernel if you are loading a lot to data into memory or onto the stack you might be concerned about the data and stack overlapping. One option is to increase the stack segment to point to a position higher in the memory, however this may make storing and retrieving memory addresses (pointers) more complicated due to the differences between the data and segment stack values. An alternative is to reserve some space using the RESB <number of bytes> instruction, as below.  

MOV AX, 0x0000       ; Setup the data and stack segments to the same value.
MOV DS. AX           ;
CLI                  ; Stop interrupts  
MOV SS, AX           ;
MOV SP, StackStart   ; Move the memory location of the StackStart label into the stack pointer  
STI                  ; Start interrupts  
StackEnd:            ; End of stack (lower memory address)  
RESB 4096            ; 4096 reserved bytes  
StackStart:          ; Start of stack (higher memory address)  

Using this arrangement you can ensure the memory space is reserved for the stack, providing it doesn't grow larger than the reserved space.  

## Advanced Assembly Example
(This will most likely work, but like any of my code I can't say for certain, being to lazy to test it at the time of writing this tutorial)

; Compile using NASM compiler (Again look for it using a search engine)
; Input: ax - LBA value
; Output: ax - Sector
;	  bx - Head
;	  cx - Cylinder

LBACHS:
 PUSH dx			; Save the value in dx
 XOR dx,dx			; Zero dx
 MOV bx, [SectorsPerTrack]	; Move into place STP (LBA all ready in place)
 DIV bx				; Make the divide (ax/bx -> ax,dx)
 inc dx				; Add one to the remainder (sector value)
 push dx			; Save the sector value on the stack

 XOR dx,dx			; Zero dx
 MOV bx, [NumHeads]		; Move NumHeads into place (NumTracks all ready in place)
 DIV bx				; Make the divide (ax/bx -> ax,dx)

 MOV cx,ax			; Move ax to cx (Cylinder)
 MOV bx,dx			; Move dx to bx (Head)
 POP ax				; Take the last value entered on the stack off.
				; It doesn't need to go into the same register.
				; (Sector)
 POP dx				; Restore dx, just in case something important was
				; originally in there before running this.
 RET				; Return to the main function


I hope this has helpped anyone with LBA to CHS translation.

If this has helpped you please send me an e-mail saying so. (I like compliments)

If you want to see new things in here please say, if you want to translate this into an other language please send me the new version so I can host that as an alternative. (I can translate copy's of this if requested but the altavista translater isn't quite perfected for large documents like this, and I would rather spend my time working on something else)

If you change this or make a copy on your website could you please keep my details with the file and could you please mention it to me some how.

Daniel Rowell Faulkner


###FROM Loading Sectors tutorial
## A complete example of such a procedure is:
; Load kernel procedure
LoadKern:
        mov ah, 0x02    ; Read Disk Sectors
        mov al, 0x01    ; Read one sector only (512 bytes per sector)
        mov ch, 0x00    ; Track 0
        mov cl, 0x02    ; Sector 2
        mov dh, 0x00    ; Head 0
        mov dl, 0x00    ; Drive 0 (Floppy 1) (This can be replaced with the value in BootDrv)
        mov bx, 0x2000  ; Segment 0x2000
        mov es, bx      ;  again remember segments bust be loaded from non immediate data
        mov bx, 0x0000  ; Start of segment - offset value
.readsector
        int 0x13        ; Call BIOS Read Disk Sectors function
        jc .readsector  ; If there was an error, try again

        mov ax, 0x2000  ; Set the data segment register
        mov ds, ax      ;  to point to the kernel location in memory

        jmp 0x2000:0x0000       ; Jump to the kernel

A complete example of a procedure including the LBA to CHS code (that procedure is in that tutorial for details on it, though this does use a different version of that procedure):
; Procedure ReadSectors - Reads sectors from the disk.
;  Input: cx - Number of sectors; ax - Start position
;  Output: Loaded file into: es:bx

ReadSectors:
.MAIN:                          ; Main Label
        mov di, 5               ; Loop 5 times max!!!
.SECTORLOOP:
        push ax                 ; Save register values on the stack
        push bx
        push cx
        call LBAtoCHS             ; Change the LBA addressing to CHS addressing
        ; The code to read a sector from the floppy drive
        mov ah, 02              ; BIOS read sector function
        mov al, 01              ; read one sector
        mov ch, BYTE [absoluteTrack]    ; Track to read
        mov cl, BYTE [absoluteSector]   ; Sector to read
        mov dh, BYTE [absoluteHead]     ; Head to read
        mov dl, BYTE [BootDrv]          ; Drive to read
        int 0x13                ; Make the BIOS call
        jnc .SUCCESS
        dec di                  ; Decrease the counter
        pop cx                  ; Restore the register values
        pop bx
        pop ax
        jnz .SECTORLOOP         ; Try the command again incase the floppy drive is being annoying
        call ReadError          ; Call the error command in case all else fails
.SUCCESS
        pop cx                  ; Restore the register values
        pop bx
        pop ax
        add bx, WORD [BytesPerSector]   ; Queue next buffer (Adjust output location so as to not over write the same area again with the next set of data)
        inc ax                          ; Queue next sector (Start at the next sector along from last time)
        ; I think I may add a status bar thing also. A # for each sector loaded or something.
        ; Shouldn't a test for CX go in here???
        dec cx                          ; One less sector left to read
        jz .ENDREAD                     ; Jump to the end of the precedure
        loop .MAIN                      ; Read next sector (Back to the start)
.ENDREAD:                       ; End of the read procedure
        ret                     ; Return to main program


				In order to use that you put the code into a loop and read one sector at a time like so:
				Get and set output location in memory,get start location,get number of sectors to load.
				Loop 'number of sectors to load' times:
				Run LBA to CHS (to convert the sector number in a head and cylinder)
				Run int 0x13 to load the sector from the LBA to CHS outputed data.
				Increase bx by the number of bytes per sector (512) ready for next sector.

				This code is often best put into a procedure and called as needed to load sectors off a floppy disk.
