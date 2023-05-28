f_width equ 10
f_height equ 10
f_size equ f_width*f_height

head  equ '#' 
empty equ '.' 
apple equ '@' 

waitPeriodMs equ 300

section .data
	winMsg  db 10, "You won!", 10, 0
	loseMsg db 10, "You lost!", 10, 0

	field: times f_size db empty 

	dirsX dd -1, 0, 1, 0
	dirsY dd 0, -1, 0, 1
	dirChars db '<', '^', '>', 'v' 
	inputs db 'a', 'w', 'd', 's'
	
	headDir db 0


	newline db 10

%macro coordsToIndex 2
	push ebx
	push edx
	
	mov eax, %2
	mov ebx, f_width
	mul ebx
	add eax, %1

	pop edx
	pop ebx
%endmacro

%define systcall int 0x80

ss_read equ 0x3
ss_write equ 0x4
ss_exit equ 0x1

%macro pushChar 1
	mov eax, [pbCount]
	mov [printbuf+eax], byte %1
	inc dword [pbCount]
%endmacro

%macro pushZString 1
	mov ebx, %1
%%next:
	mov cl, [ebx]
	test cl, cl
	 jz %%out
	pushChar cl
	inc ebx
	 jmp %%next
%%out:
%endmacro

%macro writeChars 0
	mov eax, ss_write
	mov ebx, 1
	mov ecx, printbuf
	mov edx, [pbCount]
	mov [pbCount], dword 0
	systcall
%endmacro

%macro exit 0
	mov eax, ss_exit
	mov ebx, 0
	systcall
%endmacro

section .bss
	printbuf resb 1024
	pbCount resd 1

	frameIndex resd 1

	headX resd 1
	headY resd 1
	tailX resd 1
	tailY resd 1
	
	ateApple resb 1

	rand resd 1

	sleepReq resd 2
	
	appleGenUseArr resb 1
	appleGenArr resd f_size

	inputBuf resb 1024

termios:
	c_iflag resd 1
	c_oflag resd 1
	c_cflag resd 1
	c_lflag resd 1
	c_lone  resb 1
	ic_cc   resb 19


printbuf_size equ $-printbuf

%macro aaa 1
	mov eax, [%1]
	call print_eax
%endmacro

%macro sleep 2
	mov [sleepReq], dword %1
	mov [sleepReq+4], dword %2
	mov eax, 0xA2
	mov ebx, sleepReq
	mov ecx, 0
	systcall
%endmacro


section .text
	global _start

;stackoverflow.com/a/3062783
advanceRNG:
a equ 1103515245
	push ebx
	push edx
	mov eax, [rand]
	mov ebx, a
	mul ebx
	add eax, 12345
	and eax, 0x7FFFFFFF
	mov [rand], eax
	pop edx
	pop ebx
	ret

;stackoverflow.com/a/62939804
_make_concole_nonblocking:
	mov eax, 54
	mov ebx, 0
	mov ecx, 0x5401
	mov edx, termios
	systcall

	and byte [c_lflag], 0x0FD

	mov eax, 54
	mov ebx, 0
	mov ecx, 0x5402
	mov edx, termios
	systcall

	ret

_start:
	call _make_concole_nonblocking

	rdtsc
	mov [rand], eax
	mov ebx, 10
	;mov [rand],dword 2

	;initialize head and tail positions
	mov eax, f_width/2
	mov ebx, f_height/2
	mov [headX], eax
	mov [headY], ebx
	mov [tailX], eax
	mov [tailY], ebx

;setup head
	coordsToIndex [headX], [headY]
	mov [field + eax], byte head 

	call gen_apple
_gameLoop:
	call move_beg
	call print_field
	
	;mov eax, [frameIndex]
	;inc dword [frameIndex]
	;call print_eax
	;aaa headX
	;aaa headY
	;aaa tailX
	;aaa tailY
	;xor eax, eax
	;mov al, [headDir]
	;call print_eax
	
	sleep (waitPeriodMs / 1000), (waitPeriodMs % 1000)*1000000 
	call _read_input
	call move_snake
	
	 jmp _gameLoop
	
	exit

print_field:
	xor esi, esi
_printFieldLine:
	mov eax, ss_write
	mov ebx, 1
	lea ecx, [field+esi]
	mov edx, f_width
	systcall

	mov eax, ss_write
	mov ebx, 1
	mov ecx, newline
	mov edx, 1
	systcall
	
	add esi, f_width
	cmp esi, f_size
	 jne _printFieldLine

	ret

