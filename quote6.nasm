; -*- coding: utf-8 -*-
;
; quote6.nasm: PotterSoftware Quote Displayer V2.62 (NASM source code)
; (C) 22 September 1996 by EplPáj of PotterSoftware, Hungary
; translation to NASM on 2022-03-18
;
; Compile it with NASM 0.98.39 .. 2.13.02 ...:
;
;   $ nasm -O0 -f bin -o quote6n.com quote6.nasm
;
; Alternatively, compile it with Yasm 1.2.0 or 1.3.0:
;
;   $ yasm -O0 -f bin -o quote6n.com quote6.nasm
;
; Compiles with NASM 0.98.39 or later. Produces identical output with
; NASM 2.13.02 (with both -O0 and -O9).
;
; This source file is for archival purposes only.
; Bugfixes and features shouldn't be added to this file, but to quote63.nasm.
;
;I read from quote.txt, and I read/write/keep quote.idx in the current dir.
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
;I require an IBM compatible PC/AT computer, I can even work on a 286, but
;unfurtunately the XT is not supported. I need exactly 64K free conventional
;memory. No matter ANSI.SYS is loaded or not. I can only produce nice
;text-mode graphics in 80-column modes. I need DOS 2.0 or later; DOSBox and
;FreeDOS also work.
;
;My error codes are not documentated, however, I give back the same errorlevel
;for the same error. Now the errors may be file i/o and line-too-long.
;
; Limits (all unchecked):
;
; * minimum quote size: 5 bytes (1 byte of text + CRLF + CRLF)
; * maximum quote size: 4096 bytes including the trailing CRLF (longer than
;   a screen)
; * minimum number of quotes: 1
; * maximum number of quotes: 65535
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
; * 0xf0...0xf2 (2 bytes): Variable named qqqqw. Overlaps command-line
;   arguments.
; * 0xf2...0xf4 (2 bytes): Variable named qqqqbefore. Overlaps command-line
;   arguments.
; * 0x100... (at most 3840 bytes): .com file (code and data) loaded by DOS.
;   Entry point is at the beginning, has label _start for convenience.
; * 0x1000...0x1800 (2048 bytes): Variable named buffer, file preread buffer.
;   When reading our quote, it continues and overlaps idxchw, idxc and index.
; * 0x1800...0x1802 (2 bytes): Variable named idxc, contains total number of
;   quotes. First 2 bytes of the quote.idx file.
; * 0x1802...0xf402 (56320 bytes): Array variable named index, index entries:
;   each byte contains the total number of quotes whose first byte is in the
;   corresponding 1024-byte block of quote.txt. Remaining bytes of the
;   quote.idx file.
; * 0xf402...0x10000 (3070 bytes): Stack, it grows from high to low offsets.
;   Before jumping to 0x100, DOS pushes the exit address 0 within the PSP
;   (containing an `int 20h' instruction), so that a simple `ret' will exit
;   the program.
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

org 0x100
bits 16
cpu 286  ; Some instructions below (such as higher-than-1 bit shifts) need 286.

;=======Size-measuring constants.
	_bss equ 1000h
	buflen equ 2048
	idxlen equ 55*1024  ; 55 KiB.
	quote_max equ 4096  ; All quotes must be shorter than this. For compatibility with earlier versions.

;=======Uninitialized data (_bss).
%define	buffer word[_bss]		;quote.txt file preread buffer. It overlaps idxc and index when reading our quote.
%define offset_buffer _bss
%define	idxc   word[_bss+buflen]	;Total number of quotes.
%define offset_idxc (_bss+buflen)
%define	index  word[_bss+buflen+2]	;Index table: 1 byte for each 1024-byte block of quote.txt.
%define offset_index (_bss+buflen+2)
%define	qqqqw  word[0F0h]
%define	param  byte[080h]
%define	qqqqbefore word[0F2h]

;=======Code (_code).
_start:
	a86_xor bx, bx
	mov idxc, bx

	cmp param, 2
	je strict short l18
	mov ax, 0E0Dh
	int 10h				;BH=0, Writeln.
	mov al, 00Ah
	int 10h
	mov si, headermsg
	call header			;Print blue header message.

l18:	mov ax, 3D00h
	mov dx, txtfn
	int 21h				;Open .txt file quote.txt.
	jnc strict short nc1
	call error
nc1:	push ax				;Save .txt filehandle.

	mov ax, 3D00h
	mov dx, idxfn
	int 21h				;Open index file quote.idx.
	mov dl, param
	adc dl, 0
	jnz strict short gen
	
;=======Reads the index file quote.idx.
	a86_mov bx, ax
	mov ah, 3Fh
	mov cx, idxlen+2
	mov dx, offset_idxc
	int 21h
	mov ah, 3Eh
	int 21h
	pop bx				;Restore .txt filehandle.
	jmp l5

;=======Starts generating the index file quote.idx.
gen:	pop bx				;Restore .txt filehandle.
	mov si, offset_buffer
	mov di, offset_index
	mov bp, 0A0Dh
	mov [si], bp			;First few bytes must not be 13, 10, 13, 10.
	mov [si+2], bp

l2:	mov ah, 3Fh			;Read next 1024-byte block.
	mov cx, 1024
	mov dx, offset_buffer+4
	int 21h
	a86_mov cx, ax
	jcxz l1
	mov al, 0			;Number of quotes in this block.

l4:	cmp [si], bp
	jne strict short l3
	cmp [si+2], bp
	jne strict short l3
	cmp byte[si+4], 13
	jne strict short ne3
	call error
ne3:	inc idxc			;Count the quote as total.
	inc ax				;Count the quote within the block.
l3:	inc si
	loop l4

	stosb				;Add byte for current block to index.
	lodsw
	mov [offset_buffer], ax
	lodsw
	mov [offset_buffer+2], ax
	mov si, offset_buffer
	cmp di, idxlen
	jne strict short l2
	push di				;Push error code. Error: quote.txt too long, index full.

error:  mov al, 7			;General error message.
	int 29h				;Beep.
	pop ax				;Get code address of error, and
	mov ah, 4Ch			;give it back as errorlevel.
	int 21h				;Exit to DOS.

;=======Rewrites the index file.
l1:	cmp param, 5
	je strict short l19
	push bx				;Save .txt filehandle.
	mov ah, 3Ch
	a86_xor cx, cx			;Creates with attributes = 0.
	mov dx, idxfn
	int 21h				;Open index file quote.idx for rewriting.
	jnc strict short nc2
	call error
nc2:	a86_mov bx, ax
	mov ah, 40h
	lea cx, [di-offset_idxc]	;CX := DI-ofs(index) == sizeof_index.
	mov dx, offset_idxc
	int 21h				;Write to index file.
	mov ah, 3Eh
	int 21h				;Close index file.
	pop bx				;Restore .txt filehandle.
l19:	cmp param, 2
	jne strict short ne4
	ret				;Exit to DOS with int 20h.
ne4:

;=======Continues after quote.idx has been read or generated.
l5:

;=======Generates 32-bit random seed in DX:AX. Clobbers flags, BP, BX, CX.
	mov ah, 0			;Read system clock counter to CX:DX.
	int 1Ah
	push bx				;Save handle of quote.txt.
	a86_xor bp, bp
	mov ax, cs
	a86_add ax, dx			;Modify seed.
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
	add ax, strict word 1		;Modifies CF (inc ax doesn't). `strict word' to make `nasm -O0' and `nasm -O9' the same.
	a86_adc dx, bp			;(DX:AX) += (0, 1). BP is 0.
	; Now DX:AX is a 32-bit random number.

;=======Generates random DX:=random(idxc) from random seed DX:AX.
;       Assumes BP==0. Clobbers flags, AX, BX.
	a86_mov bx, dx
	mul idxc
	a86_mov ax, bx
	a86_mov bx, dx
	mul idxc
	a86_add ax, bx
	a86_adc dx, bp			;DX:=random(idxc). BP is 0.

;=======Finds block index (as SI-offset_index) of the quote with index DX.
	pop bx				;Restore handle of quote.txt.
	mov si, offset_index
	mov ah, 0
l7:	lodsb
	a86_cmp dx, ax
	js strict short l6
	a86_sub dx, ax
	jmp strict short l7

;=======Seeks to the block of our quote with index DX.
l6:	sub si, offset_index+2		;SI := 1024-byte block index.
	push dx				;DX = quote index within block.
	mov bp, 0A0Dh
	mov ax, 4200h
	jns strict short l8
	a86_xor dx, dx			;Our quote is in block 0, seeks to the beginning.
	a86_xor cx, cx
	int 21h
	mov dx, offset_buffer+1024
	mov word [offset_buffer+1024-4], bp
	mov word [offset_buffer+1024-2], bp
	jmp strict near l20
l8:	a86_mov dx, si
	shl dx, 10
	a86_mov cx, si
	shr cx, 6
	int 21h				;Seek to 1024 * SI, to the beginning of the previous block.
	mov dx, offset_buffer

;=======Reads the blocks containing our quote.
l20:	mov ah, 3Fh
	mov cx, quote_max		;Reads this many bytes.
	; Bug: this trailing CRLF + CRLF (bp + bp) should be put after
	; read read_size (in ax above), not after quote_max bytes.
	mov [offset_buffer+quote_max], bp	;Append sentinel CRLF + CRLF.
	mov [offset_buffer+quote_max+2], bp
	int 21h				;Read from .txt file.
	mov ah, 3Eh
	int 21h				;Close .txt file.

	pop ax				;AX := quote index within block.
	mov di, offset_buffer+1020-1
l21:	inc di
	cmp [di], bp
	jne strict short l21
	cmp [di+2], bp
	jne strict short l21
	dec ax
	jns strict short l21
	add di, byte 4			;DI:=offset(our_quote).

;=======Prints our quote.
	mov ax, 00EDAh
	mov bx, 0BFh			;'┌┐'.
	call pline			;Draw the top side of the frame.

lld:    mov cx, 79
	mov al, 13			;CR.
	lea si, [di-1]
	repnz scasb			;Seek CR using DI.
	jz strict short z5
	call error			;Line too long in quote.
z5:	sub cx, byte 79			;Now: byte[di-1] == 10 (LF).
	inc cx				;Replacing inc+neg by not wouldn't change ZF.
	neg cx				;CX := length(line); without CR.
	jnz strict short y91

;=======Empty line: prints foooter and exits.
lle:	mov ax, 00EC0h
	mov bx, 0D9h			;'└┘'.
	call pline			;Draw the bottom side of the frame.
	mov si, footermsg
	call header			;Print blue footer message.
	mov bx, 7
	call fillc
	ret				;Exit to DOS with int 20h.

y91:    inc di
	mov [si], cl			;Set length of Pascal string.

;=======Prints the Pascal string starting at SI with the correct color & alignment
;       according to the control codes found at [SI] and [SI+1]. Keeps DI intact.
	; Calculate the value of BEFORE first using up AnsiCh:
	; #0=Left '-'=Right '&'=Center alignment.
	mov qqqqw, si
	lodsb				;AL:=length(s), AL<>0.
	mov dl, 0			;AnsiCh=dl is 0 by default.
	cmp byte [si], '-'
	jne strict short yc
	add qqqqw, byte 2		;If AnsiCh!=0, skip first 2 characters (-- or -&).
	dec ax
	dec ax
	a86_mov dx, ax
	xchg [si+1], dl			;Copy Pascal string length to the next byte, get new AnsiCh.
yc:     mov ah, 0
	mov bx, 78
	mov cx, 15
	cmp dl, 0
	jne strict short ya
	mov al, 0
	a86_xor bx, bx
	mov cx, 7
	jmp strict near yb
ya:     cmp dl, '&'
	jne strict short yb
	mov bx, 39
	shr ax, 1
	mov cx, 10
yb:     a86_sub bx, ax
	mov qqqqbefore, bx
	mov ax, 0Eh*256+0b3h		;'│' Start the line.
	mov bh, 0
	int 10h
	a86_mov bx, cx
	mov cx, 78
	call filld

	; Displays the Pascal string at qqqqw prefixed by qqqqbefore spaces.
	mov si, qqqqw
	lodsb				;Get length of Pascal string.
	a86_mov cl, al
	mov ch, 0
	a86_mov dx, cx
	mov bh, 0
	mov cx, qqqqbefore
	jcxz y5
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
	jcxz y7
	mov ax, 0Eh*256+' '
y4:     int 10h
	loop y4
y7:     mov ax, 0Eh*256+0b3h		;'│' The line ends by this, too.
	int 10h
	jmp strict near lld		;Display next line of our quote.

;=======Prints colorful header or footer line (func_Header).
;	Input is Pascal string at SI.
header:	mov bx, 16
	call fillc
	mov ax, 0Eh*256+0b2h		;'▓'.
	mov byte [ploop2], 48h		;Set to `dec ax' (48h).
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
	jcxz y74
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
	jcxz y78
y77:    int 10h
	loop y77
y78:    mov al, 0b0h			;'░'.
	mov byte [ploop2], 40h		;Set to `inc ax' (40h).
	call ploop
	mov bx, 7
	;call fillc			;Optimized away.
	;ret				;Optimized away.
fillc:	mov cx, 80			;Print 80 spaces with attributes in BX.
filld:	mov ax, 920h			;Print CX spaces with attributes in BX.
	int 10h
	ret

;=======Prints a top or bottom border line (func_PrintLine).
;	Input: AL=left corner byte; BL=right corner byte; AH=0Eh; BH=0.
pline:	int 10h
	mov cx, 78
	mov al, 196			;'─'.
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
ploop2:	dec ax				;Self-modifying code will modify this to `dec ax' or `inc ax'.
	loop y72
	ret

;=======Data with initial value (_data).
txtfn		db 'QUOTE.TXT',0
idxfn		db 'QUOTE.IDX',0
headermsg	db 34,'PotterSoftware Fortune Teller 2.6'  ; Size 34 should be 33.
footermsg	db 44,'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.'
