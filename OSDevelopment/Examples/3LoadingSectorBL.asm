; Relevant guide: 3LoadingSectors.md
; Description: A simple bootloader which loads a sector into memory
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

[BITS 16]      ; 16 bit code generation
[ORG 0x7C00]   ; Origin location

; Main program

; Load a sector into memory
mov bx, 0x2000  ; Segment location to read into
mov es, bx      ;  this value cannot be loaded directly in the es register
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
