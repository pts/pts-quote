; -*- coding: utf-8 -*-
;
; quote.nasm: PotterSoftware Quote Displayer V2.63 (NASM source code)
; (C) 2022-03-30 by EplPáj of PotterSoftware, Hungary
; based on quote.nasm V2.62
;
; Compile it with NASM 0.98.39 .. 2.13.02 ...:
;
;   $ nasm -O0 -f bin -o quote63n.com quote63.nasm
;
; Alternatively, compile it with Yasm 1.2.0 or 1.3.0:
;
;   $ yasm -O0 -f bin -o quote6n.com quote6.nasm
;
; Compiles with NASM 0.98.39 or later. Produces identical output with
; NASM 2.13.02 (with both -O0 and -O9).
;
;
;I read from QUOTE.TXT, and I read/write/keep QUOTE.IDX in the current dir.
;
;If you do not specify the command line parameter, first I check for .idx If
;I can't find it, I generate it. Then using up the .idx I display a random
;quote from .txt in the speed of light.
;
;If you give parameter "i", I'll create the .idx and quit immediately without
;echoing anything to the screen.
;
;You can either give the parameter "id" or "di". If you do this, I'll first
;(re)generate the .idx regardless it exists or not, then I display a quote.
;
;And last, specifying the parameter "slow", I display the quote without
;touching the .idx file. Of course it's *very* slow unless you've a .txt file
;smaller than 64K.
;
;I require an IBM compatible PC omputer, I can even work on an 8086 (no need
;for 286, 386, 486, Pentium etc.). I need exactly 64K free conventional
;memory. No matter ANSI.SYS is loaded or not. I can only produce nice
;text-mode graphics in 80-column modes. I need DOS 2.0 or later; DOSBox and
;FreeDOS also work.
;
;My error codes are not documentated, however, I give back the same errorlevel
;for the same error. Now the errors may be file i/o and line-too-long.
;
; Limits:
;
; * minimum quote size: 5 bytes (1 byte of text + CRLF + CRLF)
; * maximum quote size: 4096 bytes including the trailing CRLF (longer than
;   a screen)
; * minimum number of quotes: 1  !! check at indexing time
; * maximum number of quotes: 65535  !! check at indexing time
; * minimum quote.txt file size: 5 bytes (1 quote)
; * maximum quote.txt file size: 55 MiB == 55 << 20 bytes
; * quote.idx file size = 2 + ceil(number_of_quotes / 1024.0) bytes
; * minimum quote.idx file size: 2 + 1 == 3 bytes
; * maximum quote.idx file size: 2 + (55 << 10) == 56322 bytes
;
; Memory layout:
;
; * 0...0x80: PSP (Program Segment Prefix), populated by DOS.
; * 0x80...0x100: String containing command-line arguments, populated by DOS.
;   It starts with the 8-bit variable named `param'.
; * 0x100... (at most 1274 bytes): .com file (code and data) loaded by DOS.
;   Entry point is at the beginning, has label _start for convenience.
; * 0x5fa...0x9fe (1028 bytes): Variable named buffer, file preread buffer.
;   When reading our quote, it continues and overlaps idxc and index.
; * 0x9fe...0xa00 (2 bytes): Variable named idxc, contains total number of
;   quotes.
; * 0xa00...0xff00 (62720 bytes): Array variable named index, index entries:
;   each byte contains the total number of quotes whose first byte is in the
;   corresponding 1024-byte block of quote.txt.
; * 0xff00...0x10000 (256 bytes): Stack, it grows from high to low offsets.
;   Before jumping to 0x100, DOS pushes the exit address 0 within the PSP
;   (containing an `int 20h' instruction), so that a simple `ret' will exit
;   the program.
;

org 0x100
bits 16
cpu 8086

;=======Konstansok
	_bss equ 0x5fa
	buflen equ 1024+4
	idxlen equ 0xf500  ; 61.25 KiB
	quote_limit equ 4096  ; All quotes must be shorter than this. For compatibility with earlier versions.

