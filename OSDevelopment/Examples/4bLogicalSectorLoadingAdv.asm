; Relevant guide: 4AddressingSectors.md
; Description: A simple bootloader which loads a sector using its logical address
; Including additional error handling support for multiple sectors
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

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

; Read multiple sectors
; Input:  ax - LBA starting address
;         cx - Number of sectors to load
;         bx - Memory offset to write to
; REQUIRES Both readerror and LBAtoCHS functions to be present

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
  RET                           ; Return to the main program

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
  ; Usually you would add some code to display a warning here
  JMP $          ; Halt the bootloader
 .success:
  POP di         ; Restore the di register
  RET            ; Return to the main program

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

BytesPerSector   dw  512 ; Sector size in bytes
SectorsPerTrack  dw  18  ; Sectors per track
NumberOfHeads    dw  2   ; Number of heads (2 for a double sided floppy)
DriveNumber      db  0   ; Drive to load the sector from
LBA              dw  1   ; The logical sector address to access
                         ; A word is used as there are 2880 sectors to a floppy disk, more than a byte can address

; End Matter
times 510-($-$$) db 0 ; Fill the rest with zeros
dw 0xAA55             ; Boot loader signature
