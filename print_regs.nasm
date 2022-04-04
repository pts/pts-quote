; by pts@fazekas.hu at Mon Apr  4 16:13:30 CEST 2022

bits 16
cpu 8086

; Prints registers AX, BC, CX, DX, SI, DI in hex, then prints CRLF.
; Keeps all flags and registers intact.
print_regs:
	pushf
	push ax
	push cx
	push dx
	;
	push dx
	push cx
	push ax
	mov al, 'A'
	int 29h
	mov al, 'X'
	int 29h
	pop dx
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 'B'
	int 29h
	mov al, 'X'
	int 29h
	mov dx, bx
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 'C'
	int 29h
	mov al, 'X'
	int 29h
	pop dx
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 'D'
	int 29h
	mov al, 'X'
	int 29h
	pop dx
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 'S'
	int 29h
	mov al, 'I'
	int 29h
	mov dx, si
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 'D'
	int 29h
	mov al, 'I'
	int 29h
	mov dx, di
	call print_dx_hex
	mov al, ' '
	int 29h
	mov al, 13
	int 29h
	mov al, 10
	int 29h
	;
	pop dx
	pop cx
	pop ax
	popf
	ret
	
l6j:	jmp strict short l6

; Clobbers AX and CX.
print_dx_hex:
	mov cx, 0404h
.l2x:	rol dx, cl
	mov al, dl
	and al, 15
	cmp al, 9
	jna .l1x
	add al, 'A'-'0'-10
.l1x:	add al, '0'
	int 29h
	dec ch
	jnz .l2x
	ret
