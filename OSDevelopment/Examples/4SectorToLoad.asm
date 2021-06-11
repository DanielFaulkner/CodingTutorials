; Relevant guide: 4AddressingSectors.md
; Description: Some simple code to display a string. Used as a sector to load.
; See 0CompilingAndPhysicalMedia.md or 0TestingEnvironment.md for instructions on use.
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

[BITS 16]      ; 16 bit code generation
[ORG 0x0000]   ; ORiGin location is 0000

; Main program
main:          ; Label for the start of the main program

 mov ax,cs     ; Setup the Data Segment register, by copying the code segment register.
 mov ds,ax     ; This can not be loaded directly it has to be in two steps.
               ; 'mov ds, 0x0000' will NOT work

 mov si, Message    ; Load the position of the string into SI.
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

Message db 'Sector loaded and executed successfully',13,10,0
