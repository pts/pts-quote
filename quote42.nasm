; -*- coding: utf-8 -*-
;
; quote42.nasm: PotterSoftware Quote Displayer V2.42 (NASM source code)
; (C) 1996--2022-03-27 by EplPáj of PotterSoftware, Hungary
; translation to NASM on 2022-03-27
;
; $ nasm.static -O0 -f bin -o quote42n.com quote42.nasm
;
; Is this bug still present? !! This program prints garbage after the last
; quote (could not be reproduced), assuming CRLF + CRLF file ending.
;
; This is version 2.42. It is functionally equivalent to version 2.33, but it's
; implemented in NASM (rather than Turbo Pascal 7.0 inline assembly). The original
; source code for version 2.40 was implemented in A86, but that has been lost.
;
; The QUOTE.IDX index file format is identical in version 2.30 .. 2.5? and
; different from version 2.60.
;
; This source code is based on the disassembly of quote3.exe generated by
; the Turbo Pascal compiler (tp70), but it has been changed since then to
; make it work as a DOS .com program, and it is also based on the source
; code quote3.pas (mostly for comments).
;
; It uses ANSI.SYS for color output, and it detects the lack of ANSI.SYS (such as
; in DOSBox), and then it prints colorless output.
;
; Command-line argument (first byte on the command-line):
;
; * ' '-> Display a quote using index table (default).
; * 'A'-> Display a quote using linear search.
; * 'B'-> Create index table & then display a quote using it.
; * 'C'-> Create index table.
;

bits 16
cpu 286
org 0x100

%macro my_jcxz_strict_short 1
; `jcxz strict short %1' doesn't work: error: mismatch in operand sizes
; `jcxz %1' works, but the shortness is not explicit.
db 0xe3, (%1)-2-$
%endmacro

_start:  ; begin { Főprogram }
mov al, 0xd  ; Writeln
int 0x29
mov al, 0xa
int 0x29
; Detect ANSI.SYS.
;
; From http://www.osfree.org/doku/en:docs:dos:api:int29 :
; COMMAND.COM v3.2 and v3.3 compare the INT 29 vector against the INT 20
; vector and assume that ANSI.SYS is installed if the segment is larger.
push es
xor ax, ax
mov es, ax
mov bx, [es:0x29*4+2]  ; ansi:=memw[0:$29*4+2]>memw[0:$20*4+2];
cmp bx, [es:0x20*4+2]
pop es
jnc strict short lx_12b
mov byte [ttt], '*'  ; This means there's no ANSI.SYS
lx_12b:

push strict word headermsg
call func_Header

