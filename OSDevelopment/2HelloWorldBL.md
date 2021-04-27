# Bootloader basics - Hello World

This tutorial walks through producing a simple Hello world boot loader.  

## Contents
Glossary  
Rules  
Int 0x10 details (Teletype function)  
Boot loader installation  
Empty boot loader  
Never ending loop boot loader  
Displaying a character boot loader  
Storing data  
Hello World bootloader

## Glossary
BIOS - Code which is built-in to the computer. This tests that the hardware is present and has some built-in functions that can be called using interrupts.  
Interrupts - Allows a built-in function/procedure to be called.  
Hexadecimal - 16base numbering system. Generally indicated by putting a 'h' after the number or a 0x before.
Decimal - Normal base 10 numbering system everyone is likely to be familiar with.  

## Rules
All bootloaders need to follow couple of key rules  

1) It MUST be 512bytes long!
This is because the BIOS will automatically load the first sector of the boot disk into the memory. (Boot disk is set in the BIOS, the normal setup is to have it boot from the floppy drive and failing that the hard drive).  

2) It MUST end with the bootloader signature, '55 AA'  

Where is the boot loader loaded to in memory?
In hexadecimal it is loaded to 7C00, 31744 in decimal.  
Why is this? The computer has a number of items stored in early memory which, as you advance in the hobby operating system development scene, you may go to learn more about.  

## INT 0x10
INT 0x10 is the BIOS video interrupt, a function provided by the BIOS which can be called to display characters to the screen.  

Using this interrupt requires some registers to be populated with the information you want to display.  
AH - 0x0E <- Teletype mode (This number must be used to tell the BIOS to put a character on the screen)  
AL - ASCII character to display  
BH - Page number (For most of our work this will remain 0x00)  
BL - Text attribute (For most of our work this will remain 0x07), change the value for different colours.  

Then once the registers are populated calling the interrupt will display a character on the monitor.  

## Installing a boot loader
**NOTE:** With the exception of the first boot loader, the code can be typed into a computer to follow along with the guide. However running all the examples is at the readers own risk.  

Also, for obvious reasons I advise against installing the boot loader over your current hard drives boot loader.  

