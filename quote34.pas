{$G+} {$F-} {$A-} {$D-} {$E-} {$I-} {$L-} {$S-} {$X-} { -*- coding: UTF-8 -*- }
{
quote34.pas: PotterSoftware Quote Displayer V2.34 (Turbo Pascal 7.0 inline assembly source code)
(C) 1996--2022-03-27 by EplPáj of PotterSoftware, Hungary

Compile it with Turbo Pascal 7.0 on DOS, generate quote34.exe: tpc quote34.pas

The QUOTE.IDX index file format is identical in version 2.30 .. 2.5? and
different from version 2.60.

It uses ANSI.SYS for color output, and it detects the lack of ANSI.SYS (such as
in DOSBox), and then it prints colorless output.

Command-line argument (first byte on the command-line):

* ' '-> Display a quote using index table (default).
* 'A'-> Display a quote using linear search.
* 'B'-> Create index table & then display a quote using it.
* 'C'-> Create index table.
}
program PotterSoftware_Quote_Displayer;

const
  full=16384;
  ttt: array[0..29] of char= #27'[44;30m$'#27'[0m'#27'[K$'#27'[30;1m$'#27'[0m$';
  txtfn: array[0..12] of char= 'QUOTE.TXT'#0#0#0#0;
  idxfn: array[0..12] of char= 'QUOTE.IDX'#0#0#0#0;
  headermsg: string[35]= 'PotterSoftware Quote Displayer 2.34';
  footermsg: string[44]= 'Greetings to RP,TT,FZ/S,Blala,OGY,FC,VR,JCR.';

var
  buf: array[0..full+4-1] of char;
  s: string absolute buf;
  idx: array[0..24160] of word;  { 1 less is enough, first element unused. TODO: Get rid of idx[0]. }
  qqq: record
    a,b,w: word;
    l, max, oldl: longint;
    xch: char;
    before: word;
    ansich: char;
    han: word;
  end absolute headermsg; { Must be long enough (23 bytes) }

function GetNext: char; assembler;
  asm
	cmp qqq.b, full+4                 { if qqq.b=full+4 then begin }
	jne @88

	mov si, offset buf + full  { move(buf[full], buf[0], 4); }
	mov di, offset buf
	movsw
	movsw

	{ blockread(f, buf[4], full, qqq.w); }
	mov ah, 3Fh
	mov bx, qqq.han
	mov cx, full
	mov dx, offset buf+4
	int 21h
	jnc @87
	mov ax, 4CF1h  { Abort on read error. }
	int 21h
@87:    mov qqq.b, 4                      { endif }

@88:    mov bx, qqq.b			{ GetNext:=Buf[qqq.B];}
	mov al, byte ptr buf[bx]
	inc qqq.b				{ inc(qqq.b); }
	add word ptr qqq.l,1		{ inc(qqq.l); }
	adc word ptr qqq.l[2], 0
end;

procedure Header(const s: OpenString); assembler;
  asm
        cmp byte ptr ttt, '*'  { Check ansi driver }
        je @71
        mov dx, offset ttt[25] { Reset every attributes first }
        mov ah, 9
        int 21h
        mov dx, offset ttt[0]
        mov ah, 9
	int 21h
@71:    mov al, 0b2h  { '▓' }
	mov cx, 3
@72:    int 29h; int 29h; int 29h; int 29h; int 29h
        dec al
        loop @72
	push ds
        lds si, s
        lodsb
	mov ah, 0
        mov dx, ax
	shr ax, 1
        mov cx, 25
        sub cx, ax
        mov bx, cx
        mov al, ' '
	jcxz @74
@75:    int 29h
	loop @75
@74:    mov cx, [ds:si-1]
	mov ch, 0
@76:    lodsb
	int 29h
        loop @76
        pop ds
        mov cx, 50
	sub cx, bx
        sub cx, dx
        mov al, ' '
	jcxz @78
@77:    int 29h
	loop @77
@78:    mov al, 0b0h  { '░' }
	mov cx, 3
@73:    int 29h; int 29h; int 29h; int 29h; int 29h
	inc al
	loop @73
	cmp byte ptr ttt, '*'
	je @79
	mov dx, offset ttt[9]
	mov ah, 9
	int 21h
@79:
end;