mov al, [0x81]  ; First character of command-line arguments in PSP.  ; xch:=char(mem[PrefixSeg:$81]);
cmp al, ' '
jne strict short lx_13c  ; if xch=' ' then xch:=char(mem[PrefixSeg:$82]);
mov al, [0x82]
lx_13c:
cmp byte [0x80], 0x0  ; if mem[PrefixSeg:$80]=0 then xch:=' ';
jne strict short lx_146
mov al, ' '
lx_146:
and al, 255-32
mov [qqq_xch], al
; es will remain this way for the rest of the run.
push ds
pop es
; XReset(IdxFn);
mov ax, 0x3d00  ; Open for Read Only, C-Mode
mov dx, idxfn
int 0x21
mov [qqq_han], ax
sbb ax, ax  ; AX:=0, ha OK ; AX:=$FFFF, ha hiba
mov word [idx], 0x0  ; idx[0]:=0
cmp ax, strict word 0x0  ; if (IOResult<>0) or (xch<>#0) then
jne strict short lx_16d
cmp byte [qqq_xch], 0x0
jne strict short lx_16d
jmp strict near lls
lx_16d:
; XReset(TXTFN);
mov ax, 0x3d00  ; Open for Read Only, C-Mode
mov dx, txtfn
int 0x21
mov [qqq_han], ax
;sbb ax, ax  ; AX:=0, ha OK ; AX:=$FFFF, ha hiba  ; !! Fail on I/O error.
; qqq_max:=filesize(f);
mov ax, 0x4202
mov bx, [qqq_han]
xor cx, cx
xor dx, dx
int 0x21
mov [qqq_max], ax
mov [qqq_max+2], dx
mov ax, 0x4200
mov bx, [qqq_han]
xor cx, cx
xor dx, dx
int 0x21
mov word [qqq_b], full+4  ; b:=full+4
xor ax, ax
mov [qqq_l], ax  ; l:=0
mov [qqq_l+2], ax
mov [qqq_oldl], ax  ; oldl:=0
mov [qqq_oldl+2], ax
mov word [qqq_a], 0x1
mov [buf+full], ax  ; Make sure we don't detect CRLF+CRLF at the beginning.

lx_1b5:
; repeat
call func_GetNext
mov si, buf-4
add si, [qqq_b]
cmp word [si], 0x0a0d  ; CRLF
jne strict short lx_1fd
cmp word [si+0x2], 0x0a0d  ; CRLF
jne strict short lx_1fd  ;  if buf[b-4]=newline then begin
mov ax, [qqq_l]  ;    idx[a]:=l-oldl
mov dx, [qqq_l+2]
sub ax, [qqq_oldl]
sbb dx, [qqq_oldl+2]
mov di, idx
add di, [qqq_a]
add di, [qqq_a]
mov [di], ax
mov [di+0x2], dx
inc word [qqq_a]
mov ax, [qqq_l]  ;    oldl:=l
mov [qqq_oldl], ax
mov ax, [qqq_l+2]
mov [qqq_oldl+2], ax  ;  end;
lx_1fd:
mov ax, [qqq_max]  ; until l=max
mov dx, [qqq_max+2]
cmp [qqq_l], ax
jne strict short lx_1b5
cmp [qqq_l+2], dx
jne strict short lx_1b5

; Close(f);
mov ah, 0x3e
mov bx, [qqq_han]
int 0x21
cmp byte [qqq_xch], 'A'  ; Nem írjuk ki az IT-t, ha az A par. van
jne strict short lx_222
jmp strict near llc
lx_222:
mov cx, [qqq_a]
dec cx
mov si, idx+2
mov ax, ds
mov es, ax
mov di, buf
xor dx, dx
lx_233:
lodsw
stosb
cmp ax, 0xf0
jc strict short lx_242
dec di
rol ax, byte 0x8
or ax, 0xf0
stosw
lx_242:
loop lx_233
mov [qqq_a], di
sub word [qqq_a], buf

; XRewrite(IDXFN);
mov ah, 0x3c  ; Create file
mov cx, 0x0
mov dx, idxfn
int 0x21
jnc strict short lx_25f
mov ax, 0x4cf0  ; Fatal error
int 0x21
lx_25f:
; blockwrite(f, buf, qqq_a);
mov ah, 0x40
mov bx, [qqq_han]
mov cx, [qqq_a]
mov dx, buf
int 0x21
; close(f);
mov ah, 0x3e
mov bx, [qqq_han]
int 0x21
; goto c;
jmp strict short llc

lls:  ; end else begin
; XReset(IDXFN);
mov ax, 0x3d00  ; Open for Read Only, C-Mode
mov dx, idxfn
int 0x21
mov [qqq_han], ax
;sbb ax, ax  ; AX:=0, ha OK ; AX:=$FFFF, ha hiba  ; !! Fail on I/O error.
; blockread(f, buf, $FFFF, qqq_a);
mov ah, 0x3f
mov bx, [qqq_han]
mov cx, 0xffff  ; !! Lower this to proect stack etc. against buffer overflow.
mov dx, buf
int 0x21
mov [qqq_a], ax
; close(f);
mov ah, 0x3e
mov bx, [qqq_han]
int 0x21

mov cx, [qqq_a]
mov dx, 0x1
mov si, buf
mov di, idx+2
mov ax, ds
mov es, ax
lx_2af:
lodsb
mov ah, 0x0
stosw
cmp al, 0xf0
jc strict short lx_2c0
dec di
dec di
and al, 0xf
mov ah, al
lodsb
stosw
dec cx
lx_2c0:
inc dx
loop lx_2af
mov [qqq_a], dx
llc:
cmp byte [qqq_xch], 'C'
jne strict short lx_2d1
jmp strict near lx_46d
lx_2d1:
; XReset(TXTFN);
mov ax, 0x3d00  ; Open for Read Only, C-Mode
mov dx, txtfn
int 0x21
mov [qqq_han], ax
;sbb ax, ax  ; AX:=0, ha OK ; AX:=$FFFF, ha hiba  ; !! Fail on I/O error.
; Now qqq_a-1 is the number of quotes in txtfn, provided that txtfn ends with CRLF + CRLF.
xor ax, ax
mov [qqq_l], ax  ; L kezdőoffszet kiszámolása
mov [qqq_l+2], ax
mov si, [qqq_a]
test si, si
jz after_random  ; If there are 0 quotes, print from the beginning of txtfn.
dec si  ; SI := Number of quotes.

; DX:=random(SI);  Then 0 <= SI < DX.
; This code may ruin AX, BX, CX, SI, DI, BP and FLAGS.
;
; This code generates a 32-bit random number n in a register pair, then computes
; DX := (n * SI) >> 32 as the random value.
;mov ah, 0  ; Not needed, AX=0 above.
int 0x1a  ; Get time-random seed in CX:DX.
xor bp, bp
mov ax, cs
add ax, dx  ; Modify seed.
mov bx, ax
mov dx, 0x8405
mul dx
shl bx, 3
add ch, cl
add dx, bx
add dx, cx
shl cx, 2
add dx, cx
add dh, bl
shl cx, 5
add ax, strict word 1  ; Modifies CF (inc ax doesn't)..
adc dx, bp
mov bx, dx
mul si
mov ax, bx
mov bx, dx
mul si
add ax, bx
adc dx, bp  ; DX:=random(SI)
jz after_random  ; If the chosen random number is 0, print from the beginning of txtfn.

mov si, idx
add si, dx
add si, dx
std
lx_321:
lodsw  ; L:=IDX[W]+IDX[W-1]+...+IDX[1]
add [qqq_l], ax
adc word [qqq_l+2], byte +0x0
cmp si, idx
jne strict short lx_321
cld

after_random:
push strict word 0xbfda  ; '┌┐'  ; Keret ki
call func_PrintLine
lx_33a:
; seek(f, qqq_l);
mov ax, 0x4200
mov bx, [qqq_han]
mov dx, [qqq_l]
mov cx, [qqq_l+2]
int 0x21
; blockread(f, s[1], 255, qqq_w);
mov ah, 0x3f
mov bx, [qqq_han]
mov cx, 0xff
mov dx, var_s+1
int 0x21
mov [qqq_w], ax
cmp word [qqq_w], byte +0x0  ; Stop at EOF
jne strict short lx_366
jmp strict near lx_454
lx_366:
mov bx, 0x0  ; Look for #13 to determine length(s)
mov si, var_s+1
lx_36c:
or bh, bh
jnz strict short lx_378
cmp byte [bx+si], 0xd
je strict short lx_37b
inc bx
jmp strict short lx_36c
lx_378:
jmp strict near lx_46d  ; Hiba: 255 karakternél hosszabb sor
lx_37b:
mov [var_s], bl  ; Beállítjuk a string hosszát
inc bx
inc bx
add [qqq_l], bx  ; inc(l,length(s)+2);
adc word [qqq_l+2], byte +0x0

; START OF ALIGN
;
; If S='' align returns TRUE else it returns FALSE. Align prints S with the
; correct color & alignment according to the control codes found in S[1, 2].

; Calculate the value of BEFORE first using up AnsiCh: #0=Left '-'=Right
; '&'=Center alignment
mov cx, ds
mov si, var_s
mov [qqq_w], si
lodsb
cmp al, 0x0
jne strict short lx_39f
mov al, 0x1
mov ds, cx
jmp strict near lx_44d  ; Empty string: do nothing but restore original CS
lx_39f:
mov byte [qqq_ansich], 0x0  ; AnsiCh is 0 by default
cmp byte [si], '-'
jne strict short lx_3bc
mov al, [si+0x1]
mov [qqq_ansich], al
add word [qqq_w], byte 2  ; If not AnsiCh<>0 the 1st 2 char won't be in the str
mov al, [si-0x1]
dec ax
dec ax
mov [si+0x1], al
lx_3bc:
mov ah, 0x0
mov ds, cx
mov bx, 0x4e
cmp byte [qqq_ansich], 0x0
jne strict short lx_3cf
mov al, 0x0
mov bx, 0x0
lx_3cf:
cmp byte [qqq_ansich], '&'
jne strict short lx_3db
mov bx, 0x27
shr ax, 1
lx_3db:
sub bx, ax
mov [qqq_before], bx
mov al, 0xb3  ; '│'  ; The line starts by this
int 0x29
cmp byte [ttt], '*'  ; Put out an ANSI EscSeq to set color if needed
je strict short lx_404
mov ah, 0x9
mov al, [qqq_ansich]
cmp al, 0x0
je strict short lx_404
add al, 0xa
mov [ttt+17+3], al
mov dx, ttt+17
int 0x21
mov byte [qqq_ansich], 0x0
lx_404:

; Display the string "s" with "before" spaces in front of it
mov si, [qqq_w]
lodsb
mov cl, al
mov ch, 0x0
mov dx, cx
my_jcxz_strict_short lx_438
mov cx, [qqq_before]
my_jcxz_strict_short lx_41e
mov al, ' '
lx_41a:
int 0x29
loop lx_41a
lx_41e:
mov cx, dx
my_jcxz_strict_short lx_427
lx_422:
lodsb
int 0x29
loop lx_422
lx_427:
mov cx, 0x4e
sub cx, [qqq_before]
sub cx, dx
my_jcxz_strict_short lx_438
mov al, ' '
lx_434:
int 0x29
loop lx_434
lx_438:

cmp byte [ttt], '*'  ; Restore original color via ANSI EscSeq if needed
je strict short lx_447
mov ah, 0x9
mov dx, ttt+25
int 0x21
lx_447:
mov al, 0xb3  ; '│'  ; The line ends by this, too
int 0x29
mov al, 0x0 ; The return value is FALSE
; END OF ALIGN

lx_44d:
or al, al
jnz strict short lx_454
jmp strict near lx_33a  ; Ha FALSE-t ad vissza, még van köv. sor, Különben lábléc és program vége
lx_454:
push strict word 0xd9c0  ; '└┘'
call func_PrintLine
push strict word footermsg
call func_Header
mov ah, 0x3e  ; Close(F);
mov bx, [qqq_han]
int 0x21
lx_46d:
ret  ; Exit to DOS.

; function GetNext: char; assembler;
func_GetNext:
cmp word [qqq_b], full+4  ; if qqq_b=full+4 then begin
jne strict short lx_33
; move(src:=buf[full], dst:=buf[0], 4);
  mov si, buf + full
  mov di, buf
  movsw
  movsw
; blockread(f, buf[4], full, qqq_w);
mov ah, 0x3f
mov bx, [qqq_han]
mov cx, full
mov dx, buf+4
int 0x21
jnc strict short lx_2d
mov ax, 0x4cf1  ; Abort on read error.
int 0x21
lx_2d:
mov word [qqq_b], 0x4  ; endif
lx_33:
mov bx, [qqq_b]  ; GetNext:=Buf[qqq_B];
mov al, [bx+buf]
inc word [qqq_b]
add word [qqq_l], byte +0x1  ; inc(qqq_l);
adc word [qqq_l+2], byte +0x0
ret

; procedure Header(const s: near OpenString); assembler;
%define Header_arg_s (bp+4)
func_Header:
push bp
mov bp, sp
cmp byte [ttt], '*'
je strict short lx_69
mov dx, ttt+25
mov ah, 0x9
int 0x21
mov dx, ttt
mov ah, 0x9
int 0x21
lx_69:
mov al, 0xb2  ; '▓'
mov cx, 0x3
lx_6e:
int 0x29
int 0x29
int 0x29
int 0x29
int 0x29
dec al
loop lx_6e
mov si, [Header_arg_s]
lodsb
mov ah, 0x0
mov dx, ax
shr ax, 1
mov cx, 0x19
sub cx, ax
mov bx, cx
mov al, ' '
my_jcxz_strict_short lx_96
lx_92:
int 0x29
loop lx_92
lx_96:
mov cx, [si-0x1]
mov ch, 0x0
lx_9b:
lodsb
int 0x29
loop lx_9b
mov cx, 0x32
sub cx, bx
sub cx, dx
mov al, ' '
my_jcxz_strict_short lx_b0
lx_ac:
int 0x29
loop lx_ac
lx_b0:
mov al, 0xb0  ; '░'
mov cx, 0x3
lx_b5:
int 0x29
int 0x29
int 0x29
int 0x29
int 0x29
inc al
loop lx_b5
cmp byte [ttt], '*'
je strict short lx_d1
mov dx, ttt+9
mov ah, 0x9
int 0x21
lx_d1:
leave
ret 2

; procedure PrintLine(w: word); assembler;
%define PrintLine_arg_w (bp+4)
func_PrintLine:
push bp
mov bp, sp
mov al, [PrintLine_arg_w]
int 0x29
mov cx, 0x4e
mov al, 0xc4  ; '─'
lx_e9:
int 0x29
loop lx_e9
mov al, [PrintLine_arg_w+1]
int 0x29
leave
ret 0x2

_data:
ttt: db 27, '[44;30m$', 27, '[0m', 27, '[K$', 27, '[30;1m$', 27, '[0m$'
txtfn: db 'QUOTE.TXT', 0
idxfn: db 'QUOTE.IDX', 0
; Must be long enough (23 bytes) for overlap with qqq_... .
headermsg: db 34, 'PotterSoftware Quote Displayer 2.4'
footermsg: db 44, 'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.'
_data_end:

; _bss: (Uninitialized data.)
full equ 16384  ; Just a size.
buf equ _data_end+((_data_end-$$)&1)  ; array[0..full+4-1] of char;  Aligned.
var_s equ buf  ; string; overlaps buf
idx equ buf+full+4+((buf+full+4-$$)&1)  ; array[0..24160] of word;  ; Aligned.
qqq_a equ headermsg  ; word; overlaps headermsg.
qqq_b equ qqq_a+2  ; word; overlaps headermsg.
qqq_w equ qqq_b+2  ; word; overlaps headermsg.
qqq_l equ qqq_w+2  ; longint; overlaps headermsg.
qqq_max equ qqq_l+4  ; longint; overlaps headermsg.
qqq_oldl equ qqq_max+4  ; longint; overlaps headermsg.
qqq_xch equ qqq_oldl+4  ; char; overlaps headermsg. Contains the command-line argument character: 0 for missing or space (' '), otherwise uppercased ('A' to 'C').
qqq_before equ qqq_xch+1  ; word; overlaps headermsg, Not aligned.
qqq_ansich equ qqq_before+2  ; char; overlaps headermsg.
qqq_han equ qqq_ansich+1  ; word; overlaps headermsg. Filehandle.
