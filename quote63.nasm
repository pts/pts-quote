; -*- coding: utf-8 -*-
;
; quote.nasm: PotterSoftware Quote Displayer V2.63 (NASM source code)
; (C) 2022-03-30 by EplPáj of PotterSoftware, Hungary
; based on quote.nasm V2.62
;
; $ nasm -O0 -f bin -o quote63n.com quote63.nasm
;
; Compiles with NASM 0.98.39 or later. Produces identical output with
; NASM 2.13.02 (with both -O0 and -O9).
;

;I read from QUOTE.TXT, and I read/write/keep QUOTE.IDX in the current dir.

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
;I require an IBM compatible PC/AT computer, I can even work on a 286, but
;unfurtunately the XT is not supported. I need exactly 64K free conventional
;memory. No matter ANSI.SYS is loaded or not. I can only produce nice text-
;mode graphics in 80-column modes. Oh, haven't I mentioned that I need only
;DOS 2.0, but I prefer GNU-DOS.
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
; * 0xf0...0xf2 (2 bytes): Variable named qqqqw. Overlaps command-line arguments.
; * 0xf2...0xf4 (2 bytes): Variable named qqqqbefore. Overlaps command-line arguments.
; * 0x100... (at most 3840 bytes): .com file (code and data) loaded by DOS.
;   Entry point is at the beginning, has label _start for convenience.
; * 0x1000...0x1800 (2048 bytes): Variable named buffer, file preread buffer.
; * 0x1800...0x1802 (2 bytes): Variable named idxc, contains total number of quotes.
; * 0x1802...0xf402 (56320 bytes): Array variable named index, index
;   entries: each byte contains the total number of quotes whose first byte is in the
;   corresponding 1024-byte block of quote.txt.
; * 0xf402...0x10000 (3070 bytes): Stack, it grows from high to low offsets. Before
;   jumping to 0x100, DOS pushes the exit address 0 within the PSP (containing an
;   `int 20h' instruction), so that a simple `ret' will exit the program.
;

; --- Library for emulating byte-by-byte A86 output.
;
; Usage: instead of e.g. `a86_add ax, bx', use `a86_add ax, bx'.

%define _W_ax 0
%define _W_cx 1
%define _W_dx 2
%define _W_bx 3
%define _W_sp 4
%define _W_bp 5
%define _W_si 6
%define _W_di 7

%define _B_al 0
%define _B_cl 1
%define _B_dl 2
%define _B_bl 3
%define _B_ah 4
%define _B_ch 5
%define _B_dh 6
%define _B_bh 7

%define _RI_add  0x00
%define _RI_or   0x08
%define _RI_adc  0x10
%define _RI_sbb  0x18
%define _RI_and  0x20
%define _RI_sub  0x28
%define _RI_xor  0x30
%define _RI_cmp  0x38
%define _RI_test 0x84
%define _RI_xchl 0x86  ; Long (2-byte) xchg. Not a real instruction.
%define _RI_xchg 0x86
%define _RI_mov  0x88

%define _XI_add  1
%define _XI_or   1
%define _XI_adc  1
%define _XI_sbb  1
%define _XI_and  1
%define _XI_sub  1
%define _XI_xor  1
%define _XI_cmp  1
%define _XI_test 2
%define _XI_xchl 2
%define _XI_xchg 4
%define _XI_mov  0

%macro a86 3  ; a86 <instruction>, <destination-register>, <source-register>
; This macro assumes __BITS__ == 16. (Older versions of NASM don't support __BITS__.)
%ifdef _RI_%1
%ifdef _W_%2
%ifdef _W_%3
%if (_XI_%1) == 4 && ((_W_%2) == 0 || (_W_%3) == 0)
db 0x90 | (_W_%2) | (_W_%3)  ; 1-byte xchg with ax.
%elif (_XI_%1) < 2 && (((_W_%2) >> 1) ^ ((_W_%3) >> 1) ^ (_XI_%1)) & 1
db (_RI_%1) | 3, 0xc0 | (_W_%3) | (_W_%2) << 3
%else
db (_RI_%1) | 1, 0xc0 | (_W_%2) | (_W_%3) << 3  ; nasm.
%endif
%else
%error word-size register %3 unknown
db 0x90, 0x90
%endif
%else
%ifdef _B_%2
%ifdef _B_%3
%if (_XI_%1) < 2 && (((_B_%2) >> 1) ^ ((_B_%3) >> 1) ^ (_XI_%1)) & 1
db (_RI_%1) | 2, 0xc0 | (_B_%3) | (_B_%2) << 3
%else
db (_RI_%1), 0xc0 | (_B_%2) | (_B_%3) << 3  ; nasm.
%endif
%else
%error byte-size register %3 unknown
db 0x90, 0x90
%endif
%else
%error register %2 unknown
db 0x90, 0x90
%endif
%endif
%else
%error instruction %1 unknown
db 0x90, 0x90
%endif
%endmacro

%define a86_add  a86 add,
%define a86_or   a86 or,
%define a86_adc  a86 adc,
%define a86_sbb  a86 sbb,
%define a86_and  a86 and,
%define a86_sub  a86 sub,
%define a86_xor  a86 xor,
%define a86_cmp  a86 cmp,
%define a86_test a86 test,
%define a86_xchl a86 xchl,
%define a86_xchg a86 xchg,
%define a86_mov  a86 mov,

; ---

%macro my_jcxz_strict_short 1
; `jcxz strict short %1' doesn't work: error: mismatch in operand sizes
; `jcxz %1' works, but the shortness is not explicit.
db 0xe3, (%1)-2-$
%endmacro

; Independent of `nasm -O0' vs `nasm -O9'.
%macro my_add_ax_immediate 1
db 5
dw (%1)
%endmacro

org 0x100
bits 16
cpu 286  ; Some instructions below (such as higher-than-1 bit shifts) need 286.

;=======Konstansok
	buflen equ 2048
	idxlen equ 55*1024
	quote_limit equ 4096  ; All quotes must be shorter than this. For compatibility with earlier versions.

;=======Kezdőérték nélküli adatok
%define	buffer word[1000h]		;Fájl-előreolvasó buffer
%define offset_buffer 1000h		;buffer overlaps idxc and index when reading the final quote.
%define	idxc   word[1000h+buflen]	;Total number of quotes. IDXC és INDEX egymás után van!!!
%define offset_idxc (1000h+buflen)
%define	index  word[1000h+buflen+2]	;Indextábla 1 az 1-ben
%define offset_index (1000h+buflen+2)
%define	qqqqw  word[0F0h]
%define	param  byte[080h]
%define	qqqqbefore word[0F2h]

;=======Kód
_start:
	a86_xor bx, bx
	mov idxc, bx

	cmp param, 2
	je l18
	mov ax, 0E0Dh
	int 10h				;BH=0, Writeln
	mov al, 00Ah
	int 10h
	mov si, headermsg			;Fejléc kiírása
	call header

l18:	mov ax, 3D00h
	mov dx, txtfn
	int 21h				;Open quote.txt
	jnc nc1
	call error
nc1:	push ax				;Save file handle

	mov ax, 3D00h
	mov dx, idxfn
	int 21h
	mov dl, param
	adc dl, 0
	jnz gen
	
;=======Beolvassuk az indextáblát
	a86_mov bx, ax
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
	mov [si], bp			;Az első 4 byte nem lehet 13,10,13,10
	mov [si+2], bp

l2:	mov ah, 3Fh
	mov cx, 1024
	mov dx, offset_buffer+4
	int 21h
	a86_mov cx, ax
	my_jcxz_strict_short l1
	mov al, 0

l4:	cmp [si], bp
	jne l3
	cmp [si+2], bp
	jne l3
	cmp byte[si+4], 13
	jne ne3
	call error
ne3:	inc idxc			;Megszámolunk egy idézetet
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
	jne l2
	push di				;Push error code

error:  mov al, 7			;General error message
	int 29h				;Beep
	pop ax				;Get code address of error, and
	mov ah, 4Ch			;give it back as errorlevel.
	int 21h

l1:	cmp param, 5
	je l19
	push bx				;File handle elmentése
	mov ah, 3Ch
	a86_xor cx, cx			;Attribútumot nem kap
	mov dx, idxfn
	int 21h				;Open
	jnc nc2
	call error
nc2:	a86_mov bx, ax
	mov ah, 40h
	lea cx, [di-offset_idxc]	;CX:=DI-ofs(index)=indextábla_hossza
	mov dx, offset_idxc
	int 21h				;Write
	mov ah, 3Eh
	int 21h				;Close .idx
	pop bx				;Most: BX=handle of quote.txt
l19:	cmp param, 2
	jne ne4
	ret				;int 20h
ne4:

;=======Megkeressük a random idézetet
l5:	mov ah, 0
	int 1Ah				;Get time-random seed in CX:DX
	push bx
	a86_xor bp, bp
	mov ax, cs
	a86_add ax, dx			;Modify seed
	a86_mov bx, ax
	mov dx, 8405h
	mul dx
	shl bx, 3
	a86_add ch, cl
	a86_add dx, bx
	a86_add dx, cx
	shl cx, 2
	a86_add dx, cx
	a86_add dh, bl
	shl cx, 5
	my_add_ax_immediate 1		;Modifies CF (inc ax doesn't).
	a86_adc dx, bp			;BP:AX
	a86_mov bx, dx
	mul idxc
	a86_mov ax, bx
	a86_mov bx, dx
	mul idxc
	a86_add ax, bx
	a86_adc dx, bp			;DX:=random(nr_of_quotes)
	pop bx

	mov si, offset_index
	mov ah, 0
l7:	lodsb
	a86_cmp dx, ax
	js l6
	a86_sub dx, ax
	jmp short l7

l6:	sub si, offset_index+2		;Now: SI: block index (of size 1024).  !! Why +2?
	push dx				;Now: DX: quote index within the block.
	mov bp, 0A0Dh
	mov ax, 4200h
	jns l8
	a86_xor dx, dx
	a86_xor cx, cx
	int 21h				;!!Why special-case seeking to the beginning?
	jnc nc5
	call error			;Error seeking to the beginning.
nc5:	mov dx, offset_buffer+1024	;!!Why not just offset_buffer? What's in the beginning?
	mov word [offset_buffer+1024-4], bp
	mov word [offset_buffer+1024-2], bp
	jmp strict near l20

l8:	a86_mov dx, si
	shl dx, 10
	a86_mov cx, si
	shr cx, 6
	int 21h				;Seek to 1024 * SI, to the beginning of the previous block.
	jnc nc6
	call error
nc6:	mov dx, offset_buffer

l20:	mov ah, 3Fh
	mov cx, quote_limit-1		;Silently truncate longer quotes.
	int 21h				;Olvasás
	jnc nc7
	call error			;Error reading quote.
nc7:	add ax, dx
	xchg ax, di			;DI := AX and clobber AX, but shorter.
	mov ax, bp
	stosw				;Append sentinel CRLF+CRLF.
	stosw
	mov ah, 3Eh
	int 21h				;Close .txt file.

	pop ax				;Now: AX: quote index within the block.
	mov di, offset_buffer+1020-1
l21:	inc di
	cmp [di], bp
	jne l21
	cmp [di+2], bp
	jne l21
	dec ax
	jns l21
	add di, byte 4			;DI:=offset(idézet)

;=======Kiírjuk a kiválasztott idézetet
	mov ax, 00EDAh			;Felső keret
	mov bx, 0BFh
	call pline

lld:    mov cx, 79
	mov al, 13			;CR
	lea si, [di-1]
	repnz scasb			;Seek CR
	jz z5
	call error			;Túl hosszú sor
z5:	sub cx, byte 79
	inc cx				;NOT nem állítja a flageket!!!
	neg cx				;Most CX=sor hossza, CR nélkül
	jnz y91

lle:	mov ax, 00EC0h			;Üres sor=> Idézet vége, kilépés
	mov bx, 0D9h			;└┘
	call pline
	mov si, footermsg
	call header
	mov bx, 7
	call fillc
	ret				;int 20h, Program vége

y91:    inc di
	mov [si], cl			;Beállítjuk a PasStr hosszát


;If S='' align returns TRUE else it returns FALSE. Align prints S with the
;correct color & alignment according to the control codes found in S[1,2]

;START OF ALIGN
					;Calculate the value of BEFORE first
					;using up AnsiCh: #0=Left '-'=Right
	mov qqqqw, si                   ;'&'=Center alignment
	lodsb				;AL:=length(s), AL<>0.
yd:     mov dl, 0			;AnsiCh=dl is 0 by default
	cmp byte [si], '-'
	jne yc
	add qqqqw, byte 2		;Ha AnsiCh<>0 => s[1,2] kihagyása
	dec ax
	dec ax
	a86_mov dx, ax
	xchg [si+1], dl			;length odébbmásolása, új AnsiCh
yc:     mov ah, 0
	mov bx, 78
	mov cx, 15
	cmp dl, 0
	jne ya
	mov al, 0
	a86_xor bx, bx
	mov cx, 7
	jmp strict near yb
ya:     cmp dl, '&'
	jne yb
	mov bx, 39
	shr ax, 1
	mov cx, 10
yb:     a86_sub bx, ax
	mov qqqqbefore, bx
	mov ax, 0Eh*256+0b3h		;'│' Start the line
	mov bh, 0
	int 10h
	a86_mov bx, cx
	mov cx, 78
	call filld
y6:     				;Display the string "s" with "before"
	mov si, qqqqw
	lodsb
	a86_mov cl, al
	mov ch, 0
	a86_mov dx, cx
	mov bh, 0
	mov cx, qqqqbefore
	my_jcxz_strict_short y5
	mov ax, 256*0Eh+' '
y2:     int 10h
	loop y2
y5:     a86_mov cx, dx
	mov ah, 0Eh
y3:     lodsb
	int 10h
	loop y3
y8:     mov cx, 78
	sub cx, qqqqbefore
	a86_sub cx, dx
	my_jcxz_strict_short y7
	mov ax, 0Eh*256+' '
y4:     int 10h
	loop y4
y7:     mov ax, 0Eh*256+0b3h		;'│' The line ends by this, too.
	int 10h
	jmp lld				;A következő sor feldolgozása
;END OF ALIGN

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
	a86_mov dx, ax
	shr ax, 1
	mov cx, 25
	a86_sub cx, ax
	a86_mov bx, cx
	mov ax, 0Eh*256+' '
	mov bh, 0
	my_jcxz_strict_short y74
y75:    int 10h
	loop y75
y74:    mov cx, [si-1]
	mov ch, 0
y76:    lodsb
	int 10h
	loop y76
	mov cx, 50
	a86_sub cx, bx
	a86_sub cx, dx
	mov al, ' '
	my_jcxz_strict_short y78
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
	a86_mov al, bl
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
txtfn	db 'QUOTE.TXT',0
idxfn	db 'QUOTE.IDX',0
headermsg	db 34,'PotterSoftware Fortune Teller 2.6'  ; Size 34 should be 33.
footermsg	db 44,'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.'