procedure PrintLine(w: word); assembler;
  asm
	mov al, byte ptr w
        int 29h
	mov cx, 78
	mov al, 0c4h  { '─' }
@70:    int 29h
	loop @70
	mov al, byte ptr w[1]
	int 29h
end;

label llc,lld,lle,llf,lls,after_random,fatal_error;

begin { Főprogram }
  asm { This statement is going to be long. Very long. }
	mov al, 13				{ Writeln }
	int 29h
	mov al, 10
	int 29h

	{ Detect ANSI.SYS. }
	xor ax, ax { ansi:=memw[0:$29*4+2]>memw[0:$20*4+2]; }
	mov es, ax
	mov bx, [es:$29+$29+$29+$29+2]
	cmp bx, [es:$20+$20+$20+$20+2]
	jae @95
	mov byte ptr ttt, '*' { This means there's no ANSI.SYS }
@95:

	push ds
	push offset headermsg
	call Header  { Print header. }

	{ Get parameter from beginning of command-line arguments. }
	mov ax, PrefixSeg  { xch:=char(mem[PrefixSeg:$81]); }
	mov es, ax
	mov al, [es:81h]
	cmp al, ' '
	jne @96  { if xch=' ' then xch:=char(mem[PrefixSeg:$82]); }
	mov al, [es:82h]  { First byte of command-line arguments. }
@96:    cmp byte ptr [es:80h], 0 { if mem[PrefixSeg:$80]=0 then xch:=' '; }
	jne @94
	mov al, ' '
@94:    and al, 255-32
	mov qqq.xch, al
	mov ax, ds
	{ es will remain this way for the rest of the run.
	  It affects es:, stosb, stosw, scasb, scasw, movsb, movsw, cmpsb, cmpsw. }
	mov es, ax
	{ qqq.w:=XReset(IdxFn); }
	mov ax, 3D00h { Open for Read Only, C-Mode }
	mov dx, offset idxfn
	int 21h
	mov qqq.han, ax
	sbb ax, ax { AX:=0, ha OK; AX:=$FFFF, ha hiba }
	mov word ptr idx, 0			{ idx[0]:=0 }
	cmp ax, 0                           { if (IOResult<>0) or (xch<>#0) then }
	jne @90
	cmp qqq.xch, 0
	jne @90
	jmp lls
@90:    { XReset(TXTFN); }
	mov ax, 3D00h { Open for Read Only, C-Mode }
	mov dx, offset txtfn
	int 21h
	jc fatal_error
	mov qqq.han, ax

	{  qqq.max:=filesize(f); }
	mov ax, 4202h
	mov bx, qqq.han
	xor cx, cx
        xor dx, dx
        int 21h
        mov word ptr qqq.max, ax
        mov word ptr qqq.max[2], dx
        mov ax, 4200h
	mov bx, qqq.han
	xor cx, cx
	xor dx, dx
	int 21h

	mov qqq.b, full+4               	{b:=full+4 }
	xor ax, ax
	mov word ptr qqq.l, ax          	{l:=0 }
	mov word ptr qqq.l[2], ax
	mov word ptr qqq.oldl, ax       	{oldl:=0 }
	mov word ptr qqq.oldl[2], ax
	mov qqq.a, 1                    	{ a:=1 }
	mov [offset buf+full], ax  { Make sure we don't detect CRLF+CRLF at the beginning. }

					{repeat }
@81:    call GetNext
	mov si, offset buf-4
	add si, qqq.b
	cmp word ptr [ds:si], $0A0D
	jne @82
	cmp word ptr [ds:si+2], $0A0D
	jne @82                            {  if buf[b-4]=newline then begin }

	mov ax, word ptr qqq.l                {    idx[a]:=l-oldl }
	mov dx, word ptr qqq.l[2]
	sub ax, word ptr qqq.oldl
	sbb dx, word ptr qqq.oldl[2]
	mov di, offset idx
	add di, qqq.a
	add di, qqq.a
	mov [ds:di], ax
	mov [ds:di+2], dx
	inc qqq.a                             {    inc(a) }
	mov ax, word ptr qqq.l                {    oldl:=l }
	mov word ptr qqq.oldl, ax
	mov ax, word ptr qqq.l[2]
	mov word ptr qqq.oldl[2], ax          {  end; }

@82:    mov ax, word ptr qqq.max              {until l=max }
	mov dx, word ptr qqq.max[2]
	cmp word ptr qqq.l, ax
	jne @81
	cmp word ptr qqq.l[2], dx
	jne @81

	{ Now qqq.a == (number of quotes) + 1. }
	{ close(f); }
	mov ah, 3Eh
	mov bx, qqq.han
	int 21h

	cmp qqq.xch, 'A' { Nem írjuk ki az IT-t, ha az A par. van }
	je llc
	mov cx, qqq.a
	dec cx
	mov si, offset idx+2
	mov di, offset buf
	xor dx, dx
@83:    lodsw
	stosb
	cmp ax, 240
	jb @84
	dec di
	rol ax, 8
	or ax, 11110000b
	stosw
@84:    loop @83
	sub di, offset buf  { DI := number of compressed bytes to write. }

        { XRewrite(IDXFN); }
        mov ah, 3Ch { Create file }
        mov cx, 0
        mov dx, offset idxfn
	int 21h
	jnc @91
fatal_error:
        mov ax, 4CF0h
	int 21h { Fatal error }
@91:    { blockwrite(f, buf, compressed_size); }
	mov ah, 40h
	mov bx, qqq.han
	mov cx, di
	mov dx, offset buf
	int 21h
	{ close(f); }
	mov ah, 3Eh
	mov bx, qqq.han
	int 21h
	{ goto c; }
	jmp llc
				{ end else begin }
lls:    { XReset(IDXFN); }
	mov ax, 3D00h { Open for Read Only, C-Mode }
	mov dx, offset idxfn
	int 21h
	jc fatal_error
	mov qqq.han, ax
	{ blockread(f, buf, full+4, reg_ax); }
	mov ah, 3Fh
	mov bx, qqq.han
	mov cx, full+4
        mov dx, offset buf
        int 21h
	mov cx, ax  { Save number of (compressed) bytes read to cx, for below. }
	{ close(f); }
	mov ah, 3Eh
	mov bx, qqq.han
	int 21h

	mov dx, 1
	mov si, offset buf
	mov di, offset idx+2
@85:    lodsb
	mov ah, 0
	stosw
	cmp al, 240
	jb @86
	dec di
	dec di
	and al, 15
	mov ah, al
	lodsb
	stosw
	dec cx
@86:    inc dx
	loop @85
	mov qqq.a, dx  { qqq.a := (number of quotes) + 1. }
llc:    cmp qqq.xch, 'C'
	je llf

	{ XReset(TXTFN); }
	mov ax, 3D00h { Open for Read Only, C-Mode }
	mov dx, offset txtfn
	int 21h
	jc fatal_error
	mov qqq.han, ax
	{ Now qqq.a-1 is the number of quotes in txtfn, provided that txtfn ends with CRLF + CRLF. }
	xor ax, ax
	mov word ptr qqq.l, ax  { L kezdőoffszet kiszámolása }
	mov word ptr qqq.l+2, ax
	mov si, qqq.a
	test si, si
	jz after_random  { If there are 0 quotes, print from the beginning of txtfn. }
	dec si  { SI := Number of quotes. }

	{ DX:=random(SI);  Then 0 <= SI < DX.
	  This code may ruin AX, BX, CX, SI, DI, BP and FLAGS.

	  This code generates a 32-bit random number n in a register pair, then computes
	  DX := (n * SI) >> 32 as the random value.
	}
	push bp
	{mov ah, 0}  { Not needed, AX=0 above. }
	int 01ah  { Get time-random seed in CX:DX. }
	xor bp, bp
	mov ax, cs
	add ax, dx  { Modify seed. }
	mov bx, ax
	mov dx, 08405h
	mul dx
	shl bx, 3
	add ch, cl
	add dx, bx
	add dx, cx
	shl cx, 2
	add dx, cx
	add dh, bl
	shl cx, 5
	add ax, 1  { Modifies CF (inc ax doesn't).. }
	adc dx, bp
	mov bx, dx
	mul si
	mov ax, bx
	mov bx, dx
	mul si
	add ax, bx
	adc dx, bp  { DX:=random(SI) }
	pop bp
	jz after_random  { If the chosen random number is 0, print from the beginning of txtfn. }

        mov si, offset idx
	add si, dx
	add si, dx
	std
@97:    lodsw                             { L:=IDX[W]+IDX[W-1]+...+IDX[1] }
	add word ptr qqq.l, ax
	adc word ptr qqq.l[2], 0
	cmp si, offset idx
	jne @97
	cld

after_random:
	push $BFDA { ┌┐ }                 { Keret ki }
	call PrintLine

lld:    { seek(f, qqq.l); }
        mov ax, 4200h
	mov bx, qqq.han
        mov dx, word ptr qqq.l
        mov cx, word ptr qqq.l[2]
        int 21h
        { blockread(f, s[1], 255, qqq.w); }
        mov ah, 3Fh
        mov bx, qqq.han
        mov cx, 255
        mov dx, offset s+1
        int 21h
        mov qqq.w, ax

        cmp qqq.w, 0			{ Stop at EOF }
        je lle
        mov bx, 0			{ Look for #13 to determine length(s) }
        mov si, offset s+1
@12:    or bh, bh
        jnz @13
        cmp byte ptr [si+bx], 13
        je @11
	inc bx
        jmp @12
@13:    jmp fatal_error { Error: Line longer than 255 bytes. }
@11:    mov byte ptr s, bl { Beállítjuk a string hosszát }
        inc bx
        inc bx
        add word ptr qqq.l, bx { inc(l,length(s)+2); }
        adc word ptr qqq.l[2], 0

	{If S='' align returns TRUE else it returns FALSE. Align prints S with the
	correct color & alignment according to the control codes found in S[1,2]}

{ START OF ALIGN }

	{ Calculate the value of BEFORE first using up AnsiCh: #0=Left '-'=Right
	'&'=Center alignment }
	mov cx, ds
        mov si, offset s
        mov qqq.w, si
        lodsb
	cmp al, 0
        jne @d
        mov al, 1
        mov ds, cx
	jmp @9 { Empty string: do nothing but restore original CS }
@d:     mov qqq.ansich, 0 { AnsiCh is 0 by default }
        cmp byte ptr [ds:si], '-'
        jne @c
        mov al, [ds:si+1]
        mov qqq.ansich, al
        add qqq.w, 2 { If not AnsiCh<>0 the 1st 2 char won't be in the str }
        mov al, [ds:si-1]
        dec ax
        dec ax
        mov [ds:si+1],al
@c:     mov ah, 0
        mov ds, cx
        mov bx, 78
        cmp qqq.ansich, 0
        jne @a
	mov al, 0
        mov bx, 0
@a:     cmp qqq.ansich, '&'
        jne @b
        mov bx, 39
        shr ax, 1
@b:     sub bx, ax
        mov qqq.before, bx
        mov al, 0b3h  { '│' } { The line starts by this }
        int 29h
        cmp byte ptr ttt, '*' { Put out an ANSI EscSeq to set color if needed }
        je @6
        mov ah, 9
	mov al, qqq.ansich
	cmp al, 0
        je @6
        add al, 10
        mov byte ptr ttt[17+3], al
        mov dx, offset ttt[17]
        int 21h
	mov qqq.ansich, 0
@6:     push ds { Display the string "s" with "before" spaces in front of it }
        mov si, qqq.w
        lodsb
        mov cl, al
        mov ch, 0
        mov dx, cx
        jcxz @1
        mov cx, qqq.before
        jcxz @5
        mov al, ' '
@2:     int 29h
        loop @2
@5:     mov cx, dx
        jcxz @8
@3:     lodsb
        int 29h
        loop @3
@8:     mov cx, 78
        sub cx, qqq.before
	sub cx, dx
	jcxz @1
	mov al, ' '
@4:     int 29h
	loop @4
@1:     pop ds
	cmp byte ptr ttt, '*' { Restore original color via ANSI EscSeq if needed }
	je @7
	mov ah, 9
	mov dx, offset ttt[25]
	int 21h
@7:     mov al, 0b3h  { '│' } { The line ends by this, too }
	int 29h
	mov al, 0 { The return value is FALSE }

{ END OF ALIGN }

@9:     or al, al
	jz lld             	{ Ha FALSE-t ad vissza, még van köv. sor }
				{ Különben lábléc és program vége }
lle:    push $D9C0	{ └┘ }
	call PrintLine
	push ds
	push offset footermsg
	call Header
	mov ah, 3Eh      { close(F); }
	mov bx, qqq.han
	int 21h
llf:end; { ASM Statement. Good bye, reader. }
end.
