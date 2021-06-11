; Relevant guide: 2HelloWorldBL.md
; Description: A very simple bootloader which performs no actions
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

[BITS 16]    ; 16 bit code
[ORG 0x7C00] ; Code origin set to 7C00

main:        ; Main code label (Not really needed now but will be later)
jmp $        ; Jump to the start of the instruction (never ending loop)
             ; An alternative would be 'jmp main' that would have the same effect.

; End matter
times 510-($-$$) db 0
dw 0xAA55