gen_apple:
	mov al, [appleGenUseArr]
	test al, al
	 jnz _genAppleArr

	xor ecx, ecx
	dec ecx
_tryGenApple:
	inc ecx
	cmp ecx, 5
	 je _genAppleSwitchToArr
	call advanceRNG
	xor edx, edx
	mov ebx, f_size
	div ebx
	
	mov bl, [field+edx]
	cmp bl, '.' 
	 jne _tryGenApple

	mov [field+edx], byte apple
	ret

_genAppleSwitchToArr:
	mov [appleGenUseArr], byte 1
_genAppleArr:
	xor edi, edi
	xor eax, eax
	dec eax
_fillAppleArrLoop:
	inc eax
	cmp eax, f_size
	 je _appleArrFind
	mov cl, [field + eax]
	cmp cl, empty
	 jne _fillAppleArrLoop
	mov [appleGenArr+edi], eax
	inc edi
	jmp _fillAppleArrLoop
_appleArrFind:
	test edi, edi
	 je winGame

	call advanceRNG
	xor edx, edx
	mov ebx, edi
	div ebx
	xor eax, eax
	mov al, [appleGenArr+edx]
	mov [field+eax], byte apple
	
	ret
	
winGame:
	pushZString winMsg
	writeChars
	exit

loseGame:
	pushZString loseMsg
	writeChars
	exit

move_beg:
	mov [pbCount], dword 0
	pushChar 27
	pushChar '['
	pushChar 'H'
	pushChar 27
	pushChar '['
	pushChar 'J'
	writeChars
	ret

move_snake:
	coordsToIndex [headX], [headY]
	mov esi, eax
	coordsToIndex [tailX], [tailY]
	mov edi, eax
	
	xor ecx, ecx
	mov cl, [headDir]
	push ecx

	;make head point in the direction of new head
	mov al, [dirChars + ecx]
	mov [field+esi], al

	mov al, [ateApple]
	test al, al
	 jnz _updateHead

	;move tail to the next position
	mov al, [field + edi]       ;char with tail dir
	mov [field+edi], byte empty ;replace tail with empty
	xor edx, edx                ;tail dir index
	not edx
find_tail_dir:
	inc edx
	cmp al, [dirChars + edx]
	 jne find_tail_dir

	mov ecx, edx

%macro updateCoord 3
	mov ebx, %3
	mov eax, [%1+ecx*4]
	add eax, %2
	
	cmp eax, 0
	 jge %%skipAdd
	add eax, ebx
%%skipAdd:
	cmp eax, ebx
	 jl %%skipSub
	sub eax, ebx
%%skipSub:
	mov %2, eax

	;xor edx, edx
	;mov ebx, %3
	;div ebx
	;mov %2, edx	
%endmacro
	
	updateCoord dirsX, [tailX], f_width
	updateCoord dirsY, [tailY], f_height
			
_updateHead:
	mov [ateApple], byte 0
	pop ecx

	updateCoord dirsX, [headX], f_width
	updateCoord dirsY, [headY], f_height
	coordsToIndex [headX], [headY]
	mov bl, [field+eax]
	cmp bl, empty
	 je _moveSnakeOk
	cmp bl, apple
	 je _moveSnakeAteApple
	jmp loseGame
_moveSnakeAteApple:
	mov [ateApple], byte 1
	push eax
	call gen_apple
	pop eax
_moveSnakeOk:
	mov [field+eax], byte head 
	ret

_read_input:
	mov eax, ss_read
	mov ebx, 0
	mov ecx, printbuf
	mov edx, 102
	systcall
	
	cmp eax, 0
	jle _input_not_found

	mov bl, [printbuf+eax-1]
	xor eax, eax
	not eax
convert_input_loop:
	inc eax
	cmp bl, [inputs + eax]
	 je input_found
	cmp al, 3
	 jne convert_input_loop
_input_not_found:
	ret
input_found:
	mov [headDir], al
	ret

print_eax:
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	xor esi, esi           ;-int size
	mov ecx, 10            ;divider
	mov [printbuf+16], byte 10	
_putDigitLoop:
	xor edx, edx
	div ecx
	add edx, '0'
	mov [printbuf+15 + esi], dl
	dec esi
	test eax, eax
	jnz _putDigitLoop
	
	mov eax, ss_write
	mov ebx, 1
	lea ecx, [printbuf+16 + esi]
	neg esi
	mov edx, esi
	inc edx
	systcall

	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax

	ret
