INCLUDE Irvine32.inc

DIM equ 20
NUM_SQUARES equ(DIM * DIM)
NUM_MINES equ 30

LOST equ 1
WON equ 2

EMPTY equ ' '
FLAG equ 'F'
MINE equ '*'

.data
try_msg BYTE "Try again? (y/n)", 0
win_msg BYTE "Congratulations! You win!", 0
lose_msg BYTE "Sorry, you lost.", 0
input_err_msg BYTE "Error: row or col is out of bounds, try again.", 0
mov_prompt_msg BYTE "Flag (f) or reveal (r)? ", 0
row_prompt_msg BYTE "Enter row: ", 0
col_prompt_msg BYTE "Enter col: ", 0

board BYTE NUM_SQUARES DUP(EMPTY)
swept BYTE NUM_SQUARES DUP(EMPTY)
num_revealed DWORD 0
end_flag BYTE 0

.code
;// A macro that calls a procedure for each adjacent tile
;// Receives: row in EDX, col in EBX, and proc name in visit_proc
m_visit_adj macro visit_proc : req
	push edx
	push ebx
	dec edx			;;// upper
	call visit_proc
	inc ebx			;;// upper-right
	call visit_proc
	inc edx			;;// right
	call visit_proc
	inc edx			;;// bottom-right				
	call visit_proc
	dec ebx			;;// bottom
	call visit_proc
	dec ebx			;;// bottom-left
	call visit_proc
	dec edx			;;// left
	call visit_proc
	dec edx			;;// upper-left
	call visit_proc
	pop ebx
	pop edx
endm

;// A macro that exits if current loc is out of bounds
;// Receives: row in EDX, col in EBX, and exit dest in exit_label
m_validate_loc macro exit_label:req
	cmp edx, 0
	jl exit_label
	cmp edx, DIM
	jge exit_label
	cmp ebx, 0
	jl exit_label
	cmp ebx, DIM
	jge exit_label
endm

m_print_msg macro msg:req, line:req
	mov dh, line
	mov dl, DIM + 4
	call Gotoxy
	mov edx, OFFSET msg
	call WriteString
endm

;// Generates a random row and col
;// Returns: row in EDX and col in EBX
get_rand_loc proc uses eax
	mov eax, DIM
	call RandomRange
	mov edx, eax
	mov eax, DIM
	call RandomRange
	mov ebx, eax
	ret
get_rand_loc endp

;// Increments the proximity counter for a tile
;// Receives: row in EDX and col in EBX
inc_prox_tile proc uses eax edx
	m_validate_loc cannot_inc

	call is_mine
	cmp eax, 1
	je cannot_inc

	imul edx, edx, DIM
	cmp board[ebx + edx], EMPTY
	jne has_prox_val
	mov board[ebx + edx], '0'

	has_prox_val:
		inc board[ebx + edx]

	cannot_inc:
		ret
inc_prox_tile endp

;// Generates mines and adjacent proximity values
init_board proc uses eax ebx ecx edx
	mov ecx, NUM_MINES
	gen_mine:
		call get_rand_loc
		call is_mine

		cmp eax, 1
			jz gen_mine

		m_visit_adj inc_prox_tile
		imul edx, edx, DIM
		mov board[ebx + edx], MINE
		loop gen_mine

	ret
init_board endp

;// Prints the board tile indexed by a row and col
;// Recieves row in EDX and col in EBX
print_tile proc uses eax edx
	imul edx, edx, DIM
	xor eax, eax
	cmp swept[ebx + edx], 1
	jnz print_hidden

	cmp board[ebx + edx], MINE
	jz print_opened
	cmp board[ebx + edx], EMPTY
	jz print_opened

	movzx eax, board[ebx + edx]
	sub eax, 30h

	print_opened:
		add eax, 240
		call SetTextColor
		mov al, board[ebx + edx]
		call WriteChar
		ret

	print_hidden:
		cmp swept[ebx + edx], EMPTY
		jz not_flagged
		mov eax, 12

	not_flagged:
		add eax, 128
		call SetTextColor
		mov al, swept[ebx + edx]
		call WriteChar
		ret
print_tile endp

;// Prints a row of single digits for IDing cols
print_col_nums proc uses eax ecx
	mov eax, 15
	call SetTextColor
	mov ecx, DIM
	mov al, ' '
	call WriteChar
	mov al, '0'

	print_col_num:
		cmp al, '9'
		jle valid_col_char
		mov al, '0'

		valid_col_char :
			call WriteChar
			inc al

		loop print_col_num

	call Crlf
	ret
print_col_nums endp

;// Prints the board
print_board proc uses eax ecx edx ebx
	call Clrscr
	call print_col_nums
	mov al, '0'
	xor edx, edx
	jmp loop_row

	next_row:
		push eax
		mov eax, 15
		call SetTextColor
		pop eax
		call WriteChar
		call Crlf
		inc al
		cmp al, '9'
		jle valid_row_char
		mov al, '0'

		valid_row_char:		
			inc edx
			cmp edx, DIM
			jz print_done

	loop_row:
		call WriteChar
		xor ebx, ebx
	
		loop_col:
			call print_tile
			inc ebx
			cmp ebx, DIM
			jz next_row
			jmp loop_col
	
	print_done:
		call print_col_nums
		ret