;=======Kezdőérték nélküli adatok
%define	buffer word[_bss]		;Fájl-előreolvasó buffer
%define offset_buffer _bss		;buffer overlaps idxc and index when reading the final quote.
%define	idxc   word[_bss+buflen]	;Total number of quotes. IDXC és INDEX egymás után van!!!
%define offset_idxc (_bss+buflen)
%define	index  word[_bss+buflen+2]	;Indextábla 1 az 1-ben
%define offset_index (_bss+buflen+2)
%define	param  byte[080h]

;=======Kód
_start:
	; Vanity header. It is mostly a no-op at the beginning of a DOS .com file.
	; The version number digits after 2. can be arbitrary.
	db 'POTTERSOFTWARE_QUOTE_DISPLAYER_2.63', 13, 10, 26, 0x83, 0xc4, 0x14
	;db 'POTTERSOFTWARE_FORTUNE_TELLER_2.63', 13, 10, 26, 0x83, 0xc4, 0x16
	xor bx, bx
	mov idxc, bx

	cmp param, 2
	je strict short l18
	mov ax, 0E0Dh
	int 10h				;BH=0, Writeln
	mov al, 00Ah
	int 10h
	mov si, headermsg			;Fejléc kiírása
	call header

l18:	mov ax, 3D00h
	mov dx, txtfn
	int 21h				;Open quote.txt
	jnc strict short nc1
	call error
nc1:	push ax				;Save file handle

	mov ax, 3D00h
	mov dx, idxfn
	int 21h
	mov dl, param
	adc dl, 0
	jnz strict short gen
	
;=======Beolvassuk az indextáblát
	mov bx, ax
	mov ah, 3Fh
	mov cx, idxlen+2
	mov dx, offset_idxc
	int 21h
	mov ah, 3Eh
	int 21h
	pop bx				;Restore .txt handle
	jmp l5

;=======Generáljuk az indexfájlt
gen:	pop bx				;Get handle of quote.txt
	mov si, offset_buffer
	mov di, offset_index
	mov bp, 0A0Dh
	mov [si], bp
	mov [si+2], bp

l2:	mov ah, 3Fh
	mov cx, 1024
	mov dx, offset_buffer+4
	int 21h
	mov cx, ax
	jcxz l1
	mov al, 0

l4:	cmp [si], bp
	jne strict short l3
	cmp [si+2], bp
	jne strict short l3
	cmp byte[si+4], 13
	je strict short l3		;Subsequent empty line is not a quote.
	inc idxc			;Megszámolunk egy idézetet
	inc ax				;Az 1K-kon belül is
l3:	inc si
	loop l4

	stosb				;Az adat felvétele az indextáblába
	lodsw
	mov [offset_buffer], ax
	lodsw
	mov [offset_buffer+2], ax
	mov si, offset_buffer
	cmp di, idxlen
	jne strict short l2
	push di				;Push error code

error:  mov al, 7			;General error message
	int 29h				;Beep
	pop ax				;Get code address of error, and
	mov ah, 4Ch			;give it back as errorlevel.
	int 21h

l1:	cmp param, 5
	je strict short l19
	push bx				;File handle elmentése
	mov ah, 3Ch
	xor cx, cx			;Attribútumot nem kap
	mov dx, idxfn
	int 21h				;Open
	jnc strict short nc2
	call error
nc2:	mov bx, ax
	mov ah, 40h
	lea cx, [di-offset_idxc]	;CX:=DI-ofs(index)=indextábla_hossza
	mov dx, offset_idxc
	int 21h				;Write
	mov ah, 3Eh
	int 21h				;Close .idx
	pop bx				;Most: BX=handle of quote.txt
l19:	cmp param, 2
	jne strict short ne4
	ret				;Exit with int 20h.
ne4:
l5:	push bx