**Requirements:**  
- An x86 CPU based computer (AMD or Intel).  
- A floppy disk to install the boot sector on if you want to run this on real hardware.  
- NASM to compile the source code. NASM can be downloaded for free from their [website](https://www.nasm.us/), and is included in most Linux distributions package repositories.  
Their are alternatives to using a floppy disk, which are not covered here. You may also want to try testing the code in an emulator such as Bochs, which is covered in a different tutorial.  

**Instructions:**  
- Step 1. Copy/Write the boot sector to a standard text file. (.txt/.asm/.s/etc ending doesn't matter)  
- Step 2. Type at the prompt: 'NASM filename.txt' this should output a compiled file.  
- Step 3. Check the compiled file is exactly 512 bytes.  
- Step 4. Install the boot loader to the first sector of the disk. (Varies per OS)  

*DOS:*  
Insert a blank floppy disk.  
DEBUG file <return>  
w 100 0 0 1  
q  

*Linux:*  
Insert a floppy but don't mount it.  
dd if=Bootloader bs=512 of=/dev/fd0  

- Step 5. Reboot leaving the floppy in the drive. If needed change the boot order in the BIOS to first boot from the floppy disk ('A') drive.  

## Empty boot loader:
**Do NOT copy and run**  

```assembly
; Starting boiler plate code  
[BITS 16]       ; Informs the compiler that 16bit machine code is required.  
[ORG 0x7C00]    ; Origin, informs the compiler where the code is going to be loaded in memory.  

; Your bootloader code here  

; End boiler plate code  
times 510-($-$$) db 0	; Fills the rest of the sector with zero's  
dw 0xAA55             ; Add the boot loader signature to the end   
```

*So what does this example do?*  
In short, nothing. At least nothing worth mentioning.  

The comments in the code explain each line. However I will briefly go over them here.  

The first 2 lines provide information the NASM compiler needs to produce a compatible executable file.  

The last 2 lines are a little more confusing however.  
times 510-($-$$) db 0  
This can be read as: Times 510-(Start of this Instruction - Start of program) with 0's  
$ stands for start of the instruction  
$$ stands for start of the program   

db stands for define (or declare) byte - a byte is 8 bits, a bit can be a 0 or a 1.  

dw 0xAA55  
This writes the boot signature, 55AA (hexadecimal), to the last two bytes of the boot sector. Without this signature the BIOS won't recognise this as a bootable disk.  
It is written this way round as X86 computers store values using the 'Little Endian' order, essentially reversing the order however a full explanation is beyond the scope of this guide.  

***I suggest that you don't try this boot loader as there is no code to execute, which could result in unexpected or undesirable behaviour.***  

## Never ending loop boot sector:

[BITS 16]    ; 16 bit code  
[ORG 0x7C00] ; Code origin set to 7C00  

main:	     ; Main code label (Not really needed now but will be later)  
jmp $	     ; Jump to the start of the instruction (never ending loop)  
	     ; An alternative would be 'jmp main' that would have the same effect.  

; End matter  
times 510-($-$$) db 0  
dw 0xAA55  

This bootloader puts the computer into a continuous loop. Which is not useful in any way and will display nothing, except any remaining BIOS booting messages. However, this boot loader is safe to try making and running yourself.  

The inline comments are fairly self explanatory, so lets continue with the next boot loader.  

## Displaying a character boot loader:

[BITS 16]	 ; 16 bit code generation  
[ORG 0x7C00]	 ; ORGin location is 7C00  

;Main program  
main:		 ; Main program label  

mov ah,0x0E	 ; This number is the number of the BIOS function to run.  
		 ;  This function places a character onto the screen  
mov bh,0x00	 ; Page number (for our purposes leave this as zero)  
mov bl,0x07	 ; Text attribute (Sets the background and foreground colour)  
		 ;  07 = White text, black background.  
		 ; (Feel free experiment with other values)  
mov al,65	 ; This should places the ASCII value of a character into al.  
int 0x10	 ; Call the BIOS video interrupt.  

jmp $		 ; Put the bootloader into a continuous loop to stop code execution.  

; End matter  
times 510-($-$$) db 0	; Fill the rest of the sector with zeros  
dw 0xAA55		; Boot signature  

This bootloader combines the previous basic bootloader with a call to an interrupt function, discussed earlier, to display a character to the screen. Once you have this working you can try different ASCII values or change the text attribute for alternative colours.  

However, duplicating this for each character you want to display is impractical. So the next couple of bootloader examples move onto storing and displaying a string.  

## Storing data:

If you have used assembly before you will be used to having defined text/code and data sections. Unfortunately this is handled differently in the boot loader.  

All data and procedures must be placed where they won't be executed as part of the bootloader. This is either at the start of the boot loader, with a jmp instruction used to skip them when the boot loader starts, or at the end at a position never executed by the bootloader.  
The choice is up to you, but I recommend using the end of the bootloader sector.  

[BITS 16]       ; 16 bit code generation  
[ORG 0x7C00]	; Origin of the program. (Start position)  

; Main program  
main:		; Put a label defining the start of the main program  

 call PutChar	; Run the procedure  

jmp $		; Put the program into a never ending loop  

; Everything here is out of the main program  
; Procedures  

PutChar:		; Label to call procedure  
 mov ah,0x0E		; Put char function number (Teletype)  
 mov bh,0x00		; Page number  
 mov bl,0x07		; Normal attribute  
 mov al,65		; ASCII character code  
 int 0x10		; Run interrupt  
 ret			; Return to main program  

; This data is never run, not even as a procedure  
; Data  

TestHugeNum dd 0x00	; This can be a very large number (1 double word)  
			;  Upto ffffffff hex  
TestLargeNum dw 0x00	; This can be a large number (1 word)  
			;  Upto ffff hex  
TestSmallNum db 0x00	; This can be a small number (1 byte)  
			;  Upto ff hex  

TestString db 'Test String',13,10,0	; This is a string (Can be quite long)  

; End matter  
times 510-($-$$) db 0	; Zero's for the rest of the sector  
dw 0xAA55		; Bootloader signature  

This bootloader behaves in the same way as the previous example. However the code to display a character has been converted into a function and along with some (unused) values is now stored after the region of code being executed.  

The main thing that will look unusual is the line:  
TestString db 'Test String',13,10,0  

How come it is only a byte (db)?  
Well it isn't, but TestString only stores the memory location not the data it self. And each item in the string can be stored in a byte. Think of this as TestString[byte|byte|byte...].  

The numbers at the end of the string are special characters.  
13 - ASCII for Character Return  
10 - ASCII for New Line  
(Character Return and New Line together makes the next string start on a new line)  
0 - Does nothing but will be used later as a marker for the end of the string  

The rest of the code you should recognise or understand from the comments.  

## Hello World bootloader:

[BITS 16]      ; 16 bit code generation  
[ORG 0x7C00]   ; Origin location  

; Main program  
main:		; Label for the start of the main program  

 mov ax,0x0000	; Setup the Data Segment register. Data is located at DS:Offset.  
 mov ds,ax	; This can not be loaded directly it has to be in two steps.  
		; 'mov ds, 0x0000' will NOT work  

 mov si, HelloWorld	; Load the position of the string into SI.  
 call PutStr	; Call/start the procedure to display the string  

jmp $		; Never ending loop  

; Procedures  
PutStr:		; Procedure label/start  
 ; Set up the registers for the interrupt call  
 mov ah,0x0E	; The function to display a character (teletype)  
 mov bh,0x00	; Page number  
 mov bl,0x07	; Text attribute  

.nextchar	; Internal label (needed to loop around for the next character)  
 lodsb		; I think of this as LOaD String Byte (may not be the official meaning)  
		; Loads DS:SI into AL and increases SI by one  
 ; Check for end of string '0'  
 or al,al	; Sets the zero flag if al = 0  
 jz .return	; If the zero flag has been set go to the end of the procedure.  
 int 0x10	; Run the BIOS video interrupt  
 jmp .nextchar	; Loop back around  
.return		; Label at the end to jump to when the loop is complete  
 ret		; Return to main program  

; Data  

HelloWorld db 'Hello World',13,10,0  

; End Matter  
times 510-($-$$) db 0	; Fill the rest with zeros  
dw 0xAA55		; Boot loader signature  


Congratulations! If you are following along you should now have a bootloader which can display the message 'Hello World' to the screen. From this point you can try changing the message, displaying multiple messages or changing the colour of the message.  

This last example introduced a few new assembly commands. If you are not familiar with assembly this bootloader is combining the lodsb instruction with a loop to create a basic 'print' function.  
- Ensure the registers DS:SI contains the location of the string.
- Setup the register values for calling Interrupt 10.
- Start loop:
- - Load the byte (character) at position DS:SI into the register AL and increment SI by 1 (lodsb).
- - Set the zero flag if the byte just loaded was a zero (or).
- - - If the zero flag is set jump to the end of the function (jz).
- - Display the character in register AL to the screen (int 0x10).
- - Loop back to the start (jmp).

I hope this tutorial has helped you to understand the basics of boot sectors.  

## Author  
Written by Daniel Rowell Faulkner.  
All code and terminal commands are run at the readers own risk.  
