; Relevant guide: 5FilesystemsFAT12.md
; Description: The hello world bootloader but with the parameters at the start to make it FAT12 compatible
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

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

 mov ax,0x0000 ; Setup the Data Segment register. Data is located at DS:Offset.
 mov ds,ax     ; This can not be loaded directly it has to be in two steps.
               ; 'mov ds, 0x0000' will NOT work

 mov si, HelloWorld ; Load the position of the string into SI.
 call PutStr        ; Call/start the procedure to display the string

jmp $               ; Never ending loop

; Procedures
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

; Data

HelloWorld db 'Hello World',13,10,0

; End Matter
times 510-($-$$) db 0 ; Fill the rest with zeros
dw 0xAA55             ; Boot loader signature