;=======Generates 32-bit random number in DX:AX. Clobbers flags, BP, BX, CX.
	mov ah, 0
	int 1Ah				;Get time-random seed in CX:DX
	xor bp, bp
	mov ax, cs
	add ax, dx			;Modify seed
	mov bx, ax
	mov dx, 8405h
	mul dx
	shl bx, 1
	shl bx, 1
	shl bx, 1
	add ch, cl
	add dx, bx
	add dx, cx
	shl cx, 1
	shl cx, 1
	add dx, cx
	add dh, bl
	add ax, strict word 1		;Modifies CF (inc ax doesn't). `strict word' to make `nasm -O0' and `nasm -O9' the same.
	adc dx, bp			;(DX:AX) += (0, 1). BP is 0.
	; Now DX:AX is a 32-bit random number.

;=======Generates random DX:=random(idxc) from random DX:AX.
;       Assumes BP==0. Clobbers flags, AX, BX.
	mov bx, dx
	mul idxc
	mov ax, bx
	mov bx, dx
	mul idxc
	add ax, bx
	adc dx, bp			;DX:=random(idxc). BP is 0.

;=======Finds block index (as SI-offset_index) of the quote with index DX.
	pop bx
	mov si, offset_index
	mov ah, 0
l7:	lodsb
	cmp dx, ax
	js strict short l6
	sub dx, ax
	jmp strict short l7

;=======Seeks to the block of our quote with index DX.
l6:	sub si, offset_index+2		;Now: SI: block index (of size 1024).
	push dx				;Now: DX: quote index within the block.
	mov bp, 0A0Dh
	mov ax, 4200h
	mov di, offset_buffer
	jns strict short l8
	xor dx, dx			;Our quote is in block 0, seek to the beginning.
	xor cx, cx
	int 21h
	jnc strict short nc5
	call error			;Error seeking to the beginning.
nc5:	mov ax, bp
	stosw				;Add sentinel CRLF+CRLF before the beginning.
	stosw
	; 1023 is the maximum size of the previous quote in the current (first)
	; block and (quote_limit-1) is the maximum size of our quote.
	mov cx, 1023+(quote_limit-1)
	jmp strict near l20
l8:	; Set CX:DX to 1024 * SI + 1020.
	mov dx, si
	mov cl, 10
	rol dx, cl
	mov cx, dx
	and cx, ((1 << 10) - 1)
	and dx, ((1 << 6) - 1) << 10
	add dx, 1020
	adc cx, byte 0
	int 21h				;Seek to 1024 * SI + 1020, to the beginning of the previous block.
	jnc strict short nc6
	call error
nc6:	; 4 is the size of the end of the  previous block, 1023 is the maximum size of
	; the previous quote in the current block and (quote_limit-1) is the maximum
	; size of our quote.
	mov cx, 4+1023+(quote_limit-1)

;=======Reads the blocks containing our quote.
l20:	mov dx, di
	mov ah, 3Fh
	int 21h				;Olvasás
	jnc strict short nc7
	call error			;Error reading quote.
nc7:	add ax, dx
	xchg ax, di			;DI := AX and clobber AX, but shorter.
	mov ax, bp
	stosw				;Append sentinel CR,LF,CR,LF,14,CR,LF,CR,LF.
	stosw
	; Now append 14,CR,LF,CR,LF quote_index times (at most 1275 bytes), as a
	; final sentinel to stop processing even if the index file is buggy.
	pop cx
	push cx
	jcxz lclose
l9:	inc ax
	stosb
	dec ax
	stosw
	stosw
	loop l9

lclose:	mov ah, 3Eh
	int 21h				;Close .txt file.

	pop ax				;Now: AX: quote index within the block.
	mov di, offset_buffer-1		;buffer starts with the last 4 bytes of the previous block.
l21:	inc di
	cmp [di], bp
	jne strict short l21
	cmp [di+2], bp
	jne strict short l21
	cmp byte [di+4], 13
	je strict short l21		;Ignore CRLF+CRLF followed by CR.
l22:	dec ax
	jns strict short l21
	add di, byte 4			;DI:=offset(our_quote)
	mov word [di+quote_limit-1], 0x0d0d  ;Forcibly truncate at 4095 bytes.

;=======Kiírjuk a kiválasztott idézetet
	mov ax, 00EDAh			;Felső keret
	mov bx, 0BFh
	call pline

lld:    mov cx, 79
	mov al, 13			;CR
	lea si, [di-1]
	repnz scasb			;Seek CR using DI.
	jz strict short z5
	call error			;Túl hosszú sor
z5:	sub cx, byte 79
	inc cx				;NOT nem állítja a flageket!!!
	neg cx				;Most CX=sor hossza, CR nélkül
	jnz strict short y91

lle:	mov ax, 00EC0h			;Üres sor=> Idézet vége, kilépés
	mov bx, 0D9h			;└┘
	call pline
	mov si, footermsg
	call header
	mov bx, 7
	call fillc
	ret				;Exit with int 20h.

y91:	cmp [di-1], bp			;Compare against CRLF, we try to match LF.
	jne strict short y92
	inc di				;Skip over LF.
y92:	mov [si], cl			;Set length of Pascal string.

;=======Prints the Pascal string starting at SI with the correct color & alignment
;       according to the control codes found at [SI] and [SI+1]. Keeps DI intact.
	; Calculate the value of BEFORE first using up AnsiCh:
	; #0=Left '-'=Right '&'=Center alignment.
	push di
	lodsb				;AL:=length(s), AL<>0.
	mov dl, 0			;AnsiCh=dl is 0 by default
	cmp byte [si], '-'
	jne strict short yc
	dec ax
	dec ax
	mov dx, ax
	inc si
	xchg [si], dl			;Copy Pascal string length, get new AnsiCh.
	inc si				;Skip first 2 characters (-- or -&).
yc:     dec si
	mov ah, 0
	mov bx, 78
	mov cx, 15
	cmp dl, 0
	jne strict short ya
	mov al, 0
	xor bx, bx
	mov cx, 7
	jmp strict near yb
ya:     cmp dl, '&'
	jne strict short yb
	mov bx, 39
	shr ax, 1
	mov cx, 10
yb:     sub bx, ax
	mov di, bx
	mov ax, 0Eh*256+0b3h		;'│' Start the line
	mov bh, 0
	int 10h
	mov bx, cx
	mov cx, 78
	call filld
        ; Display the Pascal string at SI prefixed by DI spaces.
	lodsb				;Get length of Pascal string.
	mov cl, al
	mov ch, 0
	mov dx, cx
	mov bh, 0
	mov cx, di
	jcxz y5
	mov ax, 256*0Eh+' '
y2:     int 10h
	loop y2
y5:     mov cx, dx
	mov ah, 0Eh
y3:     lodsb
	int 10h
	loop y3
y8:     mov cx, 78
	sub cx, di
	sub cx, dx
	jcxz y7
	mov ax, 0Eh*256+' '
y4:     int 10h
	loop y4
y7:     mov ax, 0Eh*256+0b3h		;'│' The line ends by this, too.
	int 10h
	pop di

	jmp strict near lld		;Display next line of our quote.

;(3)
;Itt kerülnek leírásra a meghívott függvények.
;

header: 	                        ;Fejléc & Lábléc kiíró
					;Hívás: string absoulute DS:SI
y71:    mov bx, 16
	call fillc
	mov ax, 0Eh*256+0b2h		;'▓'
	mov byte [ploop2], 48h		;048h: DEC AX
	call ploop
	lodsb
	mov ah, 0
	mov dx, ax
	shr ax, 1
	mov cx, 25
	sub cx, ax
	mov bx, cx
	mov ax, 0Eh*256+' '
	mov bh, 0
	jcxz y74
y75:    int 10h
	loop y75
y74:    mov cx, [si-1]
	mov ch, 0
y76:    lodsb
	int 10h
	loop y76
	mov cx, 50
	sub cx, bx
	sub cx, dx
	mov al, ' '
	jcxz y78
y77:    int 10h
	loop y77
y78:    mov al, 0b0h			;'░'
	mov byte [ploop2], 40h		;40h: INC AX
	call ploop
	mov bx, 7			;call fillc; ret Meg lett spórolva
fillc:	mov cx, 80
filld:	mov ax, 920h			;Fekete hátterű üres sort hagyunk.
	int 10h
	ret

pline:	int 10h				;Hívás: AH=0Eh, AL=1. ch, BX=2. ch
	mov cx, 78
	mov al, 196			;'─'
y70:    int 10h
	loop y70
	mov al, bl
	int 10h
	ret

ploop:	mov cx, 3
y72:    int 10h
	int 10h
	int 10h
	int 10h
	int 10h
ploop2:	dec ax
	loop y72
	ret

;=======Kezdőértékes adatok
txtfn:	db 'QUOTE.TXT',0
idxfn:	db 'QUOTE.IDX',0
headermsg:	db headermsg_size, 'PotterSoftware Fortune Teller 2.63'
headermsg_size	equ $-headermsg-1
footermsg:	db footermsg_size, 'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.'
footermsg_size	equ $-footermsg-1
