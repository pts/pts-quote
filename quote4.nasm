; -*- coding: utf-8 -*-
;
; quote4.nasm: PotterSoftware Quote Displayer V2.41 (NASM source code)
; (C) 1996--2022-03-27 by EplPáj of PotterSoftware, Hungary
; translation to NASM on 2022-03-27
;
; Compile it with NASM 0.98.39 .. 2.13.02 ...:
;
;   $ nasm -O0 -f bin -o quote4n.com quote4.nasm
;
; Alternatively, compile it with Yasm 1.2.0 or 1.3.0:
;
;   $ yasm -O0 -f bin -o quote4n.com quote4.nasm
;
; This source file is for archival purposes only.
; Bugfixes and features shouldn't be added to this file, but to quote42.nasm.
;
; This program (quote4n.com) is buggy (just like quote3.exe) in both DOSBox
; and QEMU, it usually hangs after printing the header correctly.
; It is because of the slow random number generator. It also has some other
; serious bugs, see BUG in the source code.
;
; This is version 2.41. It is functionally equivalent to version 2.33, but
; it's implemented in NASM (rather than Turbo Pascal 7.0 inline assembly).
; The original source code for version 2.40 was implemented in A86, but that
; has been lost.
;
; The QUOTE.IDX index file format is identical in version 2.30 .. 2.5? and
; different from version 2.60.
;
; This source code is based on the disassembly of quote3.exe generated by
; the Turbo Pascal compiler (tp70), but it has been changed since then to
; make it work as a DOS .com program, and it is also based on the source
; code quote3.pas (mostly for comments).
;
; It uses ANSI.SYS for color output, and it detects the lack of ANSI.SYS
; (such as in DOSBox), and then it prints colorless output.
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

_code:
_start:

; Increase DS and SS to accommodate for the total memory usage of 68 KiB (67
; KiB for code and data + 1 KiB for stack).
mov ah, 0x4a  ; https://stanislavs.org/helppc/int_21-4a.html
mov bx, 0x1100  ; Number of bytes needed == 0x1100 * 16, that's 68 KiB.
int 0x21
jnc strict short resize_ok
jmp strict near fatal_error
resize_ok:
mov ax, ds
add ax, seg_delta
mov ds, ax
mov es, ax  ; es will remain this way for most of the rest of the run.
mov ax, ss
add ax, 0x100  ; 1 KiB of stack at the end of the 68 KiB.
mov ss, ax

mov al, 0xd  ; Writeln
int 0x29
mov al, 0xa
int 0x29

push ds  ; Header ki
push strict word headermsg
call func_Header

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
; qqq_w:=XReset(IdxFn);
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
;jc strict near fatal_error  ; BUG: Fail.
mov [qqq_han], ax
sbb ax, ax
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
fatal_error:
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
;jc strict near fatal_error  ; BUG: Fail.
mov [qqq_han], ax
sbb ax, ax
; blockread(f, buf, $FFFF, qqq_a);
mov ah, 0x3f
mov bx, [qqq_han]
mov cx, 0xffff  ; BUG: To avoid buffer overflow, read just full+4 instead of $FFFF.
mov dx, buf
int 0x21
mov [qqq_a], ax  ; Save number of (compressed) bytes read to qqq_a.
; close(f);
mov ah, 0x3e
mov bx, [qqq_han]
int 0x21

mov cx, [qqq_a]
mov dx, 0x1
mov si, buf
mov di, idx+2
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
jmp strict near exit
lx_2d1:
; XReset(TXTFN);
mov ax, 0x3d00  ; Open for Read Only, C-Mode
mov dx, txtfn
int 0x21
;jc strict near fatal_error  ; BUG: Fail.
mov [qqq_han], ax
sbb ax, ax

; qqq_w:=random(qqq_a+1);  Then 0 <= qqq_w < qqq_a + 1.
;
; According to https://stanislavs.org/helppc/bios_data_area.html , dword [0x40:0x6c]
; is the daily timer counter: equal to zero at midnight; incremented by INT 8;
; read/set by int 0x1a. Thus this random number generator is very slow.
;
; First we generate a 16-bit random number based on the timer counter. The code for
; this is ad hoc and messy.
push es
lx_2df:
xor ax, ax
mov es, ax
mov ax, [es:0x46c]
xor ax, [es:0x46e]
mov bx, dx
xor ax, bx
mov cx, [es:0x46d]
mov bx, 0xe21
lx_2f8:
mul bx
add ax, 0xbe0
loop lx_2f8
; Now we have the 16-bit random number in ax. If it is small enough (qqq_a <= ax),
; then we are done, otherwise we generate another random number in a busy loop, also
; waiting for int 0x8 timer to tick. Thus this random number generator is very slow.
cmp ax, [qqq_a]
ja strict short lx_2df  ; BUG: This makes the random generator very slow.
mov [qqq_w], ax  ; Save random(qqq_a+1) to qqq_w.
pop es

