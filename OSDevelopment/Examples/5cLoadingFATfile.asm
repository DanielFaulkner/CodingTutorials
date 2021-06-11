; Relevant guide: 5FilesystemsFAT12.md
; Description: A bootloader which loads a file from a FAT12 filesystem
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

; IMPORTANT: With these larger examples check the file size.
; If the compiled file is over 512 bytes then you MUST move some of the code into a second stage of the bootloader.
; This can be based on example 4, logical sector loading, using that bootloader example to load multiple additional sectors.
; If doing this ensure the FAT parameter table is in the first stage and the number of reserved sectors is updated.

[BITS 16]      ; 16 bit code generation
[ORG 0x7C00]   ; Origin location

jmp EndFATInfo
 OEM_ID                  db      "MYOS    "      ; 8 char ID of FAT software (I.E. MSDOS)
 BytesPerSector          dw      512             ; Sector size in bytes
 SectorsPerCluster       db      1               ; Sectors per cluster
 ReservedSectors         dw      1               ; Reserved sectors (Sectors used by the bootloader)
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

; Main program
main:          ; Label for the start of the main program

mov ax,0x0000  ; Setup the Data Segment register. Data is located at DS:Offset.
mov ds,ax      ; This can not be loaded directly it has to be in two steps.
               ; 'mov ds, 0x0000' will NOT work

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
rootsizeend:                    ; Label to jump to if there was no remainder
mov [RootSize], ax              ; Store the root table position in a variable
                                ; Or alternatively store to the stack or unused register

; Load the root directory table
mov ax, [RootStart]             ; Move the LBA address to ax
mov cx, [RootSize]              ; Move the table size into cx
mov bx, 0x1000                  ; Memory offset to load sectors into
call readsectors                ; Procedure to load the sectors into memory

; Check for the filename
mov cx, WORD [MaxRootEntries]   ; Number of entries to check
mov di, 0x1000                  ; First root entry (Offset)
SearchLoop:
push cx                         ; Preserve the counter for the number of entries remaining
mov cx, 0x000B                  ; Eleven character name (Num of times for rep to repeat)
mov si, FileName                ; Filename for comparison (Load into SI the string to compare to DI)
push di                         ; Save DI (Modified by cmpsb command)
rep cmpsb                       ; Repeat internally the compare string block instruction (DS:SI to ES:DI) CX times
pop di                          ; Restore DI
je FoundFile                    ; If equal the file has been found, jump to FoundFile label.
pop cx                          ; Restore the counter value
add di, 0x0020                  ; Add 32 to the value in DI (Start of next entry)
loop SearchLoop                 ; Loop decreases cx by one and jmps, unless cx == 0 then it stops looping.
; File has not been found, you may want to display an error message
jmp Error                       ; Ignore the code to run on success
FoundFile:                      ; File has been found
mov si, FoundMsg                ; Load the position of the string into SI.
call PutStr                     ; Call the procedure to display the string

; The value in DI is the offset to the file entry in the root directory table.
; This position + 26bytes (0x1A) is the location of the 2 bytes (word) with the first cluster number
mov ax, WORD [di + 0x001A]
mov [FileFirstCluster], ax

; Calculate the size of the FAT tables
xor ax,ax                ; Zero AX to remove any values currently present
mov al, BYTE [TotalFATs] ; Move the number of FAT tables into the arithmatic register (AL)
mul WORD [SectorsPerFAT] ; Multiply the number of FAT tables by their size in sectors
mov WORD [FATSize], ax	 ; Store the result in a memory variable

; Load the File Allocation Tables into memory
mov ax, [ReservedSectors]      ; Move the LBA address to ax
mov cx, [FATSize]              ; Move the table size into cx
mov bx, 0x1000                 ; Memory offset to load sectors into
call readsectors               ; Procedure to load the sectors into memory

; Calculate FAT data region position
mov ax,[RootStart]              ; Move into ax the start position  of the Root directory table
mov cx,[RootSize]               ; Move into cx the root directory size
add ax, cx                      ; Add ax (RootStart) to cx (RootSize)
mov [DataStart], ax             ; Move the answer into the DataStart memory location

mov ax, [FileFirstCluster]  ; Load into the arithmetic register the first cluster number
mov bx, [LoadLocation]      ; Location the file will be loaded to
push bx                     ; Preserve this register
call LoadFATEntry
pop bx                      ; Restore the location
jmp bx                      ; Jump to the loaded file

; Procedures

