FAT12 notes:

A FAT12 bootloader steps:
-------------------------
* A FAT12 formatted floppy! (Done easily using DOS/Linux etc)
* FAT12 table details
* Calculate some important FAT values:
- Root Directory Size - (Number of Root Entries * Bytes per entry) / Bytes per sector
- Root Directory Start Location - Reserved sectors + Fat sectors
- Data start location - Reserved sectors + FAT sectors + Root size
* Load the root directory into memory
* Scan through the root directory until the image is found (by 11 digit name)
* FAT calculations
- Work out FAT size - Total FATs * Sectors per FAT
- Work out FAT start location - Number of reserved Sectors
* Load FAT into memory
* Aquire the FAT cluster based kernel location (using the root dir search as a pointer to the FAT)
* Convert the FAT cluster address to LBA logical sector address
* Convert the LBA logical sector address to CHS hard ware based address
* Load kernel into memory

Now in more depth:
------------------

FAT formatted floppy disk:
To start with the floppy disk you choose to install the FAT12 boot loader to should first be
formatted using FAT12. This is the default for DOS (and common standard in most other Operating
Systems). From DOS just type "format a:" while a blank or unimportant floppy disk is in the
floppy drive.

FAT table:
The start of the FAT12 bootloader needs to contain what I call the FAT table.
This contains all the variables needed to do with the filesystem and is used by the file system
code. This is best done in the format:
"abc BYTE 0	; Comment"
Though it can be done like:
"BYTE 0"
But as you will discover you will almost certainly need to refer to those values within the code
implementing the filesystem. The reason that the variable names are not needed is due to the
position of the values being the important issue not the names identified with them.
This table is used to get details about the drive and things like the drive name/ID filesystem
etc. So to get details on any FAT disk you just read the first section of the disk and parse as
needed.
One major advantage of adding this table is that even if you only add this and nothing else you
will be able to read and write to the floppy disk as a normal FAT12 floppy.
Everything after this will be for actually using the FAT12 system within your bootloader.

Root directory calculations:
These calculations are quite important in loading and using the FAT table and will certainly
be needed if you plan to implement a FAT file system. I personally put the results of the
3 formulas into there own variables for refering to them: DataStart, RootStart and RootSize
Though some people may prefer to play around with the stack and/or registers rather than storing
the values in variables. Variables make it easier to read and understand and allows changes to
be made easier. Hence the reasons I recommend using them regularly. But it does use up disk
space!
* The root directory size can be calculated by values within the FAT table, the values used for
this calculation would be: Number of Root Entries, Bytes per entry and Bytes per sector.
The formula is: (NumOfRootEntries * BytesPerEntry) / BytesPerSector
In words: Times Number of root enters by the bytes per entry, then divide that value by bytes
per sector. (Ignore any remainder, that is used later)
* The root directory start location is calculated using values within the FAT table also, the
values used are: Number of reserved sectors, Total FATs and Sectors per FAT.
The formula is simply: NumReservedSectors + (TotalFATs * SectorsPerFAT)
(TotalFATs * SectorsPerFAT) equals the total number of FAT sectors.
* The data start location can be (yet again) calculated by values within the FAT table (by now
you should be relising how much easier it is to refer to the values by name than position).
The values used are: Reserved sectors, Total FATs, Sectors per FAT
Also the value of Root size aquired from an earlier calculation is needed.
The formula is: Reserved sectors + (Total FATs * Sectors per FAT) + Root size
(Total FATs * Sectors per FAT) is equal to The total number of FAT sectors.

Loading the root directory:
The next stage is to load the root directory into memory. I assume that you know about loading
sectors and LBA to CHS addressing from earlier documents I've written so I'll skip the details.
The values to input are simply to start loading from "RootStart" calculated in the earlier step
and to load the number of sectors calculated by the other calculation. ("RootSize" sectors)
So this stage if you understand my earlier documents should be quite easy.
The location to load the root directory into though can be of your own choosing (within reason).
As long as it doesn't disrupt the running of the boot loader or any important data previously
written to memory by your boot loader.

Browse the root directory:
In this stage, which is quite a bit harder you have to browse/search/scan (or what ever you want
to call it) the root directory for the entry corresponding to the kernel file name you have will
defined. It searchs by file name, an 11 digit name. Unlike DOS it is not a nice "kern.com"
style string but "KERN    COM", it HAS to be 11 digits long and the '.' is removed.
The search should have a fail safe so that it searchs a few times in case of a floppy error
during the first try to read the disk.
What is normally done is:
- Read 11 bytes into memory from start of Root Dir.
- Compare with the 11 digit file name string hard set in the boot loader code as a variable.
- If the compare is equal then stop and save the current Root Dir offset.
- Else add 20h (or 32 bytes I think), 11 bytes name then other details of the file filling the
  rest of the entry. Then loop round to the start, repeat until you run out of root dir.