print_board endp

;// Checks location on board for a mine
;// Recieves row in EDX and col in EBX
;// Returns 0 or 1 in EAX
is_mine proc uses edx
	imul edx, edx, DIM
	cmp board[ebx + edx], MINE
	jne not_mine
	mov eax, 1
	ret

	not_mine:
		xor eax, eax

	ret	
is_mine endp

;// Prints prompt and gets input from user
;// Returns: move type in AL, row in EDX, and col in EBX
get_input proc uses ecx

	jmp try_input

	failed_input:
		call print_board
		m_print_msg input_err_msg, 4


	try_input:
		m_print_msg mov_prompt_msg, 0
		call ReadChar
		call WriteChar
		mov cl, al

		m_print_msg row_prompt_msg, 1
		call ReadDec
		mov ebx, eax

		m_print_msg col_prompt_msg, 2
		call ReadDec
		mov edx, eax
		xchg edx,ebx

		;// Check if position in bounds
		m_validate_loc failed_input
		cmp cl, "r"
		je valid_input
		cmp cl, "f"
		jne failed_input

	valid_input:
		mov al, cl
		ret
get_input endp

;// Recursively reveals empty squares
;// Recieves: row in EDX and col in EBX
rec_reveal proc uses edx ebx

	;// Check if position in bounds
	m_validate_loc skip

	push edx
	imul edx, edx, DIM

	;// Reveal if not flagged or already revealed
	cmp swept[ebx + edx], EMPTY
	jne base_case
	mov swept[ebx + edx], 1
	inc num_revealed

	;// If position is empty, call rec_reveal on adj tiles
	cmp board[ebx + edx], EMPTY
	jne base_case
	pop edx
	m_visit_adj rec_reveal
	ret

	base_case:
		pop edx

	skip:
		ret
rec_reveal endp

;// Checks for a mine in revealed tile,
;// and calls rec_reveal on tiles position if needed
;// Recieves: row in EDX and col in EBX
reveal proc uses eax
	call is_mine
	cmp eax, 1
	je game_over
	push edx
	imul edx, edx, DIM
	cmp swept[ebx + edx], FLAG
	jne not_flagged
	mov swept[ebx + edx], EMPTY
	
	not_flagged:
		pop edx
		call rec_reveal
		ret

	game_over:
		mov end_flag, LOST
		ret
reveal endp

;// Processes player input
player_move proc
	call get_input
	cmp al, 'f'
	je place_flag
	call reveal
	ret

	place_flag:
		imul edx, edx, DIM
		cmp swept[ebx + edx], 1
		je skip_flagging
		mov swept[ebx + edx], FLAG
	
	skip_flagging:
		ret
player_move endp

;// Checks to see if the player has revealed all non-mine tiles
;// Returns a 0 or 1 in eax
has_won proc uses ebx
	xor eax, eax
	mov ebx, NUM_SQUARES
	sub ebx, num_revealed
	
	cmp ebx, NUM_MINES
	jne no_win
	inc eax

	no_win:
		ret
has_won endp

;// Resets the board to it's preinitialized state
reset_board proc uses ecx
	mov end_flag, 0
	mov num_revealed, 0
	mov ecx, 0

	reset_loop:
		mov board[ecx], EMPTY
		mov swept[ecx], EMPTY
		inc ecx
		cmp ecx, NUM_SQUARES
		jne reset_loop
	ret
reset_board endp

;// Holds the game loop and end conditions
main proc
	jmp play

	replay:
		call reset_board

	play:
		call init_board

	game_loop:
		call print_board
		call player_move
		cmp end_flag, 1
		je lose_end
		call has_won
		cmp eax, 1
		je win_end
		jmp game_loop

	win_end:
		mov ecx, -1
		
		flag_loop:
			inc ecx
			cmp ecx, NUM_SQUARES
			je print_win
			cmp board[ecx], MINE
			jne flag_loop
			mov swept[ecx], FLAG
			jmp flag_loop

		print_win:
			call print_board
			m_print_msg win_msg, 4
			jmp get_retry

	lose_end:
			mov ecx, -1

			reveal_loop :
				inc ecx
				cmp ecx, NUM_SQUARES
				je print_lose
				cmp board[ecx], MINE
				jne reveal_loop
				mov swept[ecx], 1
				jmp reveal_loop

			print_lose :
				call print_board
				m_print_msg lose_msg, 4

	get_retry:
		m_print_msg try_msg, 5
		call ReadChar
		cmp al, 'y'
		je replay
		cmp al, 'n'
		je finished
		jmp get_retry
	
	finished:
		mov dh, DIM+5
		mov dl, 0
		call Gotoxy
		exit
main endp
end main