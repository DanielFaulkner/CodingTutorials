; Relevant guide: 2HelloWorldBL.md
; Description: A very simple bootloader which displays a single character
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

; Additional notes:
; Alternative characters can be displayed using their ASCII values https://en.wikipedia.org/wiki/ASCII

[BITS 16]      ; 16 bit code generation
[ORG 0x7C00]   ; ORGin location is 7C00

;Main program
main:          ; Main program label

mov ah,0x0E    ; This number is the number of the BIOS function to run.
               ;  This function places a character onto the screen
mov bh,0x00    ; Page number (for our purposes leave this as zero)
mov bl,0x07    ; Text attribute (Sets the background and foreground colour)
               ;  07 = White text, black background.
               ; (Feel free experiment with other values)
mov al,65      ; This should places the ASCII value of a character into al.
int 0x10       ; Call the BIOS video interrupt.

jmp $          ; Put the bootloader into a continuous loop to stop code execution.

; End matter
times 510-($-$$) db 0 ; Fill the rest of the sector with zeros
dw 0xAA55             ; Boot signature