Once the search has ended save/store the offset of how far into the root directory the file entry
was found for future reference/use.

FAT calculations:
These claculations are needed in order to load the FAT and load anything from the FAT file
system, if you per chance just wanted to get a list of files or search for a file but nothing
more you can get away with out implementing this section or anything more.
I recommend that you store these values into variables if you have the space, if not make sure
not to accidently delete them! (I use FATsize and FATstart in this document and my code)
* The FAT size is equal to (as I have mentioned before in a couple of places) the number of FATs
  (Yes there can be more than 1, but we won't be dealing with anything complicated) times by the
  number of sectors per FAT.
  So NumFATs * SectorsPerFAT equals Total number of FAT sectors aka FAT size.
  The values NumFATs and SectorsPerFAT you define in the FAT table at the start of the boot
  sector normally.
* The FAT start location is also very simple. It starts after any reserved sectors. Number of
  reserved sectors is defined in the FAT table at the start of the boot loader also.
  So formula wise: FATstart = NumReservedSectors
  (Yes that easy) Why the reserved sectors? Well some boot loaders may load up multiple stages
  so using more than the normal 1 sector of disk. There may be other things that could reserve
  sectors at the start but mostly it will be by elaborate boot loaders.

Loading the FAT:
Now we need to load the FAT into memory so we can look up the address of the entry in the root
directory. This is a very simple overlay style lookup (for lack of a better term). The offset
in the root directory when applied to the FAT will give the address of the root entry in FAT
format. (This later will need converting)
I will again assume that you have read the earlier documents on boot loaders and so understand
the principles of loading sectors from a disk using LBA format. (So read up on loading sectors
and LBA to CHS addressing conversion if you haven't done so yet, or if you need reminding)
You will have to load the sectors starting at FATstart (defined by the earlier stage) and of
FATsize (again defined by the earlier stage).
You propbably could load the FAT into any unused memory location but it is a bit wasteful of
memory and a lot more complicated, where as the easiest place to load it is over the top of the
root directory location. As we no longer will be needing the root directory in the boot loader.
If we did it would only take a second to reload it. This way though you save a lot of hassle with
trying to make pointers point to the right places.

Looking up the FAT cluster:
By following the previous stages correctly this stage is not really even needed! You don't have
to look up the cluster till the actual loading of the kernel. The offset into the root directory
is the first cluster! This makes things far easier, as there is no calculations needed here,
you just need to understand how important the offset into the root directory really is.
The root directory entry location offset is equal to the offset needed for the FAT address and
details.

Converting a FAT cluster to a LBA logical sector address:
This converts the FAT cluster based addressing into LBA based addressing. The difference is that
clusters can be of different sizes on different FAT based implementations where as LBA
addressing deals only with sectors, and CHS addressing deals with sectors, heads and tracks.
Formula to get the data location offset: LBA = (Cluster - 2) * sectors per cluster
Then also you have to add to this the datastart location to get the actual file data/content
address. This is done in an earlier stage in a calculation, DataStart.

Converting LBA addressing to CHS addressing:
This I have convered in an earlier document/tutorial. I recommend starting off by refering to
things by CHS addressing (Approx 18sectors per track normally), then LBA addressing then moving
onto filesystems. At least until you get the hang of how it all works and fits together. Also in
my opinion FAT12 is the easiest file system to start with (other than a custom made one) which
also has among the largest amount of support. So with the end product you will be able to read
and write to the disk like you would any other using a FAT12 driver. (Standard in microsoft OS's)

Loading the kernel:
This is by far among the harder sections, and not as easy as reading the FAT or root directory.
There are no calculations working out the size of the kernel. The start of the kernel though
has just been calculated by the earlier set of formulas.
So to work out the last cluster you have too look up each cluster in the FAT table to see if it
is the end cluster of the current chain or if it is data or if it is an unexpected empty cluster
(an empty cluster would mean that the file would probably be corrupted or similar).
The basic steps are:
- Move to the next cluster (Harder than it sounds, formula is: (Current*1.5) read FAT table,
  if odd shift right 4 bits, if even mask out top 4 bits)
- Check FAT cluster details: (The data just read from the FAT)
-- If Empty code and display a corrupted/incomplete file message (Code num: 0000h)
-- If Bad cluster code display an error message (Code num: 0ff7h)
-- If End of chain/file code display a complete/loaded file message (Code num: 0fffh)
-- If Data code move onto the next cluster (Code num: Address to next cluster)
- Convert FAT to LBA addressing
- Load the number of bytes per cluster (BytesPerCluster defined in the FAT table)
- Jump round to the start
This is more complicated in the implementation than it sounds here (at least when you are trying
to fit it all into 1 sector normally) but that is the simple version which should get the major
implementation points across.

In all the above detailed descriptions it goes into varying depths and the code behind it is
either easier or harder to understand than the description of the process.
By following those points though you should get pretty near to a working implementation. If not
a working implementation.

I don't intend you to learn purely from here but to use this as a guide line to know what is
needed to implement a FAT12 system.

Examples:
---------
All the examples are simple cut's and pastes from my own boot loaders. The source of my
boot loaders contain extra comments with the input and output of each procedure/section.
The source to look at is: Bootloader Ver 0.5
This code may be dependant upon earlier code or values stored else where in my bootloader.
The general idea is not to cut and paste my code unless you understand what it does properly.
And remember I prefer it if you don't steal my code without notifying me.

* FAT12 table:

        OEM_ID                  db      "DFOS    "      ; 8 char sys ID
        BytesPerSector          dw      512             ; Sector size in bytes
        SectorsPerCluster       db      1               ; Sector per cluster
        ReservedSectors         dw      4               ; Reserved sectors (This I think for this should become 2 for the boot strap, was 1)
        TotalFATs               db      2               ; Number of fats
        MaxRootEntries          dw      224             ; Root directory entries
        TotalSectorsSmall       dw      2880            ; Total Sectors
        MediaDescriptor         db      0F0h            ; Format ID (FAT12 ID number)
        SectorsPerFAT           dw      9               ; Sectors per FAT
        SectorsPerTrack         dw      18              ; Sectors per track
        NumHeads                dw      2               ; Number of heads (2 as double sided floppy)
        HiddenSectors           dd      0               ; Special hidden sectors
        TotalSectorsLarge       dd      0               ; More sectors
        DriveNumber             db      0               ; Drive Number (Primary Floppy is normally 0)
        Flags                   db      0               ; Reserved
        Signature               db      41              ; Boot signature
        VolumeID                dd      435101793       ; Volume serial number
        VolumeLabel             db      "NO NAME    "   ; Volume label (11 bytes)
        SystemID                db      "FAT12   "      ; File system (8 bytes)

* Calculate some important FAT values:
- Root Directory Size - (Number of Root Entries * Bytes per entry) / Bytes per sector

	xor ax, ax			; Zero registers
	xor cx, cx
        mov ax,[MaxRootEntries] 	; Move value to register to work on. ax=Arithmatic
        mov cx, 32      		; Move value to multiply into register
        mul cx          		; Multiply
        div WORD [BytesPerSector]    	; Divide
        mov [RootSize], ax      	; Put the value into a nice storage area for a bit

- Root Directory Start Location - Reserved sectors + Fat sectors

	xor ax,ax			; Zero AX for next calculation
        mov al, BYTE [TotalFATs]        ; Load up number of FAT tables (/info) into AL
        mul WORD [SectorsPerFAT]        ; Multiply AL by the number of sectors per FAT table (/info)
        add ax, WORD [ReservedSectors]  ; Add to the FAT total (AX) the number of reserved sectors
        mov [RootStart], ax             ; Put the start of the root address into RootStart variable

- Data start location - Reserved sectors + FAT sectors + Root size

        mov cx,[RootSize]               ; Mov the root size into CX
        add ax, cx			; Add ax (RootStart) to cx (RootSize)
	mov [DataStart], ax             ; Move the answer into DataStart

* Load the root directory into memory

	mov ax,[RootStart]		; Start location of the root directory
	mov cx,[RootSize]		; Number of sectors to load
	mov bx,0x1000			; Offset of location to write to (es:bx)
	call ReadSectors		; <- Read root directory sectors

* Scan through the root directory until the image is found (by 11 digit name)

	mov cx, WORD [MaxRootEntries]	; Load the loop counter
	mov di, 0x1000			; First root entry (Offset)
	SearchLoop:
	push cx				; Save counter value
	mov cx, 0x000B			; Eleven character name (Num of times for rep to repeat)
	mov si, KernelName		; Kernel image to find (Load into SI the string to compare to DI)
	push di				; Save DI (Modified by cmpsb command)
	rep cmpsb			; Repeat internally the compare string block instruction (DS:SI to ES:DI) CX times
	pop di				; Restore DI
	je FoundKernel			; If equal jump to load kernel.
	pop cx				; Restore the counter value
	add di, 0x0020			; Add 32 to the value in DI (Next FAT block start)
	loop SearchLoop			; Loop dec's cx by one and jmps, unless cx == 0 then it stops looping.
	jmp SearchError			; Jump to the search error message

	FoundKernel:
        mov     dx, WORD [di + 0x001A]
        mov     WORD [KernelAddress], dx                  ; file�s first cluster

* FAT calculations
- Work out FAT size - Total FATs * Sectors per FAT

	xor ax,ax		; Zero AX
	mov al, BYTE [TotalFATs]; Move TotalFAT's into position
	mul WORD [SectorsPerFAT]; Multiply by SectorsPerFAT
	mov WORD [FATsize], ax	; Move into memory variable

- Work out FAT start location - Number of reserved Sectors

	xor ax,ax			; Zero AX
	mov ax, WORD [ReservedSectors]	; Move ReservedSectors into ax (This is the FATstart location)

* Load FAT into memory

	mov cx, WORD [FATsize]	; FAT table size
	mov bx,0x1000		; Offset of memory location to load to
	call ReadSectors	; Read sectors procedure

* Calculate the next cluster and get the cluster details from the FAT (This is a procedure used
  else where)

NextCluster:
	mov cx, ax			; Copy current cluster
	mov dx, ax			; Ditto again
	shr dx, 0x0001			; Divide dx by 2
	add cx, dx			; CX = 1.5
	mov bx, 0x1000			; Load the FAT location
	add bx, cx			; Add the calculated offset to the FAT location (Index into FAT) bx = FAT+calculated offset
	mov dx, WORD [bx]		; Read two bytes from FAT (a word)
	; Odd even test
	test ax, 0x0001			; Test to see if the cluster was odd or even (Seems to be the old cluster rather than the just calculated value!)
	jnz .OddCluster			; If not a zero ending cluster:
	.EvenCluster:
		and dx, 0x0fff		; Mask out the top 4 bits (0000111111111111b)
		jmp .Done		; Carry on to next section
	.OddCluster:
		shr dx, 0x0004		; So shift right by 4 bits. (1111111111110000b -> 0000111111111111b)
	.Done:
		mov ax, dx		; Move result to ax
		ret			; Return


* Calculate the LBA address from the FAT address (Procedure)

FATtoLBA:
	sub ax, 0x0002				; Subtract 2 from ax (Not sure why yet)
	xor cx, cx				; Zero CX
	mov cl, BYTE [SectorsPerCluster]	; Move SPC to cl
	mul cx					; Multiply AX by CX (FAT*SectorsPerCluster)
	add ax, WORD [DataStart]		; Base data sector
	ret					; Return

* Convert the LBA logical sector address to CHS hard ware based address
Please look at one of my earlier documents on this.

* Load kernel into memory (Combines all this)
	push es		; Save es
	mov bx, 0x3000	; Destination location
	mov es, bx	; Segment
	mov bx, 0x0000	; Offset
	push bx		; Save bx
	LoadKernelImage:
	xor ax, ax
        mov     ax, WORD [KernelAddress]                  ; cluster to read
        pop     bx                                  ; buffer to read into
        call    FATtoLBA                          ; convert cluster to LBA
	mov [KernelAddressLBA], ax
	mov ax, [KernelAddressLBA]
        xor     cx, cx
        mov     cl, BYTE [SectorsPerCluster]        ; sectors to read
        call    ReadSectors
        push    bx
     	; compute next cluster
	; Reading the FAT
	xor ax, ax
	mov ax, WORD [KernelAddress]	; Current Location
	call NextCluster		; Work out the next cluster
	mov WORD [KernelAddress], ax		; The new cluster value is stored in the variable.
	; Test to see what value the next cluster contains.
	cmp ax,0000h		; Free cluster (Empty)
        je .EmptyError          ; Error message
	cmp ax,0ff7h		; Is it a bad cluster?
        je .BadClusterError     ; Error message
	; Test to see if this is the end of the cluster chain:
	cmp ax,0x0fff		; End of chain? (0fff)
	je KernelJmp		; Jump to the loaded kernel
	jmp LoadKernelImage	; Loop back round to start
        .BadClusterError:               ; Short jumps needed initally.
                jmp BadClusterError     ; Jump to error handler
        .EmptyError:
                jmp EmptyError          ; Jump to error handler

All of my examples are cuts and pastes from version 0.5 of my bootloader. This is probably not
an ideal example as I have implemented some things in odd ways. But my bootloader does work
which is the important thing. If you do use any of my code (no matter how small) I would
appreciate being notified and my name mentioned with the source next to my code with a link to
my website/details. To use any of my code in a commercial product requires my permission however!

I hope this has helpped you with implementing FAT12 in a bootloader. (Though it can also with
some small changes be used within a kernel as a FAT12 driver)

If this has helpped you please send me an e-mail saying so. (I like compliments)

If you want to see new things in here please say, if you want to translate this into an other
language please send me the new version so I can host that as an alternative. (I can translate
copy's of this if requested but the altavista/google/etc translaters aren't quite perfected for
large documents like this, and I would rather spend my time working on something else)

If you change this or make a copy on your website could you please keep my details with the file
and could you please notify to me some how.

Daniel Rowell Faulkner