LoadFATEntry:               ; Start of FAT entry checking loop
push ax                     ; Preserve the current cluster value
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
pop ax                      ; Restore the current cluster value
; Check for invalid options or errors
cmp dx,0000h                ; Check for free cluster (Empty)
je Error                    ; Error message
cmp dx,0ff7h                ; Check for bad cluster (change to fff7h for FAT16)
je Error                    ; Error message
; Load the current cluster into memory
mov bx, [LoadLocation]      ; Memory location to load the file into
call LoadCluster            ; Call to a function to load the sector
; Check if the end of the file has been reached
cmp dx,0x0fff               ; Check for end of chain (change to 0xffff for FAT16)
je FinishedLoad             ; End FAT chain lookup
; Reset and loop back round for the next cluster
mov ax, dx                  ; Move the next cluster number into ax to reset for the next FAT entry
jmp LoadFATEntry            ; Loop back to start
FinishedLoad:               ; End of loop
ret

; Load current cluster
; Input: ax - Cluster number to load
LoadCluster:
sub ax, 0x0002                      ; Subtract the 2 reserved clusters
xor cx, cx                          ; Zero CX
mov cl, BYTE [SectorsPerCluster]    ; Move the sectors per cluster value to cl
mul cx                              ; Multiply AX by CX (ClusterNumber * SectorsPerCluster)
add ax, WORD [DataStart]            ; Add the offset for the start of the data region
call readsectors                    ; Procedure to load the sectors into memory
mov [LoadLocation], bx              ; Update the load location for the next cluster
ret                                 ; Return to FAT entry loading loop

; Generic very basic error handling function

Error:
mov si, ErrorMsg               ; Load the position of the string into SI.
call PutStr                    ; Call the procedure to display the string
jmp $                          ; Halt the bootloader

; PutStr
; Displays a string on the monitor
; Inputs: si - Location of message to display (ending in a 0)

PutStr:        ; Procedure label/start
 ; Set up the registers for the interrupt call
 mov ah,0x0E   ; The function to display a character (teletype)
 mov bh,0x00   ; Page number
 mov bl,0x07   ; Text attribute

.nextchar:     ; Internal label (needed to loop around for the next character)
 lodsb         ; I think of this as LOaD String Byte (may not be the official meaning)
               ; Loads DS:SI into AL and increases SI by one
 ; Check for end of string '0'
 or al,al      ; Sets the zero flag if al = 0
 jz .return    ; If the zero flag has been set go to the end of the procedure.
 int 0x10      ; Run the BIOS video interrupt
 jmp .nextchar ; Loop back around
.return:       ; Label at the end to jump to when the loop is complete
 ret           ; Return to main program

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
   JMP Error      ; Halt the bootloader
  .success:
   POP di         ; Restore the di register
   RET            ; Return to the main program

 ; LBA to CHS converter
 ; Input:  ax - LBA address
 ; Output: cl - Sector
 ;	       dh - Head
 ;	       ch - Cylinder

 LBAtoCHS:
  PUSH bx                     ; Copy the contents of bx to the stack to preserve the register state
  MOV dx,bx                   ; Store the LBA number in bx while using ax for a multiplication
  ; Calculate the cylinder
  MOV ax, [NumHeads]          ; Calculate the sectors per cylinder
  MUL WORD [SectorsPerTrack]  ;  Multiples the provided value by the value in ax, storing the result in ax
  DIV bx                      ; Divide LBA by the sectors per cylinder to calculate the cylinder value
                              ;  DIV stores the quotient in ax - Which is our cylinder number
  MOV ch, al                  ; Store the lower byte, containing the cylinder number in ch

  ; Calculate the head and sector (which start with the same division)
  MOV ax, bx                  ; Move the LBA value into the arithmetic register, ax
  DIV WORD [SectorsPerTrack]  ; LBA/SectorsPerTrack = Track number (ax) and Sector number (dx)

  ; Sector
  INC dx                      ; Add 1 to the remainder of the division, stored in dx
  MOV cl, dl                  ; Store the value into the cl register

  ; Head
  DIV WORD [NumHeads]         ; ax still contains the track number (quotient) from the previous division
  MOV dh, dl                  ; Move the remainder value into the register dl

  POP bx                      ; Restore the value in bx
  RET                         ; Return to the main program

; Data

FoundMsg  db 'File found',13,10,0
ErrorMsg  db 'Error encountered halting',13,10,0
RootStart dw 0               ; Variables to store the root directory table information
RootSize  dw 0
FATSize   dw 0               ; Variable to store the FAT size
FileName  db "FILE    TXT"   ; File name to search for
FileFirstCluster  dw 0       ; Memory variable storing the file's first cluster number
FATmemorylocation dw 0x1000  ; Change to reflect where the FAT is loaded in memory
DataStart dw 0               ; Memory variable to store the start of the FAT data region
LoadLocation dw 0x4000       ; Set this variable to the desired memory location

; End Matter
times 510-($-$$) db 0 ; Fill the rest with zeros
dw 0xAA55             ; Boot loader signature
