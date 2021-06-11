; Relevant guide: 3LoadingSectors.md
; Description: Some simple code to display a character. Used as a sector to load.
; See 0CompilingAndPhysicalMedia.md or 0TestingEnvironment.md for instructions on use.
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

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
