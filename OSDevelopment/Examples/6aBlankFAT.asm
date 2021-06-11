; Relevant guide: 6FilesystemsFAT12.md
; Description: An empty FAT table, with reserved values correctly set.
;
; All code run at the users own risk
; Written by Daniel Rowell Faulkner

; Note: In my experience usually this is not required.

[BITS 16]       ; Informs the compiler that 16bit machine code is required.
[ORG 0x0000]    ; Origin, informs the compiler where the code is going to be loaded in memory.

MediaDescriptor  db  0xF0  ; Media descriptor (as used in the boot sector parameter table)
FilesystenFlags  db  0xFF  ; FF for clean. F7 for not correctly mounted etc.
Filler           db  0xFF  ; Always FF to set remaining bits in the second FAT entry to 1.

; Change the number below to reflect the size of the FAT, to set the empty fields
; Size of FAT in sectors * Bytes per Sector
times 4608-($-$$) db 0 ; FAT size is 9 sectors. 9*512 = 4608


; Either uncomment the lines below for the redundant FAT table or write the compiled FAT table above to the disk a second time positioned immediately after the first FAT.

;MediaDescriptor  db  0xF0  ; Media descriptor
;FilesystenFlags  db  0xFF  ; Filesystem flags
;Filler           db  0xFF  ; Remaining byte set to 1

;times 4608-($-$$) db 0     ; Set the remaining FAT entries to 0