mov word [qqq_l], 0x0  ; L kezdőoffszet kiszámolása
mov word [qqq_l+2], 0x0
mov si, idx
add si, [qqq_w]
add si, [qqq_w]
std
lx_321:
lodsw  ; L:=IDX[W]+IDX[W-1]+...+IDX[1]
add [qqq_l], ax
adc word [qqq_l+2], byte +0x0
cmp si, idx
jne strict short lx_321
cld
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
jmp strict near exit  ; Error: Line longer than 255 bytes.
lx_37b:
; Beállítjuk a string hosszát
dw 0x1e88, var_s  ; mov byte [var_s], bl  ; Workaround to prevent bug in yasm-1.2.0 and yasm-1.3.0: INTERNAL ERROR at modules/arch/x86/x86expr.c, line 417: unexpected expr op
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
push ds  ; Display the string "s" with "before" spaces in front of it
mov si, [qqq_w]
lodsb
mov cl, al
mov ch, 0x0
mov dx, cx
jcxz lx_438
mov cx, [qqq_before]
jcxz lx_41e
mov al, ' '
lx_41a:
int 0x29
loop lx_41a
lx_41e:
mov cx, dx
jcxz lx_427
lx_422:
lodsb
int 0x29
loop lx_422
lx_427:
mov cx, 0x4e
sub cx, [qqq_before]
sub cx, dx
jcxz lx_438
mov al, ' '
lx_434:
int 0x29
loop lx_434
lx_438:
pop ds
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
push ds
push strict word footermsg
call func_Header
mov ah, 0x3e  ; Close(F);
mov bx, [qqq_han]
int 0x21
exit:
mov ax, 0x4c00  ; EXIT_SUCCESS.
int 0x21  ; Exit to DOS.

; function GetNext: char; assembler;
func_GetNext:
cmp word [qqq_b], full+4  ; if qqq_b=full+4 then begin
jne strict short lx_33

; move(src:=buf[full], dst:=buf[0], 4);
  ; BUG: This code is completely buggy. It should be:
  ; mov si, buf + full
  ; mov di, buf
  ; movsw
  ; movsw
  xor di, buf
  add di, full
  mov ax, [buf]
  stosw
  mov ax, [buf+2]
  stosw
; blockread(f, buf[4], full, qqq_w);
mov ah, 0x3f
mov bx, [qqq_han]
mov cx, full
mov dx, buf+4
int 0x21
jnz strict short lx_2d  ; BUG: should be jnc.
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

; procedure Header(const s: OpenString); assembler;
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
push ds
lds si, [Header_arg_s]
lodsb
mov ah, 0x0
mov dx, ax
shr ax, 1
mov cx, 0x19
sub cx, ax
mov bx, cx
mov al, ' '
jcxz lx_96
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
pop ds
mov cx, 0x32
sub cx, bx
sub cx, dx
mov al, ' '
jcxz lx_b0
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
ret 0x4

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

times ((_code-$) & 15) nop  ; Align to paragraph (16) boundary with nop.
seg_delta equ (($-_code) >> 4) + 0x10

_data:
ttt_in_data: db 27, '[44;30m$', 27, '[0m', 27, '[K$', 27, '[30;1m$', 27, '[0m$'
ttt equ ttt_in_data-_data  ; Because of seg_delta.
txtfn_in_data: db 'QUOTE.TXT', 0
txtfn equ txtfn_in_data-_data  ; Because of seg_delta.
idxfn_in_data: db 'QUOTE.IDX', 0
idxfn equ idxfn_in_data-_data  ; Because of seg_delta.
; Must be long enough (23 bytes) for overlap with qqq_... .
headermsg_in_data: db 35, 'PotterSoftware Quote Displayer 2.41'
headermsg equ headermsg_in_data-_data  ; Because of seg_delta.
footermsg_in_data: db 44, 'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.'
footermsg equ footermsg_in_data-_data  ; Because of seg_delta.
_data_end:

; _bss: (Uninitialized data.)
full equ 16384  ; Just a size.
buf equ _data_end+((_data_end-$$)&1)-_data  ; array[0..full+4-1] of char;  Aligned.
var_s equ buf  ; string; overlaps buf
idx equ buf+full+4+((buf+_data+full+4-$$)&1)  ; array[0..24160] of word;  ; Aligned.
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