# REWRITE AND CONVERSION TO MARKDOWN SYNTAX IN PROGRESS  

## Assembly Language introduction

A place holder for a short (NASM) assembly primer for readers who are not able to purchase a book on Assembly, or are not intending to use the assembly for the majority of their hobby operating system development.  

ASM terms:
Registers - In simple terms memory/variables of a fixed size in the CPU
	  - In the code I'm writing the size is 16 bytes for each register.

(; <- is a comment sign)

ASM commands used:
The DIV command is very important in this function.
DIV <reg>		; Divides register AX by the register you enter as reg
			; Output value AX = Quotient DX = Remainder.
The MOV command is simple but used often.
MOV <Destination> <Source>    ; Move the Source to the destination.
The INC command is again simple but is needed.
INC <reg>		 ; Adds 1 to the register you pass to the command.
The XOR command is mostly used for turning a register to zero's. It compares each bit of two registers and if they are set the same outputs zero as the result.
XOR ax, ax		  ; This will zero ax (will work with any register)
The RET command is used to return to the main program.
RET			; Returns to the main program
PUSH <reg>		; Puts the register's value onto the stack
POP <reg>		; Restores a registers value using the value on the stack
MUL <reg>      ; Multiples AX by the register (or memory location) specified

[]'s means load thes value at memory location LBAvalue. Without the brackets the memory location is loaded. When loading values the datatypes should equal the register type. So a word 'dw' can be loaded into a ax,bx,cx,dx register. While a byte 'db' needs to be loaded into a smaller register space using ah,al,bh,bl and so on. These can also be used for storing value as variables.  

In order to learn more about Asm I suggest looking at the Art Of Asm website (The location changes and this may not be updated regularly so best to look for it in a search engine)
The book 'Assembly Language Step By Step' By Jeff Duntemann is also very usefull for beginners to Assembly Language programming.

And to find out more about the commands I put up look at the Intel Reference manual, also the NASM documentation has a reference section. (Quite likely similar documentation is also around else where)
