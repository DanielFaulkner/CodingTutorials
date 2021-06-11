; Relevant guide: 2HelloWorldBL.md
; Description: A very simple bootloader which displays a coloured string
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

; Additional notes:
; Colour chart described at availble from https://en.wikipedia.org/wiki/BIOS_color_attributes

[BITS 16]      ; 16 bit code generation
[ORG 0x7C00]   ; Origin location

; Main program
main:          ; Label for the start of the main program

 mov ax,0x0000 ; Setup the Data Segment register. Data is located at DS:Offset.
 mov ds,ax     ; This can not be loaded directly it has to be in two steps.
               ; 'mov ds, 0x0000' will NOT work

 mov si, HelloWorld ; Load the position of the string into SI.
 ; The text attribute has been moved from the function to allow multiple calls with different settings
 mov bl,0x04        ; Text attribute 04 = Red text
 call PutStr        ; Call/start the procedure to display the string

 mov si, HelloWorld ; Load the position of the string into SI.
 mov bl,0x1E        ; Text attribute 1E = Yellow text on blue background
 call PutStr        ; Call/start the procedure to display the string

jmp $               ; Never ending loop

; Procedures
PutStr:        ; Procedure label/start
 ; Set up the registers for the interrupt call
 mov ah,0x0E   ; The function to display a character (teletype)
 mov bh,0x00   ; Page number

.nextchar      ; Internal label (needed to loop around for the next character)
 lodsb         ; I think of this as LOaD String Byte (may not be the official meaning)
               ; Loads DS:SI into AL and increases SI by one
 ; Check for end of string '0'
 or al,al      ; Sets the zero flag if al = 0
 jz .return    ; If the zero flag has been set go to the end of the procedure.
 int 0x10      ; Run the BIOS video interrupt
 jmp .nextchar ; Loop back around
.return        ; Label at the end to jump to when the loop is complete
 ret           ; Return to main program

; Data

HelloWorld db 'Hello World',13,10,0

; End Matter
times 510-($-$$) db 0 ; Fill the rest with zeros
dw 0xAA55             ; Boot loader signature
