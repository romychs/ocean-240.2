; ======================================================
; Ocean-240.2
; Turbo monitor
;
; Disassembled by Romych 2025-09-09
; ======================================================

	DEVICE NOSLOT64K

	INCLUDE	"io.inc"
	INCLUDE "equates.inc"
	INCLUDE "external_ram.inc"
	INCLUDE "bios_entries.inc"

	OUTPUT tmon_E000.bin


	MODULE	TURBO_MONITOR

	ORG		0xE000

; ------------------------------------------------------
; Monitor Entry points
; ------------------------------------------------------

start:				JP	m_init						; E000
mon_cold_start:		JP	m_cold_start				; E003
non_con_status:		JP	m_con_status				; E009
mon_con_in:			JP	tm_con_in					; E00C
mon_con_out:		JP	m_con_out					; E00F
mon_serial_in:		JP	m_serial_in					; E012
mon_serial_out:		JP	m_serial_out				; E015
mon_char_print:		JP	tm_char_print				; E018
mon_tape_read:		JP	m_tape_read					; E01B
mon_tape_write:		JP	m_tape_write				; E01E
ram_disk_read:		JP	m_ramdisk_read				; E021
ram_disk_write:		JP	m_ramdisk_write				; E024
mon_free_fn1:		JP	m_cold_start				; E027
mon_free_fn2:		JP	m_cold_start				; E02A
mon_tape_wait:		JP	m_tape_wait					; E02D
mon_tape_detect:	JP	m_tape_blk_detect			; E030
read_floppy:		JP	m_read_floppy				; E033
write_floppy:		JP	m_write_floppy				; E036


; ------------------------------------------------------
; Init system devices
; ------------------------------------------------------
m_init:
    DI
    LD	SP, TM_VARS.rst_ret_JP
    LD	A, 10000000b								; DD17 all ports to out
    OUT	(SYS_DD17CTR), A							; VV55 Sys CTR
    OUT	(DD67CTR), A								; VV55 Video CTR

    CALL	m_init_kbd_tape
    LD	A, 01111111b								; VSU=0, C/M=1, FL=111, COL=111
    OUT	(VID_DD67PB), A								; color mode
    LD	A, 00000001b
    OUT	(SYS_DD17PB), A								; Access to VRAM
    LD	B, 0x0
    LD	HL, 0x3f00
    LD	A, H
    ADD	A, 65			      						; A=128 0x80

	; Clear memory from 0x3F00 to 0x7FFF
i_fill_video:
    LD	(HL), B
    INC	HL
    CP	H
    JP	NZ, i_fill_video
    XOR	A
    OUT	(SYS_DD17PB), A								; Disable VRAM
    LD	A, 00000111b
    OUT	(SYS_DD17PC), A								; pix shift to 7
    LD	(TM_VARS.m_pix_shift), A
    XOR	A
    LD	(TM_VARS.m_screen_mode), A
    LD	(TM_VARS.m_row_shift), A

	; Set color mode and palette
    LD	(TM_VARS.m_curr_color+1), A
    CPL
    LD	(TM_VARS.m_curr_color), A
    LD	A, 00000011b
    LD	(TM_VARS.m_cur_palette), A
	; VSU=0, C/M=1, FL=000, COL=011
	; color mode, black border
	; 00-black, 01-red, 10-purple, 11-white
    LD	A, 01000011b
    OUT	(VID_DD67PB), A

	; config LPT
    LD	A, 0x4
    OUT	(DD67PC), A		    						; bell=1, strobe=0
    LD	(TM_VARS.m_strobe_state), A	   				; store strobe
    LD	HL,1024			   							; 683us
    LD	(TM_VARS.m_beep_period), HL
    LD	HL, 320										; 213us
    LD	(TM_VARS.m_beep_duration), HL

	; Config UART
    LD	A, 11001110b
    OUT	(UART_DD72RR), A
    LD	A, 00100101b
    OUT	(UART_DD72RR), A

	; Config Timer#1 for UART clock
    LD	A, 01110110b								; tmr#1, load l+m bin, sq wave
    OUT	(TMR_DD70CTR), A

	; 1.5M/10 = 150kHz
    LD	A, 10
    OUT	(TMR_DD70C2), A
    XOR	A
    OUT	(TMR_DD70C2), A

	; Config PIC
    LD	A,00010010b									; ICW1 edge trigger, interval 8, sin...
    OUT	(PIC_DD75RS), A
    XOR	A
    OUT	(PIC_DD75RM), A								; ICW2
    CPL
    OUT	(PIC_DD75RM), A								; ICW3 no slave
    LD	A,00100000b
    OUT	(PIC_DD75RS), A								; Non-specific EOI command, End of I...
    LD	A, PIC_POLL_MODE
    OUT	(PIC_DD75RS), A								; Poll mode, poll on next RD

	; Init cursor
    CALL	m_draw_cursor
    LD	HL, TM_VARS.tm_stsp
    LD	(TM_VARS.tm_stack_0), HL					; tm_stack_0 - directly not used elsewhere
    LD	A, JP_OPCODE
    LD	(EXT_RAM.RST1), A
    LD	HL, m_rst1_handler
    LD	(EXT_RAM.RST1_handler_addr), HL

	; Beep
    LD	C, BELL_CHAR
    CALL	m_con_out
    LD	A, (BIOS.boot_f)
    CP	JP_OPCODE
    JP	Z, BIOS.boot_f
    LD	HL,	msg_hw_mon
    CALL	m_out_strz
    JP	m_cold_start

m_out_strz:
    LD	C, (HL)
    LD	A, C
    OR	A
    RET	Z
    CALL	m_con_out
    INC	HL
	JP	m_out_strz

msg_hw_mon:
    DB	"\r\nHARDWARE MONITOR+ V1\r\n", 0
    DS	3, 0xFF

m_init_kbd_tape:
    LD	A, 10010011b
	; Configure KBD/TAPE VV55
	; A - In, B-Out, Ch-Out, Cl-In
    OUT	(KBD_DD78CTR), A
    LD	A, PORT_C4
    OUT	(KBD_DD78PC), A
    XOR	A
    OUT	(KBD_DD78PC), A
    XOR	A
    LD	(TM_VARS.m_last_key), A
    RET

; ------------------------------------------------------
;  Console status
;  Out: A = 0 - not ready
;       A = 0xFF - ready (key pressed)
; ------------------------------------------------------
m_con_status:
    LD	A, (TM_VARS.m_last_key)
    OR	A
    JP	Z, mc_check_irq
    LD	A, 0xff										; ready
    RET

	; ckeck keyboard IRQ
mc_check_irq:
    IN	A, (PIC_DD75RS)
    AND	KBD_IRQ
    RET	Z											; no int from keyboard

	; read keyboard data
    IN	A, (KBD_DD78PA)
    OR	A
    JP	NZ, mc_has_key
    LD	A, KBD_ACK									; ACK=1
    OUT	(KBD_DD78PC), A
    XOR	A
    OUT	(KBD_DD78PC), A								; ACK=0
    XOR	A
    RET

mc_has_key:
    PUSH	BC
    LD	B, A			       						; store row in B
    IN	A, (KBD_DD78PC)
    AND	00001111b			 						; column code
    LD	C, A
    IN	A, (KBD_DD78PB)								; [JST3..1, ACK,TAPE5,TAPE4,GK,GC]
    RRA
    AND	00110000b			 						; SHIFT+CTRL
    OR	C
    LD	C, A			       						; C=SHIFT+CTRL+IE10
    LD	A,KBD_ACK			 						; ACK=1
    OUT	(KBD_DD78PC), A
    XOR	A											; ACK=0
    OUT	(KBD_DD78PC), A
    LD	A,B			       							; A = key
    LD	B, 0xff

	; decode key
mc_calc_column:
    INC	B
    RRA												; >> [CF] -> 7
    JP	NC,mc_calc_column
    LD	A, C
    RLA												; 0 <- [CF] <<
    RLA
    RLA

	; IE10 shifted + B
    AND	01111000b
    OR	B
    INC	A
    CP	KEY_ALF
    JP	NZ, mc_not_alf
    LD	A, 0x0
    LD	(TM_VARS.mc_stored_key), A
    JP	mc_fin

mc_not_alf:
    CP	0xc
    JP	NZ,mc_chk_fix
    LD	A, 0xff
    LD	(TM_VARS.mc_stored_key), A
    JP	mc_fin

mc_chk_fix:
    CP	KEY_FIX
    JP	NZ,mc_plain_key
	; invert fix state
    LD	A, (TM_VARS.mc_fix_state)
    CPL
    LD	(TM_VARS.mc_fix_state), A
    JP	mc_fin
mc_plain_key:
    LD	(TM_VARS.m_last_key), A
    LD	A, C
    AND	0x30
    LD	(TM_VARS.m_last_shifts), A
    POP	BC
    LD	A, 0xff
    RET
mc_fin:
    POP	BC
    XOR	A
    RET

; ------------------------------------------------------
;  Read key
;  Inp: A
; ------------------------------------------------------
tm_con_in:
    CALL	m_con_status
    OR	A
    JP	Z, tm_con_in
    LD	A, (TM_VARS.m_last_key)
    PUSH	HL
    PUSH	BC
    LD	B, A
    LD	A, (TM_VARS.m_last_shifts)
    LD	C, A
    LD	HL, mci_ctrl_tab
    AND	0x10										; Ctrl
    JP	NZ, mci_is_crtl
    LD	A, C
    LD	HL, mci_alt_tab
    AND	0x20			      						; Shift
    JP	NZ, mci_is_shift
    LD	A, (TM_VARS.mc_fix_state)
    OR	A
    JP	NZ, mci_is_shift
    LD	HL, mci_base_tab
	; Calc offset for key decode
mci_is_shift:
    LD	A, B		       							; last
    ADD	A, L
    LD	L, A
    LD	A, H
    ADC	A, 0x0
    LD	H, A
    LD	C, (HL)			    						; C - decoded
    LD	A, (TM_VARS.mc_stored_key)
    OR	A
    LD	A, C			       						; A = decoded key
    JP	Z, mci_key_zero
    OR	0x80
mci_key_zero:
    LD	C, A
    XOR	A
    LD	(TM_VARS.m_last_key), A
	; Return A=C=key
    LD	A, C
    POP	BC
    POP	HL
    RET
mci_is_crtl:
    LD	A,B
    ADD	A,L
    LD	L, A
    LD	A,H
    ADC	A, 0x0
    LD	H, A
    LD	A, (HL)
    JP	mci_key_zero

mci_base_tab	equ $-1
	db	 ',',  '-', 0x00, 0x00, 0x00,  '7',   '8',  '9'
	db	0x1B, 0x09, 0x00, 0x00, 0x00,  '0',   '.', "\r"
	db	 '@',  'J',  'F',  'Q', 0x00,  '1',   '2',  '3'
	db	0x9E,  '1',  'C',  'Y',  '^',  '4',   '5',  '6'
	db	0x81,  '2',  'U',  'W',  'S',  '+',  0x7F, 0x03
	db	0x86,  '3',  'K',  'A',  'M',  "\b", 0x99, 0x8B
	db	 '4',  'E',  'P',  'I',  ' ', 0x84,  "\r",  '/'
	db	0x92,  '5',  'N',  'R',  'T', 0x98,  0x85,  '_'
	db	0x83,  '6',  'G',  'O',  'X',  '.',   ':',  '-'
	db	'7',   '[',  'L',  'B', 0x93, 0x5C,   'H',  '0'
	db	'8',   ']',  'D',  ';',  ',',  'V',   'Z',  '9'

mci_alt_tab		equ $-1
	db	 ',',  '-', 0x00, 0x00, 0x00,  '7',  '8',  '9'
	db	0x1B, "\t", 0x00, 0x00, 0x00,  '0',  '.', "\r"
	db	 '`',  'j',  'f',  'q', 0x00,  '1',  '2',  '3'
	db	0x9E,  '!',  'c',  'y',  '~',  '4',  '5',  '6'
	db	0x81,  '"',  'u',  'w',  's',  '+', 0x7F, 0x03
	db	0x86,  '#',  'k',  'a',  'm', "\b", 0x99, 0x8B
	db	 '$',  'e',  'p',  'i',  ' ', 0x84, "\r",  '?'
	db	0x92,  '%',  'n',  'r',  't', 0x98, 0x85,  '_'
	db	0x83,  '&',  'g',  'o',  'x',  '>',  '*',  '='
	db	0x27,  '{',  'l',  'b', 0x93,  '|',  'h',  '0'
	db	 '(',  '}',  'd',  '+',  '<',  'v',  'z',  ')'

mci_ctrl_tab	equ $-1
	db	 ',',  '-', 0x00, 0x00, 0x00,  '7',  '8',  '9'
	db  0x1B, "\t", 0x00, 0x00, 0x00,  '0',  '.', "\r"
	db  0x00, "\n", 0x06, 0x11, 0x00,  '1',  '2',  '3'
	db  0x9E,  '1', 0x03, 0x19, 0x1E,  '4',  '5',  '6'
	db  0x81,  '2', 0x15, 0x17, 0x13,  '+', 0x7F,  0x03
	db  0x86,  '3', "\v", 0x01, "\r", "\b", 0x99,  0x8B
	db	 '4', 0x05, 0x10, "\t", ' ',  0x84, "\r",  '/'
	db  0x92,  '5', 0x0E, 0x12, 0x14, 0x98, 0x85,  0x1F
	db  0x83,  '6', "\a", 0x0F, 0x18,  '.',  ':',  '-'
	db	 '7', 0x1B, "\f", 0x02, 0x93, 0x1C, "\b",  '0'
	db	 '8', 0x1D, 0x04,  ';',  ',', 0x16, 0x1A,  '9'

; ------------------------------------------------------
;  Out char to console
;  Inp: C - char
; ------------------------------------------------------
m_con_out:
    PUSH	HL
    PUSH	DE
    PUSH	BC
    CALL	m_con_out_int
    POP	BC
    POP	DE
    POP	HL
    RET

; ------------------------------------------------------
; Out char C to console
; ------------------------------------------------------
m_con_out_int:
    LD	DE, TM_VARS.m_esc_mode
    LD	A, (DE)
    DEC	A
    OR	A
    JP	M, co_print_no_esc							; standart print no ESC mode
    JP	NZ, co_exit_esc

	; handle ESC param
    INC	DE
    LD	A, (DE)
    OR	A
    JP	P, co_get_esc_param
    LD	A, C
    AND	0xf											; convert char to command code
    LD	(DE), A
    INC	DE
    XOR	A
    LD	(DE), A
    RET

co_get_esc_param:
    LD	HL, TM_VARS.m_esc_cmd
    LD	B, (HL)
	; inc param count
    INC	HL
    LD	A, (HL)
    INC	A
    LD	(HL), A
	; store new param
    LD	E, A
    LD	D, 0x0
    ADD	HL, DE
    LD	(HL), C
	; get params count for esc command
    LD	HL, m_esc_params_tab
    LD	E, B										; d=0, b = cmd
    ADD	HL, DE			     						; DE - command offset
    CP	(HL)
	; return if enough
    RET	M

	; Entry point for user programs
	; to use graphics with parameters in ASCII form
    LD	A, (TM_VARS.m_esc_cmd)
    AND	0xf											; ??? already applied
    CP	15
    JP	Z, ge_lbl_1
    CP	11
    LD	C, 0x5
    JP	Z, ge_lbl_2
    CP	4
    JP	P, esc_handler1
ge_lbl_1:
    LD	C, 0x4
ge_lbl_2:
    LD	HL, TM_VARS.m_esc_param_1
    LD	D, H
    LD	E, L
ge_lbl_3:

    LD	A, (HL)
    CP	0x3a			      						; ':'
    JP	M, ge_is_digit_1
    SUB	0x7
ge_is_digit_1:
    AND	0xf
    ADD	A, A
    ADD	A, A
    ADD	A, A
    ADD	A, A
    LD	B, A										; B=A*16
    INC	HL
    LD	A, (HL)
    CP	':'
    JP	M, ge_is_digit_2
    SUB	0x7
ge_is_digit_2:
    AND	0xf
    OR	B
    INC	HL
    LD	(DE), A
    INC	DE
    DEC	C
    JP	NZ, ge_lbl_3

esc_handler1:
    LD	HL, TM_VARS.m_esc_cmd
    LD	A, (HL)
    AND	0xf
    LD	E, A
    DEC	HL
    OR	A
    LD	(HL), 0x2
    RET	Z
    LD	D, 0x0
    LD	(HL), D
    DEC	DE
	; Calc ESC command handler offset
    LD	HL, m_esc_handler_tab
    ADD	HL, DE
    ADD	HL, DE
    LD	E, (HL)
    INC	HL
	; HL = addr of handler func
    LD	D, (HL)
    EX	DE, HL
	; It is 1..4 func DRAW_* func?
    CP	0x4
    JP	P, esc_no_draw_fn
    LD	A, (TM_VARS.m_screen_mode)
    AND	00000111b
	; If not in graphics mode - exit
    JP	NZ, esc_exit

esc_no_draw_fn:
    LD	DE, esc_exit
    PUSH	DE

	; Jump to ESC func handler
    JP	(HL)

esc_exit:
    XOR	A
    LD	(TM_VARS.m_esc_mode), A
    RET

	; Count of parameters for ESC commands
m_esc_params_tab:
	db	4, 8, 8, 4, 1, 2, 1, 1
	db	1, 1, 1, 10, 1, 1, 1, 8

m_esc_handler_tab:
    dw	esc_draw_fill_rect							; <ESC>1
    dw	esc_draw_line								; <ESC>2
    dw	esc_draw_dot								; <ESC>3
    dw	esc_set_color								; <ESC>4
    dw	esc_set_cursor								; <ESC>5
    dw	esc_set_vmode								; <ESC>6
    dw	esc_set_charset								; <ESC>7
    dw	esc_set_palette								; <ESC>8
    dw	esc_reset_esc								; <ESC>9
    dw	esc_print_screen							; <ESC>:
    dw	esc_fn_b									; <ESC>;
    dw	esc_fn_none									; <ESC><
    dw	esc_fn_none									; <ESC>=
    dw	esc_fn_none									; <ESC>>
    dw	esc_set_beep								; <ESC>?
esc_fn_none:
    RET

esc_set_beep:
    LD	DE, TM_VARS.m_esc_param_1
    LD	A, (DE)
    LD	H, A
    INC	DE
    LD	A, (DE)
    LD	L, A
    LD	(TM_VARS.m_beep_period), HL
    INC	DE
    LD	A, (DE)
    LD	H, A
    INC	DE
    LD	A, (DE)
    LD	L, A
    LD	(TM_VARS.m_beep_duration), HL
    RET

esc_reset_esc:
    POP	DE
    XOR	A
    LD	(TM_VARS.m_esc_mode), A
    LD	A, (TM_VARS.m_screen_mode)
    RET

esc_print_screen:
    LD	A, (TM_VARS.m_screen_mode)
    AND	00000111b
    RET	NZ											; ret if not 0 mode
    LD	DE, 0x30ff
    CALL	m_print_hor_line
    DEC	E
    LD	D, 0xf0

fna_chk_keys:
    CALL	m_con_status
    OR	A
    JP	Z, fna_no_keys
    CALL	tm_con_in
    CP	ASCII_ESC
    RET	Z

fna_no_keys:
    CALL	m_print_hor_line
    DEC	E
    JP	NZ, fna_chk_keys
    LD	D, 0xe0
    CALL	m_print_hor_line
    RET

; ------------------------------------------------------
; Print line to printer
; D - width
; ------------------------------------------------------
m_print_hor_line:
    LD	HL, cmd_esc_set_X0

	; Set printer X coordinate = 0
    CALL	m_print_cmd
    LD	HL, 4
    LD	(TM_VARS.m_print_pos_x), HL				; Set start coord X = 4
    LD	B, 0x0

phl_print_next_col:
    LD	C, 0x0
	; 1
    CALL	m_get_7vpix
    AND	D
    CALL	NZ, m_print_vert_7pix
    LD	HL, (TM_VARS.m_print_pos_x)
    INC	HL

	; inc X
    LD	(TM_VARS.m_print_pos_x), HL
    LD	C, 0x1
	; 2
    CALL	m_get_7vpix
    AND	D
    CALL	NZ, m_print_vert_7pix
    LD	HL, (TM_VARS.m_print_pos_x)
    INC	HL
	; inc X
    LD	(TM_VARS.m_print_pos_x), HL
    INC	B
    LD	A, B
    CP	236
    JP	C, phl_print_next_col
    LD	HL, cmd_esc_inc_Y2
    CALL	m_print_cmd
    RET

; ------------------------------------------------------
; Send command to printer
; Inp: HL -> to command bytes array
; ------------------------------------------------------
m_print_cmd:
    PUSH	BC
ps_print_nxt:
    LD	A, (HL)
    CP	ESC_CMD_END
    JP	Z, ps_cmd_end
    LD	C, A
    CALL	m_print_write
    INC	HL
    JP	ps_print_nxt
ps_cmd_end:
    POP	BC
    RET

; ------------------------------------------------------
;  Print 7 vertical pixels to printer
;  Inp: A - value to print
; ------------------------------------------------------
m_print_vert_7pix:
    PUSH	AF
	; Set coordinate X to 0
    LD	HL, cmd_esc_set_X
    CALL	m_print_cmd
    LD	HL, (TM_VARS.m_print_pos_x)
    LD	C,H
    CALL	m_print_write
    LD	C,L
    CALL	m_print_write
	; Set column print mode
    LD	HL, cmd_esc_print_col
    CALL	m_print_cmd
    POP	AF
	; Print 7 vertical pixels
    LD	C, A
    CALL	m_print_write
    RET

; ------------------------------------------------------
; Control codes for printer УВВПЧ-30-004
; ------------------------------------------------------
; <ESC>Zn - Increment Y coordinate
cmd_esc_inc_Y2:
    db	ASCII_ESC
    db	'Z'
    db	2h
    db	ESC_CMD_END

; <ESC>Xnn - Set X coordinate
cmd_esc_set_X0:
    db	ASCII_ESC
    db	'X'
    db	0h											; 0..479
    db	0h
    db	ESC_CMD_END
; ------------------------------------------------------
; <ESC>X - Start on "Set X coordinate" command
; ------------------------------------------------------
cmd_esc_set_X:
    db	ASCII_ESC
    db	'X'
    db	ESC_CMD_END

; <ESC>O - Column print (vertical 7 bit)
cmd_esc_print_col:
    db	ASCII_ESC
    db	'O'
    db	ESC_CMD_END

; ------------------------------------------------------
;  Get 7 vertical pixels from screen
;  Inp: C - sheet
;  Out: A - byte
; ------------------------------------------------------
m_get_7vpix:
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, B
    ADD	A, 19										; skip first 20pix
    LD	L, A
    PUSH	DE
    PUSH	BC
    LD	A, E
g7v_calc_pix_no:
    AND	0x7
    LD	B, A
    LD	A, E
	; calc hi addr
    RRA												; /8
    RRA
    RRA
    AND	0x1f
    ADD	A, A										; *2
    ADD	A, 64										; bytes per row
    LD	H, A
	; select sheet 0|1
    LD	A, C
    AND	0x1
    ADD	A, H
    LD	H, A
	; HL = pix addr, turn on VRAM access
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	E, (HL)										; read pixel
    INC	H											; HL += 512
    INC	H
    LD	D, (HL)										; read pixel row+1

	; turn off VRAM access
    XOR	A
    OUT	(SYS_DD17PB), A
g7v_for_all_pix:
    DEC	B
    JP	M,g7v_all_shifted
	; shift pixels D >> [CF] >> E
    LD	A, D
    RRA
    LD	D, A
    LD	A, E
    RRA
    LD	E, A
    JP	g7v_for_all_pix
g7v_all_shifted:
    LD	A, E
    LD	D,00000000b
    RRA
    JP	NC,g7v_not_1_1
    LD	D,00110000b
g7v_not_1_1:
    RRA
    JP	NC,g7v_not_1_2
    LD	A, D
    OR	11000000b
    LD	D, A
g7v_not_1_2:
    LD	A, D
    POP	BC
    POP	DE
    RET

esc_set_palette:
    LD	A, (TM_VARS.m_esc_param_1)
    AND	00111111b									; bgcol[2,1,0],pal[2,1,0]
    LD	(TM_VARS.m_cur_palette), A
    LD	B, A
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    LD	A, 0x0
    JP	NZ,esp_no_colr
    LD	A, 0x40

esp_no_colr:
    OR	B
    OUT	(VID_DD67PB), A
    RET

esc_set_charset:
    LD	A, (TM_VARS.m_esc_param_1)
    AND	0x3											; charset 0..3
    LD	(TM_VARS.m_codepage), A
    RET

; ------------------------------------------------------
; Get address for draw symbol glyph
; ------------------------------------------------------
m_get_glyph:
    LD	L, A
    LD	E, A
    XOR	A
    LD	D, A
    LD	H, A
	; HL = DE = A
    ADD	HL, HL
    ADD	HL, DE
    ADD	HL, HL
    ADD	HL, DE
	; HL = A * 7
    LD	A, E											; A = A at proc entry
    CP	'@'
	; First 64 symbols is same for all codepages
    JP	M, m_cp_common
    LD	A, (TM_VARS.m_codepage)
    OR	A
	; cp=0 - Latin letters
    JP	Z, m_cp_common
    DEC	A
	; cp=1 - Russian letters
    JP	Z, m_cp_russ
	; cp=2 - 0x40..0x5F - displayed as Lat
	; 0x60 - 0x7F - displayed as Rus
    LD	A, E
    CP	0x60
    JP	M, m_cp_common
m_cp_russ:
    LD	DE, 448											; +448=64*7 Offset for cp1
    ADD	HL, DE

m_cp_common:
    LD	DE, m_font_cp0-224								; m_font_cp0-224
    ADD	HL, DE											; add symbol glyph offset
    RET

; ------------------------------------------------------
; Console output
; ------------------------------------------------------
co_print_no_esc:
    LD	A, C
    AND	0x7f
    CP	' '
    JP	M, m_print_control_char
    CALL	m_get_glyph
	; Calc screen address to DE
    EX	DE, HL
    LD	HL, (TM_VARS.m_cursor_row)
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, L
    LD	L, A
    LD	A, H
    ADD	A, 64
    LD	H, A
    LD	C, 7
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    JP	NZ, co_m_no_color
	; Access to video RAM
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    EX	DE, HL
	; draw to both planes
    XOR	A
    LD	(DE), A
    INC	D
    LD	(DE), A
    DEC	D
    INC	E
co_m_colorify:
    LD	A, (TM_VARS.m_curr_color)
    AND	(HL)
    ADD	A, A
    LD	(DE), A
    INC	D
    LD	A, (TM_VARS.m_curr_color+1)
    AND	(HL)
    ADD	A, A
    LD	(DE), A

	; next font byte
    DEC	D
    INC	HL
    INC	E
    DEC	C
    JP	NZ, co_m_colorify
    XOR	A
	; Remove access to VRAM
    OUT	(SYS_DD17PB), A
	; Address to draw cursor proc on stack
    LD	HL, m_draw_cursor
    PUSH	HL
    LD	HL, TM_VARS.m_cursor_row
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x8
    JP	NZ, m_cursor_rt_2

m_psc_fwd_cmn:
    INC	HL
    LD	A, (HL)
    ADD	A, 0x2
    AND	0x3f
    LD	(HL), A
    DEC	HL
    RET	NZ
m_psc_lf_cmn:
    LD	A, (HL)
    ADD	A, 0xe
    CP	0xfa
    JP	NC, LAB_ram_e57a
    LD	(HL), A
    RET
LAB_ram_e57a:
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, 0xe
    OUT	(SYS_DD17PA), A
    LD	(TM_VARS.m_row_shift), A
    LD	HL, 0x40f0
    ADD	A, L
    LD	L, A
    DEC	L
    DEC	L
    LD	C, H
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    XOR	A
    LD	DE, 0x1240

LAB_ram_e594:
    LD	H, C
    LD	B, E
LAB_ram_e596:
    LD	(HL), A
    INC	H
    DEC	B
    JP	NZ, LAB_ram_e596
    INC	L
    DEC	D
    JP	NZ, LAB_ram_e594
    XOR	A
    OUT	(SYS_DD17PB), A
    RET

m_psc_bksp_cmn:
    INC	HL
    LD	A, (HL)
    SUB	0x2
    AND	0x3f
    LD	(HL), A
    CP	0x3e
    DEC	HL
    RET	NZ

m_psc_up_cmn:
    LD	A, (HL)
    SUB	14
    JP	NC, up_no_minus
    LD	A, 238
up_no_minus:
    LD	(HL), A
    RET

m_psc_tab_cmn:
    INC	HL
    LD	A, (HL)
    ADD	A,16
    AND	0x30
    LD	(HL), A
    DEC	HL
    RET	NZ
    JP	m_psc_lf_cmn

m_psc_tab:
    INC	HL
    LD	A, (HL)
    ADD	A, 16
    AND	0x30
    LD	(HL), A
    DEC	HL
    RET	NZ
    JP	m_psc_lf

	; Move cursor 2 sym right, move to next line if wrap
m_cursor_rt_2:
    INC	HL
    LD	A, (HL)
    ADD	A,2
    AND	0x3f										; screen column 0..63
    LD	(HL), A
    DEC	HL
    RET	NZ											; Return if no wrap

m_psc_lf:
    LD	A, (HL)
    ADD	A, 12
    CP	16
    JP	NC, mp_next_nowr
    LD	(HL), A
    RET

mp_next_nowr:
    LD	A, (TM_VARS.m_row_shift)
    LD	L, A
    ADD	A, 12
    LD	E, A
    LD	C, 8
	; Acces VRAM
    LD	A,1
    OUT	(SYS_DD17PB), A
LAB_ram_e5f2:
    LD	B, 0x40
    LD	H, 0x40
    LD	D, H
LAB_ram_e5f7:
    LD	A, (DE)
    LD	(HL), A
    INC	H
    INC	D
    DEC	B
    JP	NZ, LAB_ram_e5f7
    INC	L
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e5f2
    LD	C, 0xc
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, 0x8
    LD	E, A
LAB_ram_e60d:
    LD	B, 0x40
    LD	D, 0x40
    XOR	A
LAB_ram_e612:
    LD	(DE), A
    INC	D
    DEC	B
    JP	NZ, LAB_ram_e612
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e60d
    XOR	A
    OUT	(SYS_DD17PB), A
    RET

m_psc_bksp:
    INC	HL
    LD	A, (HL)
    OR	A
    DEC	HL
    RET	Z
    INC	HL
    SUB	0x2
    AND	0x3f
    LD	(HL), A
    DEC	HL
    RET

co_m_no_color:
    CP	7
    JP	Z, LAB_ram_e6b5
    CP	3
    JP	Z, LAB_ram_e6b5
    AND	0x2
    JP	NZ, LAB_ram_e7b9
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    EX	DE, HL
    XOR	A
    LD	(DE), A
    INC	E

LAB_ram_e645:
    LD	A, (HL)
    ADD	A, A
    LD	(DE), A
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e645
    XOR	A
    OUT	(SYS_DD17PB), A
    LD	HL, m_draw_cursor
    PUSH	HL
    LD	HL, TM_VARS.m_cursor_row
LAB_ram_e658:
    INC	HL
    LD	A, (HL)
    ADD	A, 0x1
    AND	0x3f
    LD	(HL), A
    DEC	HL
    RET	NZ
LAB_ram_e661:
    LD	A, (HL)
    ADD	A, 0xb
    CP	0xfa
    JP	NC, LAB_ram_e66b
    LD	(HL), A
    RET

LAB_ram_e66b:
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, 0xb
    OUT	(SYS_DD17PA), A
    LD	(TM_VARS.m_row_shift), A
    LD	HL, 0x40f0
    ADD	A,L
    LD	L, A
    LD	C,H
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    XOR	A
    LD	DE, 0x1040
LAB_ram_e683:
    LD	H, C
    LD	B, E
LAB_ram_e685:
    LD	(HL), A
    INC	H
    DEC	B
    JP	NZ, LAB_ram_e685
    INC	L
    DEC	D
    JP	NZ, LAB_ram_e683
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
LAB_ram_e694:
    INC	HL
    LD	A, (HL)
    SUB	0x1
    AND	0x3f
    LD	(HL), A
    CP	0x3f
    DEC	HL
    RET	NZ
LAB_ram_e69f:
    LD	A, (HL)
    SUB	0xb
    JP	NC, LAB_ram_e6a7
    LD	A, 0xf2
LAB_ram_e6a7:
    LD	(HL), A
    RET
LAB_ram_e6a9:
    INC	HL
    LD	A, (HL)
    ADD	A, 0x8
    AND	0x38
    LD	(HL), A
    DEC	HL
    RET	NZ
    JP	LAB_ram_e661
LAB_ram_e6b5:
    CALL	m_calc_addr_40
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    EX	DE, HL
    LD	A,B
    OR	B
    JP	Z, LAB_ram_e6cd
    DEC	B
    JP	Z, LAB_ram_e6df
    DEC	B
    JP	Z, LAB_ram_e706
    JP	LAB_ram_e731
LAB_ram_e6cd:
    XOR	A
    LD	(DE), A
    INC	E
LAB_ram_e6d0:
    LD	B, (HL)
    LD	A, (DE)
    AND	0xc0
    OR	B
    LD	(DE), A
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e6d0
    JP	LAB_ram_e745
LAB_ram_e6df:
    XOR	A
    LD	(DE), A
    DEC	D
    LD	(DE), A
    INC	D
    INC	E
LAB_ram_e6e5:
    LD	A, (HL)
    RRCA
    RRCA
    AND	0x7
    LD	B, A
    LD	A, (DE)
    AND	0xf0
    OR	B
    LD	(DE), A
    LD	A, (HL)
    RRCA
    RRCA
    AND	0xc0
    LD	B, A
    DEC	D
    LD	A, (DE)
    AND	0x1f
    OR	B
    LD	(DE), A
    INC	D
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e6e5
    JP	LAB_ram_e745
LAB_ram_e706:
    XOR	A
    LD	(DE), A
    DEC	D
    LD	(DE), A
    INC	D
    INC	E
LAB_ram_e70c:
    LD	A, (HL)
    RRCA
    RRCA
    RRCA
    RRCA
    AND	0x1
    LD	B, A
    LD	A, (DE)
    AND	0xfc
    OR	B
    LD	(DE), A
    LD	A, (HL)
    RRCA
    RRCA
    RRCA
    RRCA
    AND	0xf0
    LD	B, A
    DEC	D
    LD	A, (DE)
    AND	0x7
    OR	B
    LD	(DE), A
    INC	D
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e70c
    JP	LAB_ram_e745
LAB_ram_e731:
    DEC	D
    XOR	A
    LD	(DE), A
    INC	E
LAB_ram_e735:
    LD	A, (HL)
    RLCA
    RLCA
    LD	B, A
    LD	A, (DE)
    AND	0x1
    OR	B
    LD	(DE), A
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e735
    INC	D
LAB_ram_e745:
    XOR	A
    OUT	(SYS_DD17PB), A
    LD	HL, m_draw_cursor
    PUSH	HL
    LD	HL, TM_VARS.m_cursor_row
LAB_ram_e74f:
    INC	HL
    LD	A, (HL)
    ADD	A, 0x1
    AND	0x7f
    LD	(HL), A
    CP	0x50
    DEC	HL
    RET	M
LAB_ram_e75a:
    INC	HL
    XOR	A
    LD	(HL), A
    DEC	HL
LAB_ram_e75e:
    LD	A, (HL)
    ADD	A, 0xb
    CP	0xfa
    JP	NC, LAB_ram_e66b
    LD	(HL), A
    RET
LAB_ram_e768:
    INC	HL
    LD	A, (HL)
    SUB	0x1
    AND	0x7f
    CP	0x7f
    JP	Z, LAB_ram_e776
    LD	(HL), A
    DEC	HL
    RET
LAB_ram_e776:
    LD	A, 0x4f
    LD	(HL), A
    DEC	HL
LAB_ram_e77a:
    LD	A, (HL)
    SUB	0xb
    JP	NC, LAB_ram_e782
    LD	A, 0xf2
LAB_ram_e782:
    LD	(HL), A
    RET
LAB_ram_e784:
    INC	HL
    LD	A, (HL)
    ADD	A, 0x8
    AND	0x7f
    LD	(HL), A
    CP	0x50
    DEC	HL
    RET	M
    JP	LAB_ram_e75a

; ------------------------------------------------------
;  Calculate text position in 40 column text mode
;  Out: HL - addr
;       B - bit no
;       C = 7
; ------------------------------------------------------
m_calc_addr_40:
    LD	HL, (TM_VARS.m_cursor_row)
    LD	A, (TM_VARS.m_row_shift)
    ADD	A,L
    LD	L, A										; HL = row+shift
    LD	A,H
    CP	4
    LD	B, A
    JP	M, ca_bef_scrn_top
    AND	0x3
    LD	B, A
    LD	A,H
    OR	A
    RRA
    OR	A
    RRA
    LD	C, A
    LD	H, 0x3
    XOR	A

ca_lbl1:
    ADD	A,H
    DEC	C
    JP	NZ, ca_lbl1
    ADD	A,B
ca_bef_scrn_top:
    ADD	A, 0x40										; next row
    LD	H, A
    LD	C, 0x7
    RET

LAB_ram_e7b9:
    LD	A, (TM_VARS.m_cursor_col)
    CP	0x40
    JP	M, LAB_ram_e7c8
    LD	HL, TM_VARS.m_cursor_row
    CALL	m_draw_cursor
    RET
LAB_ram_e7c8:
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    EX	DE, HL
    XOR	A
    LD	(DE), A
    INC	E
LAB_ram_e7d0:
    LD	A, (HL)
    ADD	A, A
    LD	(DE), A
    INC	HL
    INC	E
    DEC	C
    JP	NZ, LAB_ram_e7d0
    XOR	A
    OUT	(SYS_DD17PB), A
    LD	HL, m_draw_cursor
    PUSH	HL
    LD	HL, TM_VARS.m_cursor_row
    INC	HL
    LD	A, (HL)
    ADD	A, 0x1
    CP	0x40
    JP	M, LAB_ram_e7ee
    LD	A, 0x40
LAB_ram_e7ee:
    LD	(HL), A
    DEC	HL
    RET

m_psc_clrscr_cmn:
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x8
    JP	NZ,m_clr_color
    LD	A,01111111b
    OUT	(VID_DD67PB), A								; C/M=1 FL=111 CL=111 All black
	; Access VRAM
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	DE, EXT_RAM.video_ram
    EX	DE, HL
    LD	A,H
    ADD	A,64										; row + 1
    LD	B, 0x0

clr_fill_scrn1:
    LD	(HL),B
    INC	HL
    CP	H
    JP	NZ, clr_fill_scrn1
    EX	DE, HL
    LD	A, (TM_VARS.m_cur_palette)
    LD	B, A
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    LD	A, 0x0
    JP	NZ, clr_rest_no_color
    LD	A, 01000000b

clr_rest_no_color:
    OR	B
	; Restore mode and palette
    OUT	(VID_DD67PB), A

m_psc_home_cmn:
    XOR	A
    NOP
    NOP
    LD	(HL), A
    INC	HL
    XOR	A
    LD	(HL), A
    DEC	HL
    XOR	A
	; Disable VRAM access
    OUT	(SYS_DD17PB), A
    RET

	; Clear scr in color mode
m_clr_color:
    LD	A, (TM_VARS.m_row_shift)
    LD	L, A
    LD	C,20
	; Access VRAM
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
m_clr_fill_c1:
    LD	H, 0x40										; HL = 0x4000 + shift_row
    LD	B,64										; 64 bytes at row
    XOR	A
m_clr_fill_c2:
    LD	(HL), A
    INC	H
    DEC	B
    JP	NZ, m_clr_fill_c2
    INC	L
    DEC	C
    JP	NZ, m_clr_fill_c1
    XOR	A
	; Disabe VRAM access
    OUT	(SYS_DD17PB), A
    JP	m_psc_home_cmn
m_draw_cursor:
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x4
    RET	NZ
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    JP	NZ, LAB_ram_e884
    EX	DE, HL
    LD	HL, (TM_VARS.m_cursor_row)
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, L
    LD	L, A
    LD	A, H
    ADD	A, 0x40
    LD	H, A
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	BC, 0x7f08
LAB_ram_e872:
    LD	A, (HL)
    XOR	B
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	B
    LD	(HL), A
    DEC	H
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e872
    EX	DE, HL
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
LAB_ram_e884:
    CP	0x3
    JP	Z, LAB_ram_e8af
    EX	DE, HL
    LD	HL, (TM_VARS.m_cursor_row)
    LD	A, (TM_VARS.m_row_shift)
    ADD	A, L
    LD	L, A
    LD	A, H
    CP	0x40
    EX	DE, HL
    RET	P
    EX	DE, HL
    ADD	A, 0x40
    LD	H, A
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	BC, 0x7f08
LAB_ram_e8a2:
    LD	A, (HL)
    XOR	B
    LD	(HL), A
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e8a2
    EX	DE, HL
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
LAB_ram_e8af:
    EX	DE, HL
    LD	HL, (TM_VARS.m_cursor_row)
    LD	A, H
    CP	0x50
    EX	DE, HL
    RET	P
    EX	DE, HL
    CALL	m_calc_addr_40
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	A, B
    OR	B
    JP	Z, LAB_ram_e8d0
    DEC	B
    JP	Z, LAB_ram_e8e6
    DEC	B
    JP	Z, LAB_ram_e908
    JP	LAB_ram_e92a
LAB_ram_e8d0:
    LD	BC, 0x1f08
LAB_ram_e8d3:
    LD	A, (HL)
    AND	0xc0
    LD	B, A
    LD	A, (HL)
    XOR	0x1f
    AND	0x1f
    OR	B
    LD	(HL), A
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e8d3
    JP	LAB_ram_e93e
LAB_ram_e8e6:
    LD	C, 0x8
LAB_ram_e8e8:
    DEC	H
    LD	A, (HL)
    AND	0x1f
    LD	B, A
    LD	A, (HL)
    XOR	0xc0
    AND	0xc0
    OR	B
    LD	(HL), A
    INC	H
    LD	A, (HL)
    AND	0xf0
    LD	B, A
    LD	A, (HL)
    XOR	0x7
    AND	0x7
    OR	B
    LD	(HL), A
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e8e8
    JP	LAB_ram_e93e
LAB_ram_e908:
    LD	C, 0x8
LAB_ram_e90a:
    DEC	H
    LD	A, (HL)
    AND	0x7
    LD	B, A
    LD	A, (HL)
    XOR	0xf0
    AND	0xf0
    OR	B
    LD	(HL), A
    INC	H
    LD	A, (HL)
    AND	0xfc
    LD	B, A
    LD	A, (HL)
    XOR	0x1
    AND	0x1
    OR	B
    LD	(HL), A
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e90a
    JP	LAB_ram_e93e
LAB_ram_e92a:
    LD	C, 0x8
    DEC	H
LAB_ram_e92d:
    LD	A, (HL)
    AND	0x1
    LD	B, A
    LD	A, (HL)
    XOR	0x7c
    AND	0x7c
    OR	B
    LD	(HL), A
    INC	L
    DEC	C
    JP	NZ, LAB_ram_e92d
    INC	H
LAB_ram_e93e:
    EX	DE, HL
    XOR	A
    OUT	(SYS_DD17PB), A								; reset screen shifts
    RET

m_print_control_char:
    CP	ASCII_ESC
    JP	NZ,m_psc_std_char
	; turn on ESC mode for next chars
    LD	HL, TM_VARS.m_esc_mode
    LD	(HL), 0x1
    INC	HL
    LD	(HL), 0xff
    RET

m_psc_std_char:
    CP	BELL_CHAR
    JP	Z, m_beep
    LD	HL, m_draw_cursor
    PUSH	HL
    LD	HL, TM_VARS.m_cursor_row
    PUSH	AF
    CALL	m_draw_cursor
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x8											; mode 40x20?
    JP	Z, m_psc_no_40x30							; jump if no
    POP	AF
    CP	ASCII_TAB									; TAB
    JP	Z,m_psc_tab
    CP	ASCII_BS									; BKSP
    JP	Z,m_psc_bksp
    CP	ASCII_CAN									; Cancel
    JP	Z,m_cursor_rt_2
    CP	ASCII_US									; ASCII Unit separator
    JP	Z,m_clr_color
    CP	ASCII_LF									; LF
    JP	Z,m_psc_lf
    CP	ASCII_CR									; CR
    RET	NZ											; ret on unknown
    INC	HL
    LD	(HL), 0x0
    DEC	HL
    RET

	; common for 40x25, 64x25, 80x25 modes
m_psc_no_40x30:
    POP	AF
    CP	ASCII_US									; Unit separator
    JP	Z, m_psc_clrscr_cmn
    CP	ASCII_FF									; Form feed
    JP	Z, m_psc_home_cmn
    PUSH	AF
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    JP	NZ, LAB_ram_e9c6
    POP	AF
    CP	ASCII_TAB
    JP	Z, m_psc_tab_cmn
    CP	ASCII_BS
    JP	Z, m_psc_bksp_cmn
    CP	ASCII_CAN
    JP	Z, m_psc_fwd_cmn
    CP	ASCII_EM									; ASCII End of medium
    JP	Z, m_psc_up_cmn
    CP	ASCII_SUB
    JP	Z, m_psc_lf_cmn								; cursor down
    CP	ASCII_LF
    JP	Z, m_psc_lf_cmn
    CP	ASCII_CR
    RET	NZ
    INC	HL
    LD	(HL), 0x0
    DEC	HL
    RET
LAB_ram_e9c6:
    LD	A, (TM_VARS.m_screen_mode)
    CP	0x3
    JP	Z, m_psc_no_40x25
    CP	0x7
    JP	Z, m_psc_no_40x25
    AND	0x2
    JP	NZ, LAB_ram_e9ff
; For 40x25?
    POP	AF
    CP	0x9
    JP	Z, LAB_ram_e6a9
    CP	0x8
    JP	Z, LAB_ram_e694
    CP	0x18
    JP	Z, LAB_ram_e658
    CP	0x19
    JP	Z, LAB_ram_e69f
    CP	0x1a
    JP	Z, LAB_ram_e661
    CP	0xa
    JP	Z, LAB_ram_e661
    CP	0xd
    RET	NZ
    INC	HL
    LD	(HL), 0x0
    DEC	HL
    RET

LAB_ram_e9ff:
    POP	AF
    CP	0xa
    JP	Z, LAB_ram_e661
    CP	0xd
    RET	NZ
    INC	HL
    LD	(HL), 0x0
    DEC	HL
    RET

m_psc_no_40x25:
    POP	AF
    CP	0x9
    JP	Z, LAB_ram_e784
    CP	0x8
    JP	Z, LAB_ram_e768
    CP	0x18
    JP	Z, LAB_ram_e74f
    CP	0x19
    JP	Z, LAB_ram_e77a
    CP	0x1a
    JP	Z, LAB_ram_e75e
    CP	0xa
    JP	Z, LAB_ram_e75e
    CP	0xd
    RET	NZ
    INC	HL
    LD	(HL), 0x0
    DEC	HL
    RET

m_beep:
    LD	HL, (TM_VARS.m_beep_duration)
    EX	DE, HL
    LD	HL, (TM_VARS.m_beep_period)
    LD	A,00110110b									; TMR#0 LSB+MSB Square Wave Generator
    OUT	(TMR_DD70CTR), A
    LD	A,L											; LSB
    OUT	(TMR_DD70C1), A
    LD	A,H											; MSB
    OUT	(TMR_DD70C1), A
    LD	A, (TM_VARS.m_strobe_state)
    LD	B, A
m_bell_cont:
    LD	A, D										; DE=duration
    OR	E
    RET	Z											; ret if enough
    DEC	DE
    LD	A,B
    XOR	BELL_PIN
    LD	B, A
    OUT	(DD67PC), A									; Invert bell pin
m_bell_wait_tmr1:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ									; 0x10
    JP	NZ,m_bell_wait_tmr1
    LD	A,B
    XOR	BELL_PIN									; Flip pin again
    LD	B, A
    OUT	(DD67PC), A
m_bell_wait_tmr2:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ
    JP	Z,m_bell_wait_tmr2
    JP	m_bell_cont

; ------------------------------------------------------
; <ESC>5<row><col> Set cursor position
; ------------------------------------------------------
esc_set_cursor:
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x8
    RET	NZ											; ret if graphics mode
    CALL	m_draw_cursor		       				; hide cursor
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7			       							; mode 0-7
    JP	NZ,sc_set_64_or_80
	; Set cursor for 32x18 mode
    LD	DE, TM_VARS.m_esc_param_1
    LD	HL, TM_VARS.m_cursor_col
    INC	DE
    LD	A, (DE)	; column
    AND	0x1f										; limit column to 0..31
    ADD	A, A			       						; *2
    LD	(HL), A
    DEC	DE
    DEC	HL
    LD	A, (DE)	; row
    AND	0x1f			     	 					; 0..31
    CP	17
    JP	C,sc_no_row_limit1
    LD	A,17

sc_no_row_limit1:
    LD	B, A
    ADD	A, A
    ADD	A,B
    ADD	A, A
    ADD	A,B
    ADD	A, A										; a = a * 14 (font height)
    LD	(HL), A
    CALL	m_draw_cursor
    RET

sc_set_64_or_80:
    LD	A, (TM_VARS.m_screen_mode)
    CP	0x3
    JP	Z, sc_set_for_80x32
    CP	0x7
    JP	Z, sc_set_for_80x32
    AND	0x2
    JP	NZ, sc_set_for_65x23
	; Set for 64 col modes
    LD	DE, TM_VARS.m_esc_param_1					; row
    LD	HL, TM_VARS.m_cursor_col
    INC	DE
    LD	A, (DE)										; column
    SUB	0x20
    AND	0x3f										; 0..63
    LD	(HL), A
    DEC	DE
    DEC	HL
    LD	A, (DE)										; row
	; limit row to 0..22
    AND	0x1f
    CP	22
    JP	C,sc_no_row_limit2
    LD	A,22
sc_no_row_limit2:
    LD	B, A
    ADD	A, A
    ADD	A, A
    ADD	A,B
    ADD	A, A
    ADD	A,B											; A = A * 11 (font height)
    LD	(HL), A
    CALL	m_draw_cursor							; show cursor
    RET

sc_set_for_65x23:
    LD	DE, TM_VARS.m_esc_param_1
    LD	HL, TM_VARS.m_cursor_col
    INC	DE
    LD	A, (DE)										; column
    SUB	0x20
    CP	64
    JP	M,sc_no_col_limit3
    LD	A,64

sc_no_col_limit3:
    LD	(HL), A
    DEC	DE
    DEC	HL
    LD	A, (DE)										; row
    AND	0x1f
    CP	22
    JP	C,sc_no_row_limit3
    LD	A,22
sc_no_row_limit3:
    LD	B, A
    ADD	A, A
    ADD	A, A
    ADD	A,B
    ADD	A, A
    ADD	A,B											; A = A * 11
    LD	(HL), A
    CALL	m_draw_cursor							; show cursor
    RET

sc_set_for_80x32:
    LD	DE, TM_VARS.m_esc_param_1
    LD	HL, TM_VARS.m_cursor_col
    INC	DE
    LD	A, (DE)
    SUB	0x20
    AND	0x7f
    CP	79
    JP	M, sc_no_row_limit4
    LD	A,79

sc_no_row_limit4:
    LD	(HL), A
    DEC	DE
    DEC	HL
    LD	A, (DE)
    AND	0x1f
    CP	22
    JP	C,sc_no_col_limit4
    LD	A,22

sc_no_col_limit4:
    LD	B, A
    ADD	A, A
    ADD	A, A
    ADD	A,B
    ADD	A, A
    ADD	A,B											; A = A * 11
    LD	(HL), A
    CALL	m_draw_cursor							; show cursor
    RET

; ------------------------------------------------------
;  <ESC>6n
;  where n is
;  0   - 32x18 with cursor;
;  1,2 - 64x23 with cursor;
;  3   - 80x23 with cursor;
;  4   - 32x18 no cursor;
;  5,6 - 64x23 no cursor;
;  7   - 80x23 no cursor;
;  8   - graphics mode.
; ------------------------------------------------------
esc_set_vmode:
    LD	HL, TM_VARS.m_screen_mode
    LD	A, (TM_VARS.m_cur_palette)
    LD	B, A										; b = palette
    LD	A, (TM_VARS.m_esc_param_1)
    LD	C, A										; c = mode
    AND	0x8											; graph mode?
    LD	A, C
    JP	Z,svm_set_text
    LD	A, 0x8
svm_set_text:
    AND	0xf
    LD	(HL), A										; save new mode
    AND	0x7											; with cursor?
    LD	A,00000000b
    JP	NZ, swm_no_color
    LD	A,01000000b
swm_no_color:
    OR	B
    OUT	(VID_DD67PB), A								; Set C/M and palette
    LD	HL, TM_VARS.m_cursor_row
    CALL	m_psc_clrscr_cmn
    CALL	m_draw_cursor
    RET

; ------------------------------------------------------
; <ESC>4n n=1..4 Set drawing color
; ------------------------------------------------------
esc_set_color:
    LD	A, (TM_VARS.m_esc_param_1)
    AND	0x3
    RRA
    LD	B, A
    LD	A, 0x0
    SBC	A, A
    LD	(TM_VARS.m_curr_color), A
    LD	A, B
    DEC	A
    CPL
    LD	(TM_VARS.m_curr_color+1), A
    RET

co_exit_esc:
    LD	A, (TM_VARS.m_screen_mode)
    AND	0x7
    JP	NZ, esc_exit
    LD	A, C
    AND	0x7f
    LD	C, A
    CP	0x20
    JP	M, esc_exit
    LD	HL, TM_VARS.m_esc_param_1
    LD	A, (HL)
    LD	E, A
    ADD	A, 0x8
    JP	C, esc_exit
    LD	(HL), A
    INC	HL
    LD	A, 0xf7
    CP	(HL)
    JP	C, esc_exit
    LD	D, (HL)
    CALL	SUB_ram_ebe2
    LD	A, L
    SUB	0x7
    LD	L, A
    PUSH	HL
    LD	A, C
    CALL	m_get_glyph
    POP	DE
    LD	C, 0x7

LAB_ram_eb9b:
    PUSH	HL
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	L, (HL)
    LD	H, 0x0
    LD	A, B
    OR	A
    JP	Z, LAB_ram_ebad
LAB_ram_eba8:
    ADD	HL, HL
    DEC	A
    JP	NZ, LAB_ram_eba8
LAB_ram_ebad:
    EX	DE, HL
    PUSH	BC
    LD	A, (TM_VARS.m_curr_color)
    CPL
    LD	B, A
    LD	A, (HL)
    XOR	B
    OR	E
    XOR	B
    LD	(HL), A
    INC	H
    INC	H
    LD	A, (HL)
    XOR	B
    OR	D
    XOR	B
    LD	(HL), A
    DEC	H
    LD	A, (TM_VARS.m_curr_color+1)
    CPL
    LD	B, A
    LD	A, (HL)
    XOR	B
    OR	E
    XOR	B
    LD	(HL), A
    INC	H
    INC	H
    LD	A, (HL)
    XOR	B
    OR	D
    XOR	B
    LD	(HL), A
    DEC	H
    DEC	H
    DEC	H
    INC	L
    EX	DE, HL
    POP	BC
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	HL
    INC	HL
    DEC	C
    JP	NZ, LAB_ram_eb9b
    RET
SUB_ram_ebe2:
    LD	A, (TM_VARS.m_row_shift)
    SUB	D
    DEC	A
    LD	L, A
    LD	A, E
    AND	0x7
    LD	B, A
    LD	A, E
    RRA
    RRA
    AND	0x3e
    ADD	A, 0x40
    LD	H, A
    RET

esc_draw_fill_rect:
    LD	HL, TM_VARS.m_esc_param_4
    LD	DE, TM_VARS.m_esc_param_2
    LD	A, (DE)
    LD	B, (HL)
    CP	B
    JP	NC, LAB_ram_ec04
    LD	(HL), A
    LD	A,B
    LD	(DE), A
LAB_ram_ec04:
    DEC	DE
    DEC	HL
    LD	A, (DE)
    LD	B, (HL)
    CP	B
    JP	C, LAB_ram_ec0f
    LD	(HL), A
    LD	A,B
    LD	(DE), A
LAB_ram_ec0f:
    EX	DE, HL
    LD	E, (HL)
    INC	HL
    LD	D, (HL)
    CALL	SUB_ram_ebe2
    PUSH	HL
    XOR	A
LAB_ram_ec18:
    SCF
    RLA
    DEC	B
    JP	P, LAB_ram_ec18
    RRA
    LD	D, A
    LD	HL, TM_VARS.m_esc_param_3
    LD	A, (HL)
    AND	0x7
    LD	B, A
    XOR	A
LAB_ram_ec28:
    SCF
    RLA
    DEC	B
    JP	P, LAB_ram_ec28
    CPL
    LD	E, A
    LD	A, (HL)
    DEC	HL
    DEC	HL
    SUB	(HL)
    RRCA
    RRCA
    RRCA
    AND	0x1f
    LD	C, A
    INC	HL
    LD	A, (HL)
    INC	HL
    INC	HL
    SUB	(HL)
    JP	NZ, LAB_ram_ec43
    INC	A
LAB_ram_ec43:
    LD	B, A
    POP	HL
    LD	A, E
    LD	(TM_VARS.m_esc_hex_cmd), A
LAB_ram_ec49:
    PUSH	DE
    PUSH	HL
    PUSH	BC
	; Access VRAM
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	A, C
    OR	A
    JP	NZ, LAB_ram_ec58
    LD	A, D
    OR	E
dr_no_cmd:
    LD	D, A
LAB_ram_ec58:
    LD	B, D
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    INC	H
    LD	A, C
    OR	A
    JP	Z, LAB_ram_ec81
    DEC	C
LAB_ram_ec70:
    LD	A, (TM_VARS.m_esc_hex_cmd)
    JP	Z, dr_no_cmd
LAB_ram_ec76:
    LD	(HL), E
    INC	H
    LD	(HL), D
    INC	H
    DEC	C
    JP	NZ, LAB_ram_ec76
    JP	LAB_ram_ec70
LAB_ram_ec81:
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	BC
    POP	HL
    POP	DE
    INC	L
    DEC	B
    JP	NZ, LAB_ram_ec49
    RET

esc_draw_line:
    LD	HL, TM_VARS.m_esc_param_1
    LD	E, (HL)
    INC	HL
    LD	D, (HL)
    INC	HL
    LD	A, (HL)
    INC	HL
    LD	H, (HL)
    LD	L, A
    CP	E
    JP	C, LAB_ram_ec9d
    EX	DE, HL
LAB_ram_ec9d:
    LD	(TM_VARS.m_esc_param_1), HL
    LD	A, E
    SUB	L
    LD	L, A
    LD	A, D
    SUB	H
    LD	H, A
    PUSH	AF
    JP	NC, LAB_ram_ecad
    CPL
    INC	A
    LD	H, A
LAB_ram_ecad:
    EX	DE, HL
    LD	HL, (TM_VARS.m_esc_param_1)
    EX	DE, HL
    JP	Z, LAB_ram_ed96
    LD	A, L
    OR	A
    JP	Z, LAB_ram_ed4c
    LD	B, A
    POP	AF
    LD	A, 0x0
    ADC	A, A
    LD	(TM_VARS.m_esc_hex_cmd), A
    LD	E, H
    LD	C, 0x10
    LD	D, 0x0
LAB_ram_ecc7:
    ADD	HL, HL
    EX	DE, HL
    ADD	HL, HL
    EX	DE, HL
    LD	A, D
    JP	C, LAB_ram_ecd3
    CP	B
    JP	C, LAB_ram_ecd6
LAB_ram_ecd3:
    SUB	B
    LD	D, A
    INC	HL
LAB_ram_ecd6:
    DEC	C
    JP	NZ, LAB_ram_ecc7
    LD	DE, 0x0
    PUSH	DE
    PUSH	HL
    LD	HL, (TM_VARS.m_esc_param_1)
    EX	DE, HL
    LD	C,B
    CALL	SUB_ram_ebe2
    LD	A, 0x80
LAB_ram_ece9:
    RLCA
    DEC	B
    JP	P, LAB_ram_ece9
    CPL
    LD	B, A
LAB_ram_ecf0:
    POP	DE
    EX	(SP), HL
    LD	A,H
    ADD	HL, DE
    SUB	H
    CPL
    INC	A
    EX	(SP), HL
    PUSH	DE
    PUSH	BC
    LD	C, A
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	A, (TM_VARS.m_esc_hex_cmd)
    OR	A
    JP	NZ, LAB_ram_ed21
LAB_ram_ed0b:
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    DEC	H
    LD	A, C
    OR	A
    JP	Z, LAB_ram_ed37
    DEC	C
    DEC	L
    JP	LAB_ram_ed0b
LAB_ram_ed21:
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    DEC	H
    LD	A, C
    OR	A
    JP	Z, LAB_ram_ed37
    DEC	C
    INC	L
    JP	LAB_ram_ed21
LAB_ram_ed37:
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	BC
    LD	A,B
    SCF
    RLA
    JP	C, LAB_ram_ed44
    RLA
    INC	H
    INC	H
LAB_ram_ed44:
    LD	B, A
    DEC	C
    JP	NZ, LAB_ram_ecf0
    POP	HL
    POP	HL
    RET
LAB_ram_ed4c:
    LD	C,H
    CALL	SUB_ram_ebe2
    LD	A, 0x80
LAB_ram_ed52:
    RLCA
    DEC	B
    JP	P, LAB_ram_ed52
    CPL
    LD	B, A
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    POP	AF
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    JP	C, LAB_ram_ed7c
LAB_ram_ed66:
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    DEC	H
    LD	A, C
    OR	A
    JP	Z, LAB_ram_ed92
    DEC	C
    DEC	L
    JP	LAB_ram_ed66
LAB_ram_ed7c:
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    DEC	H
    LD	A, C
    OR	A
    JP	Z, LAB_ram_ed92
    DEC	C
    INC	L
    JP	LAB_ram_ed7c
LAB_ram_ed92:
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
LAB_ram_ed96:
    POP	AF
    LD	C,L
    LD	A,L
    OR	A
    JP	NZ, LAB_ram_ed9e
    INC	C
LAB_ram_ed9e:
    CALL	SUB_ram_ebe2
    LD	A, 0x80
LAB_ram_eda3:
    RLCA
    DEC	B
    JP	P, LAB_ram_eda3
    CPL
    LD	B, A
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
LAB_ram_edb3:
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    DEC	H
    LD	A,B
    SCF
    RLA
    JP	C, LAB_ram_edc8
    RLA
    INC	H
    INC	H
LAB_ram_edc8:
    LD	B, A
    DEC	C
    JP	NZ, LAB_ram_edb3
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
esc_draw_dot:
    LD	HL, (TM_VARS.m_esc_param_1)
    EX	DE, HL
    CALL	SUB_ram_ebe2
    LD	A, 0x80
LAB_ram_edda:
    RLCA
    DEC	B
    JP	P, LAB_ram_edda
    LD	B, A
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	A, (HL)
    XOR	B
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	B
    LD	(HL), A
    XOR	A
    OUT	(SYS_DD17PB), A
    RET
esc_fn_b:
    LD	A, (TM_VARS.m_esc_param_3)
    LD	B, A
    OR	A
    RET	Z
    LD	A, 0x7f
    CP	B
    RET	M
    XOR	A
    LD	D, A
    LD	E,B
    CALL	SUB_ram_ee53
    LD	A, 0x1
    LD	H, A
    SUB	B
    LD	C, A
    LD	A,B
    RLCA
    LD	B, A
    LD	A, 0x1
    SUB	B
    LD	L, A
    CCF
LAB_ram_ee11:
    INC	D
    LD	A, E
    CP	D
    JP	Z,SUB_ram_ee53
    CALL	SUB_ram_ee53
    LD	A,H
    ADD	A, 0x2
    LD	H, A
    LD	A,L
    ADD	A, 0x2
    LD	L, A
    LD	A, C
    ADD	A,H
    LD	C, A
    JP	NC, LAB_ram_ee11
LAB_ram_ee28:
    CCF
    INC	D
    DEC	E
    LD	A, D
    CP	E
    JP	Z,SUB_ram_ee53
    SUB	E
    CP	0x1
    RET	Z
    LD	A, E
    SUB	D
    CP	0x1
    JP	Z,SUB_ram_ee53
    CALL	SUB_ram_ee53
    LD	A,H
    ADD	A, 0x2
    LD	H, A
    LD	A,L
    ADD	A, 0x4
    LD	L, A
    JP	NC, LAB_ram_ee4a
    CCF
LAB_ram_ee4a:
    LD	A, C
    ADD	A,L
    LD	C, A
    JP	NC, LAB_ram_ee11
    JP	LAB_ram_ee28
SUB_ram_ee53:
    PUSH	HL
    PUSH	DE
    PUSH	BC
    PUSH	DE
    CALL	SUB_ram_ee6f
    LD	HL, (TM_VARS.m_esc_param_1)
    CALL	SUB_ram_eedc
    POP	DE
    CALL	SUB_ram_ee8f
    LD	HL, (TM_VARS.m_esc_param_1)
    CALL	SUB_ram_ef0b
    POP	BC
    POP	DE
    POP	HL
    XOR	A
    RET
SUB_ram_ee6f:
    LD	HL, (TM_VARS.m_esc_param_4)
    LD	A,L
    OR	A
    LD	C, D
    LD	B, E
    JP	NZ, LAB_ram_ee7f
    LD	A,H
    OR	A
    JP	NZ, LAB_ram_ee88
    RET
LAB_ram_ee7f:
    LD	A,H
    LD	H,L
    LD	E, C
OFF_ram_ee82:
    CALL	SUB_ram_eeaf
    LD	C, E
    OR	A
    RET	Z
LAB_ram_ee88:
    LD	H, A
    LD	E,B
    CALL	SUB_ram_eeaf
    LD	B, E
    RET
SUB_ram_ee8f:
    LD	HL, (TM_VARS.m_esc_param_4)
    LD	A,L
    OR	A
    LD	C, D
    LD	B, E
    JP	NZ, LAB_ram_ee9f
    LD	A,H
    OR	A
    JP	NZ, LAB_ram_eea8
    RET
LAB_ram_ee9f:
    LD	A,H
    LD	H,L
    LD	E,B
    CALL	SUB_ram_eeaf
    LD	B, E
    OR	A
    RET	Z
LAB_ram_eea8:
    LD	H, A
    LD	E, C
    CALL	SUB_ram_eeaf
    LD	C, E
    RET
SUB_ram_eeaf:
    LD	D, 0x0
    LD	L, D
    ADD	HL, HL
    JP	NC, LAB_ram_eeb7
    ADD	HL, DE
LAB_ram_eeb7:
    ADD	HL, HL
    JP	NC, LAB_ram_eebc
    ADD	HL, DE
LAB_ram_eebc:
    ADD	HL, HL
    JP	NC, LAB_ram_eec1
    ADD	HL, DE
LAB_ram_eec1:
    ADD	HL, HL
    JP	NC, LAB_ram_eec6
    ADD	HL, DE
LAB_ram_eec6:
    ADD	HL, HL
    JP	NC, LAB_ram_eecb
    ADD	HL, DE
LAB_ram_eecb:
    ADD	HL, HL
    JP	NC, LAB_ram_eed0
    ADD	HL, DE
LAB_ram_eed0:
    ADD	HL, HL
    JP	NC, LAB_ram_eed5
    ADD	HL, DE
LAB_ram_eed5:
    ADD	HL, HL
    JP	NC, LAB_ram_eeda
    ADD	HL, DE
LAB_ram_eeda:
    LD	E,H
    RET
SUB_ram_eedc:
    LD	A,H
    ADD	A,B
    JP	C, LAB_ram_eee8
    LD	D, A
    LD	A,L
    ADD	A, C
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_eee8:
    LD	A,H
    ADD	A,B
    JP	C, LAB_ram_eef4
    LD	D, A
    LD	A,L
    SUB	C
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_eef4:
    LD	A,H
    SUB	B
    JP	C, LAB_ram_ef00
    LD	D, A
    LD	A,L
    SUB	C
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_ef00:
    LD	A,H
    SUB	B
    RET	C
    LD	D, A
    LD	A,L
    ADD	A, C
    LD	E, A
    CALL	SUB_ram_ef3a
    RET
SUB_ram_ef0b:
    LD	A,H
    ADD	A, C
    JP	C, LAB_ram_ef17
    LD	D, A
    LD	A,L
    ADD	A,B
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_ef17:
    LD	A,H
    ADD	A, C
    JP	C, LAB_ram_ef23
    LD	D, A
    LD	A,L
    SUB	B
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_ef23:
    LD	A,H
    SUB	C
    JP	C, LAB_ram_ef2f
    LD	D, A
    LD	A,L
    SUB	B
    LD	E, A
    CALL	SUB_ram_ef3a
LAB_ram_ef2f:
    LD	A,H
    SUB	C
    RET	C
    LD	D, A
    LD	A,L
    ADD	A,B
    LD	E, A
    CALL	SUB_ram_ef3a
    RET
SUB_ram_ef3a:
    RET	C
    PUSH	HL
    PUSH	BC
    CALL	SUB_ram_ebe2
    LD	A, 0x80
LAB_ram_ef42:
    RLCA
    DEC	B
    JP	P, LAB_ram_ef42
    CPL
    LD	B, A
    EX	DE, HL
    LD	HL, (TM_VARS.m_curr_color)
    EX	DE, HL
    LD	A, 0x1
    OUT	(SYS_DD17PB), A
    LD	A, (HL)
    XOR	E
    AND	B
    XOR	E
    LD	(HL), A
    INC	H
    LD	A, (HL)
    XOR	D
    AND	B
    XOR	D
    LD	(HL), A
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	BC
    POP	HL
    RET

	; Full charset, Common + Latin letters
m_font_cp0:
	db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04
	db	0x04, 0x04, 0x04, 0x00, 0x00, 0x04, 0x14, 0x14
	db	0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, 0x0A, 0x1F
	db	0x0A, 0x1F, 0x0A, 0x0A, 0x04, 0x1E, 0x05, 0x0E
	db	0x14, 0x0F, 0x04, 0x03, 0x13, 0x08, 0x04, 0x02
	db	0x19, 0x18, 0x06, 0x09, 0x05, 0x02, 0x15, 0x09
	db	0x16, 0x06, 0x04, 0x02, 0x00, 0x00, 0x00, 0x00
	db	0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08, 0x02
	db	0x04, 0x08, 0x08, 0x08, 0x04, 0x02, 0x00, 0x0A
	db	0x04, 0x1F, 0x04, 0x0A, 0x00, 0x00, 0x04, 0x04
	db	0x1F, 0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00
	db	0x06, 0x04, 0x02, 0x00, 0x00, 0x00, 0x1F, 0x00
	db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06
	db	0x06, 0x00, 0x10, 0x08, 0x04, 0x02, 0x01, 0x00
	db	0x0E, 0x11, 0x19, 0x15, 0x13, 0x11, 0x0E, 0x04
	db	0x06, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x0E, 0x11
	db	0x10, 0x08, 0x04, 0x02, 0x1F, 0x1F, 0x08, 0x04
	db	0x08, 0x10, 0x11, 0x0E, 0x08, 0x0C, 0x0A, 0x09
	db	0x1F, 0x08, 0x08, 0x1F, 0x01, 0x0F, 0x10, 0x10
	db	0x11, 0x0E, 0x0C, 0x02, 0x01, 0x0F, 0x11, 0x11
	db	0x0E, 0x1F, 0x10, 0x08, 0x04, 0x02, 0x02, 0x02
	db	0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E, 0x0E
	db	0x11, 0x11, 0x1E, 0x10, 0x08, 0x06, 0x00, 0x06
	db	0x06, 0x00, 0x06, 0x06, 0x00, 0x00, 0x06, 0x06
	db	0x00, 0x06, 0x04, 0x02, 0x08, 0x04, 0x02, 0x01
	db	0x02, 0x04, 0x08, 0x00, 0x00, 0x1F, 0x00, 0x1F
	db	0x00, 0x00, 0x02, 0x04, 0x08, 0x10, 0x08, 0x04
	db	0x02, 0x0E, 0x11, 0x10, 0x08, 0x04, 0x00, 0x04
	db	0x0E, 0x11, 0x10, 0x16, 0x15, 0x15, 0x0E, 0x04
	db	0x0A, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x0F, 0x11
	db	0x11, 0x0F, 0x11, 0x11, 0x0F, 0x0E, 0x11, 0x01
	db	0x01, 0x01, 0x11, 0x0E, 0x07, 0x09, 0x11, 0x11
	db	0x11, 0x09, 0x07, 0x1F, 0x01, 0x01, 0x0F, 0x01
	db	0x01, 0x1F, 0x1F, 0x01, 0x01, 0x0F, 0x01, 0x01
	db	0x01, 0x0E, 0x11, 0x01, 0x1D, 0x11, 0x11, 0x1E
	db	0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11, 0x0E
	db	0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x1C, 0x08
	db	0x08, 0x08, 0x08, 0x09, 0x06, 0x11, 0x09, 0x05
	db	0x03, 0x05, 0x09, 0x11, 0x01, 0x01, 0x01, 0x01
	db	0x01, 0x01, 0x1F, 0x11, 0x1B, 0x15, 0x15, 0x11
	db	0x11, 0x11, 0x11, 0x11, 0x13, 0x15, 0x19, 0x11
	db	0x11, 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E
	db	0x0F, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x01, 0x0E
	db	0x11, 0x11, 0x11, 0x15, 0x09, 0x16, 0x0F, 0x11
	db	0x11, 0x0F, 0x05, 0x09, 0x11, 0x1E, 0x01, 0x01
	db	0x0E, 0x10, 0x10, 0x0F, 0x1F, 0x04, 0x04, 0x04
	db	0x04, 0x04, 0x04, 0x11, 0x11, 0x11, 0x11, 0x11
	db	0x11, 0x0E, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x0A
	db	0x04, 0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A
	db	0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11, 0x11
	db	0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x1F, 0x10
	db	0x08, 0x04, 0x02, 0x01, 0x1F, 0x0E, 0x02, 0x02
	db	0x02, 0x02, 0x02, 0x0E, 0x00, 0x01, 0x02, 0x04
	db	0x08, 0x10, 0x00, 0x0E, 0x08, 0x08, 0x08, 0x08
	db	0x08, 0x0E, 0x0E, 0x11, 0x00, 0x00, 0x00, 0x00
	db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F
	db	0x1C, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00
	db	0x00, 0x0E, 0x10, 0x1E, 0x13, 0x1E, 0x01, 0x01
	db	0x0D, 0x13, 0x11, 0x11, 0x0F, 0x00, 0x00, 0x0E
	db	0x01, 0x01, 0x01, 0x0E, 0x10, 0x10, 0x16, 0x19
	db	0x11, 0x11, 0x1E, 0x00, 0x00, 0x0E, 0x11, 0x1F
	db	0x01, 0x0E, 0x18, 0x04, 0x04, 0x0E, 0x04, 0x04
	db	0x04, 0x00, 0x0E, 0x11, 0x11, 0x1E, 0x10, 0x0E
	db	0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x11, 0x04
	db	0x00, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x00
	db	0x08, 0x08, 0x08, 0x08, 0x06, 0x01, 0x01, 0x09
	db	0x05, 0x03, 0x05, 0x09, 0x04, 0x04, 0x04, 0x04
	db	0x04, 0x04, 0x08, 0x00, 0x00, 0x0F, 0x15, 0x15
	db	0x15, 0x15, 0x00, 0x00, 0x09, 0x13, 0x11, 0x11
	db	0x11, 0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E
	db	0x00, 0x00, 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x00
	db	0x00, 0x0E, 0x11, 0x11, 0x1E, 0x10, 0x00, 0x00
	db	0x0D, 0x13, 0x01, 0x01, 0x01, 0x00, 0x00, 0x1E
	db	0x01, 0x0E, 0x10, 0x0F, 0x04, 0x04, 0x0E, 0x04
	db	0x04, 0x04, 0x18, 0x00, 0x00, 0x11, 0x11, 0x11
	db	0x19, 0x16, 0x00, 0x00, 0x11, 0x11, 0x0A, 0x0A
	db	0x04, 0x00, 0x00, 0x11, 0x15, 0x15, 0x15, 0x0A
	db	0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x00
	db	0x00, 0x11, 0x11, 0x1E, 0x10, 0x0C, 0x00, 0x00
	db	0x1F, 0x08, 0x04, 0x02, 0x1F, 0x10, 0x08, 0x08
	db	0x04, 0x08, 0x08, 0x10, 0x04, 0x04, 0x04, 0x04
	db	0x04, 0x04, 0x04, 0x04, 0x08, 0x08, 0x10, 0x08
	db	0x08, 0x04, 0x00, 0x02, 0x15, 0x08, 0x00, 0x00
	db	0x00, 0x15, 0x00, 0x15, 0x00, 0x15, 0x00, 0x15
	db	0x00, 0x00, 0x09, 0x15, 0x17, 0x15, 0x09, 0x00
	db	0x00, 0x06, 0x08, 0x0E, 0x09, 0x16, 0x06, 0x01
	db	0x01, 0x06, 0x09, 0x09, 0x06, 0x00, 0x00, 0x09
	db	0x09, 0x09, 0x1F, 0x10, 0x00, 0x00, 0x0E, 0x0A
	db	0x0A, 0x1F, 0x11, 0x00, 0x00, 0x0E, 0x11, 0x1F
	db	0x01, 0x1E, 0x00, 0x04, 0x0E, 0x15, 0x15, 0x0E
	db	0x04, 0x00, 0x00, 0x0F, 0x09, 0x01, 0x01, 0x01
	db	0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x00
	db	0x00, 0x11, 0x19, 0x15, 0x13, 0x11, 0x0A, 0x04
	db	0x11, 0x19, 0x15, 0x13, 0x11, 0x00, 0x00, 0x11
	db	0x09, 0x07, 0x09, 0x11, 0x00, 0x00, 0x1C, 0x12
	db	0x12, 0x12, 0x11, 0x00, 0x00, 0x11, 0x1B, 0x15
	db	0x11, 0x11, 0x00, 0x00, 0x11, 0x11, 0x1F, 0x11
	db	0x11, 0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E
	db	0x00, 0x00, 0x1F, 0x11, 0x11, 0x11, 0x11, 0x00
	db	0x00, 0x1E, 0x11, 0x1E, 0x14, 0x12, 0x00, 0x00
	db	0x07, 0x09, 0x07, 0x01, 0x01, 0x00, 0x00, 0x0E
	db	0x01, 0x01, 0x01, 0x0E, 0x00, 0x00, 0x1F, 0x04
	db	0x04, 0x04, 0x04, 0x00, 0x00, 0x11, 0x11, 0x1E
	db	0x10, 0x0E, 0x00, 0x00, 0x15, 0x15, 0x0E, 0x15
	db	0x15, 0x00, 0x00, 0x03, 0x05, 0x07, 0x09, 0x07
	db	0x00, 0x00, 0x01, 0x01, 0x07, 0x09, 0x07, 0x00
	db	0x00, 0x11, 0x11, 0x13, 0x15, 0x13, 0x00, 0x00
	db	0x0E, 0x11, 0x0C, 0x11, 0x0E, 0x00, 0x00, 0x15
	db	0x15, 0x15, 0x15, 0x1F, 0x00, 0x00, 0x07, 0x08
	db	0x0E, 0x08, 0x07, 0x00, 0x00, 0x15, 0x15, 0x15
	db	0x1F, 0x10, 0x00, 0x00, 0x09, 0x09, 0x0E, 0x08
	db	0x08, 0x00, 0x00, 0x06, 0x05, 0x0C, 0x14, 0x0C

; 32 chars cp=1 (Russian letters)
m_font_matrix_cp2:
	db	0x09, 0x15, 0x15, 0x17, 0x15, 0x15, 0x09, 0x04
	db	0x0A, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x1F, 0x11
	db	0x01, 0x0F, 0x11, 0x11, 0x1F, 0x09, 0x09, 0x09
	db	0x09, 0x09, 0x1F, 0x10, 0x0C, 0x0A, 0x0A, 0x0A
	db	0x0A, 0x1F, 0x11, 0x1F, 0x01, 0x01, 0x0F, 0x01
	db	0x01, 0x1F, 0x04, 0x0E, 0x15, 0x15, 0x15, 0x0E
	db	0x04, 0x1F, 0x11, 0x01, 0x01, 0x01, 0x01, 0x01
	db	0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11, 0x11
	db	0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x04, 0x15
	db	0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x09, 0x05
	db	0x03, 0x05, 0x09, 0x11, 0x1C, 0x12, 0x12, 0x12
	db	0x12, 0x12, 0x11, 0x11, 0x1B, 0x15, 0x15, 0x11
	db	0x11, 0x11, 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11
	db	0x11, 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E
	db	0x1F, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E
	db	0x11, 0x11, 0x11, 0x1E, 0x12, 0x11, 0x0F, 0x11
	db	0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E, 0x11, 0x01
	db	0x01, 0x01, 0x11, 0x0E, 0x1F, 0x04, 0x04, 0x04
	db	0x04, 0x04, 0x04, 0x11, 0x11, 0x11, 0x11, 0x1E
	db	0x10, 0x0E, 0x15, 0x15, 0x15, 0x0E, 0x15, 0x15
	db	0x15, 0x0F, 0x11, 0x11, 0x0F, 0x11, 0x11, 0x0F
	db	0x01, 0x01, 0x01, 0x0F, 0x11, 0x11, 0x0F, 0x11
	db	0x11, 0x11, 0x13, 0x15, 0x15, 0x13, 0x0E, 0x11
	db	0x10, 0x0C, 0x10, 0x11, 0x0E, 0x15, 0x15, 0x15
	db	0x15, 0x15, 0x15, 0x1F, 0x0E, 0x11, 0x10, 0x1C
	db	0x10, 0x11, 0x0E, 0x15, 0x15, 0x15, 0x15, 0x15
	db	0x1F, 0x10, 0x11, 0x11, 0x11, 0x1E, 0x10, 0x10
	db	0x10, 0x1F, 0x15, 0x1F, 0x15, 0x1F, 0x15, 0x1C

m_print_write:
    LD	SP, m_font_cp0+28
    ds  24, 0xFF

m_ramdisk_read:
    PUSH	HL
    PUSH	DE
    LD	A, D
    AND	0x1
    OR	0x2
    LD	B, A
    XOR	A
    LD	A, E
    RRA
    LD	D, A
    LD	A, 0x0
    RRA
    LD	E, A
LAB_ram_f3ee:
    LD	A,B
    OUT	(SYS_DD17PB), A
    LD	A, (DE)
    LD	C, A
    XOR	A
    OUT	(SYS_DD17PB), A
    LD	(HL), C
    INC	HL
    INC	DE
    LD	A, E
    ADD	A, A
    JP	NZ, LAB_ram_f3ee
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	DE
    POP	HL
    RET
m_ramdisk_write:
    PUSH	HL
    PUSH	DE
    LD	A, D
    AND	0x1
    OR	0x2
    LD	B, A
    XOR	A
    LD	A, E
    RRA
    LD	D, A
    LD	A, 0x0
    RRA
    LD	E, A
LAB_ram_f414:
    XOR	A
    OUT	(SYS_DD17PB), A
    LD	C, (HL)
    LD	A,B
    OUT	(SYS_DD17PB), A
    LD	A, C
    LD	(DE), A
    INC	HL
    INC	DE
    LD	A, E
    ADD	A, A
    JP	NZ, LAB_ram_f414
    XOR	A
    OUT	(SYS_DD17PB), A
    POP	DE
    POP	HL
    RET

; ------------------------------------------------------
;  Write block to Tape
;  In: DE - block ID,
;      HL -> block of data.
; ------------------------------------------------------
m_tape_write:
    PUSH	HL
    PUSH	DE
    PUSH	DE
    LD	BC,2550
    LD	A,PIC_POLL_MODE		     					; pool mode
    OUT	(PIC_DD75RS), A
    LD	A,TMR0_SQWAVE		       					; tmr0, load lsb+msb, sq wave, bin
    OUT	(TMR_DD70CTR), A
    LD	A, C
    OUT	(TMR_DD70C1), A
    LD	A,B
    OUT	(TMR_DD70C1), A
	; Write Hi+Lo, Hi+Lo
    LD	DE, 0x4			    						; repeat next 4 times
tw_wait_t0_l1:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ			 						; check rst4 from timer#0
    JP	NZ,tw_wait_t0_l1
    LD	A, D
    CPL
    LD	D, A
    OR	A
    LD	A,TL_HIGH			 						; tape level hi
    JP	NZ,tw_set_tape_lvl
    LD	A,TL_LOW			  						; tape level low
tw_set_tape_lvl:
    OUT	(DD67PC), A		    						; set tape level
    LD	A,TMR0_SQWAVE		       					; tmr0, load lsb+msb, swq, bin
	; timer on
    OUT	(TMR_DD70CTR), A
    LD	A, C
    OUT	(TMR_DD70C1), A
    LD	A,B
    OUT	(TMR_DD70C1), A
    DEC	E
    JP	NZ,tw_wait_t0_l1
tw_wait_t0_l2:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ
    JP	NZ,tw_wait_t0_l2
	; Write 00 at start
    LD	A, 0x0
    CALL	m_tape_wr_byte
	; Write 0xF5 marker
    LD	A, 0xf5
    CALL	m_tape_wr_byte
    LD	E, 0x0			     						; checksum=0
	; Write block ID
    POP	BC
    LD	A, C
    CALL	m_tape_wr_byte
    LD	A,B
    CALL	m_tape_wr_byte
	; Write 128 data bytes
    LD	B,128
tw_wr_next_byte:
    LD	A, (HL)
    CALL	m_tape_wr_byte
    INC	HL
    DEC	B
    JP	NZ,tw_wr_next_byte
	; Write checksum
    LD	A, E
    CALL	m_tape_wr_byte
	; Write final zero byte
    LD	A, 0x0
    CALL	m_tape_wr_byte
tw_wait_t0_l3:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ
    JP	NZ,tw_wait_t0_l3
    LD	A,TL_MID									; tape level middle
    OUT	(DD67PC), A
    POP	DE
    POP	HL
    RET
; ------------------------------------------------------
;  Write byte to tape
;  Inp: A - byte top write
;       D - current level
;       E - current checksum
; ------------------------------------------------------
m_tape_wr_byte:
    PUSH	BC
; calc checksum
    LD	B, A
    LD	A, E
    SUB	B
    LD	E, A
    LD	C,8			       							; 8 bit in byte
twb_get_bit:
    LD	A,B
    RRA
    LD	B, A
    JP	C,twb_bit_hi
twb_wait_t0_l1:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ
    JP	NZ,twb_wait_t0_l1
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A
	; program for 360 cycles
    LD	A, 0x68
    OUT	(TMR_DD70C1), A
    LD	A, 0x1
    OUT	(TMR_DD70C1), A
	; change amplitude
    LD	A, D
    CPL
    LD	D, A
    OR	A
    LD	A,TL_HIGH
    JP	NZ,twb_out_bit_l1
    LD	A,TL_LOW
twb_out_bit_l1:
    OUT	(DD67PC), A
    DEC	C
    JP	NZ,twb_get_bit
    POP	BC
    RET
twb_bit_hi:
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ
    JP	NZ,twb_bit_hi
	; program for 660 cycles
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A
    LD	A, 0x94
    OUT	(TMR_DD70C1), A
    LD	A, 0x2
    OUT	(TMR_DD70C1), A
	; change amplitude
    LD	A, D
    CPL
    LD	D, A
    OR	A
    LD	A,TL_HIGH
    JP	NZ,twb_out_bit_l2
    LD	A,TL_LOW
twb_out_bit_l2:
    OUT	(DD67PC), A
    DEC	C
    JP	NZ,twb_get_bit
    POP	BC
    RET

; ------------------------------------------------------
;  Load block from Tape
;  In: HL -> buffer to receive bytes from Tape
;  Out: A = 0 - ok,
;       1 - CRC error,
;       2 - unexpected block Id
;       4 - key pressed
; ------------------------------------------------------
m_tape_read:
    PUSH	HL
    PUSH	DE
    LD	A,PIC_POLL_MODE								; pool mode
    OUT	(PIC_DD75RS), A
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A							; tmr0, load lsb+msb, sq wave
    LD	A, 0x0
	; tmr0 load 0x0000
    OUT	(TMR_DD70C1), A
    OUT	(TMR_DD70C1), A
    LD	C,3
tr_wait_3_changes:
    CALL	ccp_read_tape_bit_kbd
    INC	A
    JP	Z,tr_key_pressed_l0
    LD	A,B
    ADD	A,4
    JP	P,tr_wait_3_changes
    DEC	C
    JP	NZ,tr_wait_3_changes
tr_wait_4th_change:
    CALL	ccp_read_tape_bit_kbd
    INC	A
    JP	Z,tr_key_pressed_l0
    LD	A,B
    ADD	A,4
    JP	M,tr_wait_4th_change
    LD	C, 0x0
tr_wait_f5_marker:
    CALL	ccp_read_tape_bit_kbd
    INC	A
    JP	Z,tr_key_pressed_l0
    DEC	A
    RRA
    LD	A, C
    RRA
    LD	C, A
    CP	0xf5
    JP	NZ,tr_wait_f5_marker
    LD	E, 0x0			     						; checksum = 0
	; Read blk ID
    CALL	m_tape_read_byte
    JP	NC,tr_err_read_id
    LD	C, D
    CALL	m_tape_read_byte
    JP	NC,tr_err_read_id
    LD	B, D
    PUSH	BC
	; Read block, 128 bytes
    LD	C,128
tr_read_next_b:
    CALL	m_tape_read_byte
    JP	NC,tr_err_read_blk
    LD	(HL), D
    INC	HL
    DEC	C
    JP	NZ,tr_read_next_b

	; Read checksum
    CALL	m_tape_read_byte
    JP	NC,tr_err_read_blk
    LD	A, E
    OR	A
    JP	Z,tr_checksum_ok
    LD	A, 0x1			    						; bad checksum
tr_checksum_ok:
    POP	BC
tr_return:
    POP	DE
    POP	HL
    RET
tr_err_read_blk:
    POP	BC
    LD	BC, 0x0
tr_err_read_id:
    LD	A, 0x2			     						; read error
    JP	tr_return
tr_key_pressed_l0:
    CALL	tm_con_in
    LD	C, A			       						; store key code in C
    LD	B, 0x0
    LD	A, 0x4
    JP	tr_return
m_tape_read_byte:
    PUSH	BC

; ------------------------------------------------------
;  Read byte from Tape
;  Out: D - byte
;       CF is set if ok, cleared if error
; ------------------------------------------------------
    LD	C,8
trb_next_bit:
    CALL	ccp_read_tape_bit
	; push bit from lo to hi in D
    RRA
    LD	A, D
    RRA
    LD	D, A
    LD	A,4
    ADD	A,B
    JP	NC,trb_ret_err
    DEC	C
    JP	NZ,trb_next_bit
	; calc checksum
    LD	A, D
    ADD	A, E
    LD	E, A
    SCF
trb_ret_err:
    POP	BC
    RET

; ------------------------------------------------------
;  Read bit from tape
;  Out: A - bit from tape
;       B - time from last bit
; ------------------------------------------------------
ccp_read_tape_bit:
    IN	A, (KBD_DD78PB)								; Read Tape bit 5 (data)
    AND	TAPE_P
    LD	B, A
rtb_wait_change:
    IN	A, (KBD_DD78PB)
    AND	TAPE_P
    CP	B
    JP	Z,rtb_wait_change
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A
	; [360...480...660] 0x220=544d
    IN	A, (TMR_DD70C1)								; get tmer#0 lsb
    ADD	A, 0x20
    IN	A, (TMR_DD70C1)								; get tmer#0 msb
    LD	B, A
    ADC	A, 0x2
	; reset timer to 0
    LD	A, 0x0
    OUT	(TMR_DD70C1), A
    OUT	(TMR_DD70C1), A
	; For 0 - 65535-360+544 -> overflow P/V=1
	; For 1 - 65535-660+544 -> no overflow P/V=0
    RET	P
    INC	A
    RET

; ------------------------------------------------------
;  Read bit from tape with keyboard interruption
;  Out: A - bit from tape
;       B - time from last bit
; ------------------------------------------------------
ccp_read_tape_bit_kbd:
    IN	A, (KBD_DD78PB)
    AND	TAPE_P
    LD	B, A			       						; save tape bit state
	; wait change with keyboard check
twc_wait_change:
    IN	A, (PIC_DD75RS)
    AND	KBD_IRQ
    JP	NZ,twc_key_pressed
    IN	A, (KBD_DD78PB)
    AND	TAPE_P
    CP	B
    JP	Z,twc_wait_change
	; measure time
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A
	; read lsb+msb
    IN	A, (TMR_DD70C1)
    ADD	A, 0x20
    IN	A, (TMR_DD70C1)
    LD	B, A
    ADC	A, 0x2
	; reset timer#0
    LD	A, 0x0
    OUT	(TMR_DD70C1), A
    OUT	(TMR_DD70C1), A
	; flag P/V is set for 0
    RET	P
    INC	A
    RET
twc_key_pressed:
    LD	A, 0xff
    RET

; ------------------------------------------------------
;  Wait tape block
;  Inp: A - periods to wait
;  Out: A=4 - interrupded by keyboard, C=key
; ------------------------------------------------------
m_tape_wait:
    OR	A
    RET	Z
    PUSH	DE
    LD	B, A
m_wait_t4:
    LD	C,B
    IN	A, (KBD_DD78PB)
    AND	TAPE_P			    						; Get TAPE4 (Wait det) and save
    LD	E, A			       						; store T4 state to E
m_wait_next_2ms:
    LD	A,TMR0_SQWAVE
    OUT	(TMR_DD70CTR), A
; load 3072 = 2ms
    XOR	A
    OUT	(TMR_DD70C1), A
    LD	A, 0xc
    OUT	(TMR_DD70C1), A
m_wait_tmr_key:
    IN	A, (PIC_DD75RS)
    AND	KBD_IRQ			   							; RST1 flag (keyboard)
    JP	NZ,mt_key_pressed
    IN	A, (PIC_DD75RS)
    AND	TIMER_IRQ			 						; RST4 flag (timer out)
    JP	Z,m_wait_no_rst4
    IN	A, (KBD_DD78PB)
    AND	TAPE_P			    						; TAPE4 not changed?
    CP	E
    JP	NZ,m_wait_t4								; continue wait
    JP	m_wait_tmr_key
m_wait_no_rst4:
    DEC	C
    JP	NZ,m_wait_next_2ms
    XOR	A
    POP	DE
    RET
mt_key_pressed:
    CALL	tm_con_in
    LD	C, A			       						; C = key pressed
    LD	A, 0x4			     						; a=4 interrupted by key
    POP	DE
    RET

; ------------------------------------------------------
;  Check block marker from Tape
;  Out: A=0 - not detected, 0xff - detected
; ------------------------------------------------------
m_tape_blk_detect:
    IN	A, (KBD_DD78PB)
    AND	TAPE_D			    						; TAPE5 - Pause detector
    LD	A, 0x0
    RET	Z
    CPL
    RET

esc_64x23_cursor:
    db	ASCII_ESC, '6', '1', ASCII_ESC, '8', '0', 0

msg_turbo_mon:
    db	"\f\r\n   Turbo MONITOR   Ver 1.1 for 13.01.92   (C)Alex Z.\r\n",0

m_rst1_handler:
    DI
    LD	(TM_VARS.rst_hl_save), HL
    LD	HL, 0x2
    ADD	HL,SP
    LD	(TM_VARS.rst_sp_save), HL
    POP	HL
    LD	SP, TM_VARS.rst_hl_save
    PUSH	DE
    PUSH	BC
    PUSH	AF
    LD	(TM_VARS.rst_ret_addr), HL
    LD	(TM_VARS.tm_hrg), HL
    JP	tm_main
tm_rst_ret:
    LD	A, 0xc3
    LD	(TM_VARS.rst_ret_JP), A
    LD	SP, TM_VARS.rst_af_save
    POP	AF
    POP	BC
    POP	DE
    POP	HL
    LD	SP, HL
    LD	HL, (TM_VARS.rst_hl_save)
    JP	TM_VARS.rst_ret_JP

m_cold_start:
    LD	HL, EXT_RAM.loaded_program
    LD	(TM_VARS.tm_hrg), HL
tm_main:
    LD	SP, TM_VARS.tm_stsp
    LD	DE,esc_64x23_cursor							; FORM61
    CALL	tm_print
    LD	DE, msg_turbo_mon							;= '\f'
    CALL	tm_out_strz
    LD	DE, 0x363d									; 54 x '='
    CALL	tm_rpt_print
    CALL	tm_beeep

tm_mon:
    LD	DE, 0x300
    CALL	tm_screen
    CALL	tm_lps
    LD	DE, 0x520
    CALL	tm_rpt_print
    LD	HL,msg_digits		       ;= "0123456789ABCDEF"

	; Out '012345789ABCDEF' string
tm_tit:
    CALL	tm_print_SP
    LD	C, (HL)
    CALL	tm_sym_out
    INC	HL
    LD	A, (HL)
    OR	A
    JP	NZ, tm_tit
    LD	HL, (TM_VARS.tm_hrg)
    LD	L, 0x0
tm_adr:
    CALL	tm_print_LFCR_hexw

tm_prh:
    LD	A, (HL)
    CALL	tm_hex_b
    INC	L
    LD	A,L
    AND	0xf
    CP	0x0
    JP	NZ,tm_prh
    LD	A,L
    SUB	0x10
    LD	L, A
    CALL	tm_print_SP
    CALL	tm_buk
    LD	A,L
    CP	0x0
    JP	NZ,tm_adr
    CALL	tm_print_LFCR
    CALL	tm_lpr
    LD	DE, 0x363d			 						; 54 x '='
    CALL	tm_rpt_print
    CALL	tm_print_LFCR
    LD	DE,tm_msg_regs								;= "A,FB,CD,EH,L SP"
    LD	HL, TM_VARS.rst_af_save

LAB_ram_f717:
    LD	B, 0x3

LAB_ram_f719:
    LD	A, (DE)										;= "A,FB,CD,EH,L SP"
    LD	C, A
    CP	0xff
    JP	Z,tm_out_contacts
    CP	0x0
    JP	Z, LAB_ram_f744
    CALL	tm_sym_out
    INC	DE
    DEC	B
    JP	NZ, LAB_ram_f719
    LD	C,'='
    CALL	tm_sym_out
    INC	HL
    LD	A, (HL)
    CALL	tm_hex_b
    DEC	HL
    LD	A, (HL)
    CALL	tm_hex_b
    INC	HL
    INC	HL
    CALL	tm_print_SP
    JP	LAB_ram_f717
LAB_ram_f744:
    INC	HL
    INC	DE
    JP	LAB_ram_f719

tm_msg_regs:
    db	"A,FB,CD,EH,L SP",0
    db	" PC", 0xFF

tm_out_contacts:
    LD	DE, m_msg_contacts							;= "       (Chernogolovka Mosk.reg.  ...
    CALL	tm_out_strz
    LD	HL, (TM_VARS.tm_hrg)
tm_kur:
    LD	DE, 0x405
    LD	A, L
    AND	0xf0
    RRCA
    RRCA
    RRCA
    RRCA
    ADD	A, D
    LD	D, A
    LD	A, L
    AND	0xf
    ADD	A, A
    ADD	A, E
    LD	E, A
    CALL	tm_screen
    LD	A, (TM_VARS.tm_tbu)
    CP	0x9
    JP	Z, tm_tabu
    LD	B, 0x1
tm_m2:
    CALL	tm_con_in
    LD	C, A
    CP	0x3
    JP	Z, m_print_log_sep
    CALL	tm_poke
    LD	A, B
    OR	A
    JP	NZ, tm_m6
    CALL	tm_re1
    JP	tm_m2
tm_m6:
    LD	A, C
    CP	0x9
    JP	NZ, tm_m7
    LD	(TM_VARS.tm_tbu), A
    JP	tm_kur
tm_tabu:
    CALL	tm_print_CR
    LD	E, '&'
    LD	A, L
    AND	0xf
    ADD	A, E
    LD	E, A
    CALL	tm_scr1
tm_tab:
    CALL	tm_get_key_ctrl_c
    CP	ASCII_TAB
    JP	NZ, tm_m7
    XOR	A
    LD	(TM_VARS.tm_tbu), A
    JP	tm_kur
tm_m7:
    CP	0x8b
    JP	Z, tm_search
    CP	0x9e
    JP	Z, tm_f1
    CP	0x81
    JP	Z, tm_f2
    CP	0x86
    JP	Z, tm_f3
    CP	0x92
    JP	Z, tm_f4
    CP	0x83
    JP	Z, tm_f5
    LD	A, (TM_VARS.tm_tbu)
    CP	0x9
    LD	A, C
    JP	NZ, tm_m8_monitor
    CALL	tm_m9
    JP	tm_tab
tm_m9:
    CP	0x93
    JP	Z, tm_leta
    CP	0x8
    JP	Z, tm_leta
    CP	0x84
    JP	Z, tm_rgta
    CP	0x85
    JP	Z, tm_up
    CP	0x98
    JP	Z, tm_down
    AND	0x7f
    CP	0x20
    LD	(HL), C
    JP	NC, tm_met1
    LD	C, 0x20
    CP	ASCII_CR
    JP	NZ, tm_met1
    CALL	tm_sym_out
    CALL	tm_rigth1
    LD	(HL), ASCII_LF
    LD	C, 0x20
tm_met1:
    CALL	tm_sym_out
    JP	tm_rigth1
tm_leta:
    LD	A, L
    OR	A
    RET	Z
    AND	0xf
    JP	NZ, tm_left1
    LD	C, 0x19										; EM (End of medium)
    CALL	tm_sym_out
    LD	DE, 0x1018									; 16 x CAN (Cancel)
    CALL	tm_rpt_print
tm_left1:
    DEC	L
    LD	C, 0x8										; BS (Backspace)
    JP	tm_sym_out
tm_rgta:
    LD	C, 0x18										; CAN
    CALL	tm_sym_out
tm_rigth1:
    INC	L
    JP	Z, tm_left1
tm_rigth2:
    LD	A, L
    AND	0xf
    RET	NZ
    LD	DE, 0x1008									; 16 x BS
    CALL	tm_rpt_print
    LD	C, ASCII_LF
    JP	tm_sym_out
tm_m8_monitor:
    CP	ASCII_ESC
    JP	NZ, tm_m3
    CALL	tm_niz
    JP	tm_rst_ret
tm_m3:
    CP	ASCII_CR
    JP	Z, tm_main
    CP	0x99
    JP	Z, tm_fill
    CP	0x7f
    JP	Z, tm_fill_nxt2
    CP	'+'
    JP	Z, tm_plus
    CP	'-'
    JP	Z, tm_minus
    CP	'G'
    JP	NZ, tm_rstr
    LD	DE, tm_main
    PUSH	DE
    JP	(HL)
tm_rstr:
    CP	'J'
    JP	Z, tm_jump
    CP	'H'
    JP	Z, tm_add
    CP	'M'
    JP	Z, tm_move
    CP	'R'
    JP	Z, tm_dsk_read
    CP	'W'
    JP	Z, tm_dsk_write
    CP	'T'
    JP	Z, tm_print_t
    CP	'P'
    LD	(TM_VARS.tm_hrg), HL
    JP	Z, LAST										; ???
    CP	'p'
    JP	Z, tm_lprn
    CP	0x10
	; if key 0x10 - turn on duplicate output to printer
    JP	Z, tm_ltab
    CALL	tm_met2
    LD	(TM_VARS.tm_hrg), HL
    JP	tm_m2
tm_met2:
    CP	0x93
    JP	Z, tm_left
    CP	0x8
    JP	Z, tm_left
    CP	0x84
    JP	Z, tm_rght
    CP	0x85
    JP	Z, tm_up
    CP	0x98
    JP	Z, tm_down
    RET
tm_left:
    LD	A,B
    CP	0x2
    JP	Z, tm_le2
    LD	A,L
    AND	0xf
    RET	Z
tm_le3:
    DEC	L
    LD	B, 0x2
tm_le1:
    LD	C, ASCII_BS
    JP	tm_sym_out
tm_le2:
    LD	B, 0x1
    JP	tm_le1
tm_rght:
    LD	C, 0x18
    CALL	tm_sym_out
    LD	A, B
    CP	0x1
    LD	B, 0x2
    RET	Z
tm_re1:
    INC	L
    JP	Z, tm_le3
    LD	A, L
    AND	0xf
    LD	B, 0x1
    JP	Z, tm_print_LFCR_hexw
    RET
tm_up:
    LD	A, L
    AND	0xf0
    RET	Z
    LD	A, L
    SUB	0x10
    LD	L, A
    LD	C, 0x19
    JP	tm_sym_out
tm_down:
    LD	A, L
    ADD	A, 0x10
    AND	0xf0
    RET	Z
    LD	A, 0x10
    ADD	A, L
    LD	L, A
    LD	C, 0xa
    JP	tm_sym_out

; ------------------------------------------------------
; Get nibbles from A and (HL), conver to byte
; put back to (HL), print nibble
; ------------------------------------------------------
tm_poke:
    CP	'G'
    RET	P
    CP	'0'
    RET	M
    SUB	'0'
    CP	10
    JP	M, p_is_alpha
    SUB	0x7
p_is_alpha:
    PUSH	AF
    CALL	tm_print_hex_nibble
    LD	A, B
    CP	0x2
    JP	Z, tm_m5
    LD	A, (HL)
    AND	0xf
    LD	B, A
    POP	AF
    RLCA
    RLCA
    RLCA
    RLCA
    ADD	A, B
    LD	(HL), A
    LD	B, 0x2
    RET

tm_m5:
    LD	A, (HL)
    AND	0xf0
    LD	B, A
    POP	AF
    ADD	A, B
    LD	(HL), A
    XOR	A
    LD	B, A
    RET

tm_pokh:
    CALL	tm_pok
    DEC	HL
tm_pok:
    LD	B, 0x1
tm_pk1:
    CALL	tm_get_key_ctrl_c
    CALL	tm_poke
    LD	A, B
    OR	A
    JP	NZ, tm_pk1
    RET
tm_buk:
    LD	A, (HL)
    LD	C, A
    AND	0x7f
    CP	0x20
    JP	P, tm_m24
    LD	C, 0x20
tm_m24:
    CALL	tm_sym_out
    INC	L
    LD	A, L
    AND	0xf
    CP	0x0
    JP	NZ, tm_buk
    RET
m_msg_jump:
    db	"JAMP\r\n", 0

tm_jump:
    LD	DE, 0x300
    CALL	tm_screen
    LD	DE, m_msg_jump		       					;= "JAMP\r\n"
    CALL	tm_print
    LD	HL, TM_VARS.tm_hrg+1
    CALL	tm_pokh
    JP	tm_mon
m_msg_add:
    db	"\fADD [", 0

tm_add:
    LD	DE,m_msg_add								;= "\fADD ["
    CALL	tm_print
    LD	HL, TM_VARS.tm_strt+1
    CALL	tm_pokh
    LD	C,'+'
    CALL	tm_sym_out
    LD	HL, TM_VARS.tm_strt+3
    CALL	tm_pokh
    LD	C,'='
    CALL	tm_sym_out
    LD	HL, (TM_VARS.tm_strt)
    EX	DE, HL
    LD	HL, (TM_VARS.tm_strt+2)
    ADD	HL, DE
    CALL	tm_hex_hl
    CALL	tm_con_in
    JP	tm_main

m_msg_move:
    db	"\fMOVE }", 0

tm_move:
    LD	DE,m_msg_move		       					;= "\fMOVE }"
    CALL	tm_print
    LD	HL, TM_VARS.tm_strt+1
    CALL	tm_pokh
    LD	C,'-'
    CALL	tm_sym_out
    LD	HL, TM_VARS.tm_strt+3
    CALL	tm_pokh
    LD	C,'='
    CALL	tm_sym_out
    LD	HL, TM_VARS.tm_strt+5
    CALL	tm_pokh
    LD	HL, (TM_VARS.tm_strt)
    LD	B,H
    LD	C,L
    LD	HL, (TM_VARS.tm_strt+2)
    LD	D,H
    LD	E,L
    INC	DE
    LD	HL, (TM_VARS.tm_strt+4)

tm_mov_nxt:
    LD	A, (BC)
    LD	(HL), A
    INC	BC
    INC	HL
    LD	A, C
    CP	E
    JP	NZ, tm_mov_nxt
    LD	A, B
    CP	D
    JP	NZ, tm_mov_nxt
    JP	tm_main
tm_dsk_read:
    LD	DE, m_msg_read								;= "Read/"
    JP	tm_ra4
tm_dsk_write:
    LD	DE, m_msg_write								;= "Write/"
tm_ra4:
    LD	(TM_VARS.tm_rw_disk), A
    CALL	tm_print_verh
    CALL	tm_print
tm_ra5:
    CALL	tm_get_key_ctrl_c
    CP	'A'
    JP	C, tm_ra5
    CP	'F'
    JP	NC, tm_ra5
    LD	(TM_VARS.tm_drive), A
    CALL	tm_sym_out
    LD	C, ':'
    CALL	tm_sym_out
    LD	A, (TM_VARS.tm_drive)
    SUB	65
    LD	(TM_VARS.tm_drive), A
    JP	NZ, tm_disk
    LD	DE, tm_msg_0123		      					;= "0123 ?"
    CALL	tm_print
tm_rrr:
    CALL	tm_get_key_ctrl_c
    SUB	48
    CP	4
    JP	NC, tm_rrr
    LD	(TM_VARS.tm_strt+15), A
    JP	tm_main
tm_beeep:
    LD	BC, 0x6060
tm_bell_next_p:
    LD	A,BELL_PIN
    OUT	(DD67PC), A		    						; BELL=1
    LD	A, C
tm_bell_w1:
    DEC	A
    JP	NZ, tm_bell_w1
    OUT	(DD67PC), A		    						; BELL 0
    LD	A, C
tm_bell_w2:
    DEC	A
    JP	NZ, tm_bell_w2
    DEC	B
    JP	NZ, tm_bell_next_p
    RET
tm_msg_0123:
    db	"0123 ?", 0

tm_disk:
    LD	DE, m_msg_track		      					;= "/Track-"
    CALL	tm_print
    CALL	tm_des_dv
    LD	(TM_VARS.tm_track_no), A
    LD	DE, tm_sector								;= "/Sekt-"
    CALL	tm_print
    CALL	tm_des_dv
    LD	(TM_VARS.tm_sector_no), A
    LD	DE, m_msg_num								;= "/N-"
    CALL	tm_print
    CALL	tm_des_dv
    LD	(TM_VARS.tm_num_sect), A
    LD	DE, m_msg_io								;= "/(I/O)-"
    CALL	tm_print
tm_disk_op_unk:
    CALL	tm_get_key_ctrl_c
    CP	'I'
    JP	Z, tm_disk_inp
    CP	'O'
    JP	NZ, tm_disk_op_unk
tm_disk_inp:
    LD	(TM_VARS.tm_disk_op), A
    CALL	tm_sym_out
    CALL	tm_rd_wr_disk
    JP	tm_cont
tm_rd_wr_disk:
    CALL	tm_niz
tm_rd:
    CALL	tm_print_CR
    LD	A, (TM_VARS.tm_track_no)
    LD	D, A
    LD	A, (TM_VARS.tm_sector_no)
    LD	E, A
    LD	A, (TM_VARS.tm_disk_op)
    CP	'O'
    CALL	Z, tm_sect_map
    LD	A, H
    CP	0xac
    JP	NC, tm_error
    LD	BC, 0x84
    LD	A, (TM_VARS.tm_rw_disk)
    CP	'W'
    LD	A, (TM_VARS.tm_drive)
    JP	NZ, tm_d3
    LD	C, 0xa4
    CALL	m_write_floppy
    DEC	L
    JP	tm_d4
tm_d3:
    CALL	m_read_floppy
tm_d4:
    CP	0x0
    JP	NZ, tm_error
    LD	A, (TM_VARS.tm_track_no)
    LD	D, A
    LD	A, (TM_VARS.tm_sector_no)
    INC	A
    CP	10
    JP	C, tm_wf_nx_trk
    INC	D
    LD	A, D
    LD	(TM_VARS.tm_track_no), A
    LD	A, 0x1
tm_wf_nx_trk:
    LD	(TM_VARS.tm_sector_no), A
    LD	E, A
    CALL	tm_print_CR_hexw
    CALL	tm_dv_des
    LD	A, (TM_VARS.tm_num_sect)
    DEC	A
    LD	(TM_VARS.tm_num_sect), A
    JP	NZ, tm_rd
    RET
tm_error:
    PUSH	AF
    LD	DE, m_msg_disk_error		 				;= "Disk Error - "
    CALL	tm_print
    POP	AF
    CALL	tm_hex_b
    LD	BC, 0x70ff
    CALL	tm_bell_next_p
    LD	DE, m_msg_track		     					;= "/Track-"
    CALL	tm_print
    LD	A, (TM_VARS.tm_track_no)
    CALL	tm_dva
    LD	DE, tm_sector								;= "/Sekt-"
    CALL	tm_print
    LD	A, (TM_VARS.tm_sector_no)
    CALL	tm_dva
    LD	DE, m_msg_retr_abrt		  					;= "Retry, Abort -?"
    CALL	tm_print_w_key
    CP	'A'
    JP	Z, tm_main
    JP	tm_rd_wr_disk
tm_dv_des:
    CALL	tm_dv1
    LD	A, E

; ------------------------------------------------------
; Convert to BCD and print?
; ------------------------------------------------------
tm_dva:
    LD	D, A
tm_dv1:
    LD	C, 0
    LD	B, 8
tm_dv2:
    LD	A, D
    RLCA
    LD	D, A
    LD	A, C
    ADC	A, C
    DAA
    LD	C, A
    DEC	B
    JP	NZ, tm_dv2

OFF_ram_fb76:
    JP	tm_hex_b

tm_sec_map_t:
    db	1, 8, 6, 4, 2, 9, 7, 5, 3

; ------------------------------------------------------
;  Map sectors
;  Inp: E - sector
;  Out: E - sector
; ------------------------------------------------------
tm_sect_map:
    LD	BC, tm_sec_map_t-1
    LD	A, E
    ADD	A, C
    LD	C, A
    JP	NC, tm_tbl_noc
    INC	B
tm_tbl_noc:
    LD	A, (BC)
    LD	E, A
    RET
tm_des_dv:
    CALL	SUB_ram_fb9f
    RLCA
    RLCA
    RLCA
    LD	B, A
    RRCA
    RRCA
    ADD	A,B
    LD	B, A
    CALL	SUB_ram_fb9f
    ADD	A,B
    RET
SUB_ram_fb9f:
    CALL	tm_get_key_ctrl_c
    SUB	0x30
    JP	M,SUB_ram_fb9f
    CP	0xa
    JP	P,SUB_ram_fb9f
    PUSH	AF
    CALL	tm_sym_out
    POP	AF
    RET

; ------------------------------------------------------
;  Read data from floppy
;  Inp: A = 0..4 - select drives
;       HL -> buffer
;       C - command (0x84)  READ_SEC, single, 15ms delay
;  Out: A=0 if ok
;       CF is set if error
; ------------------------------------------------------
m_read_floppy:
    CALL	m_select_drive
    CALL	m_start_floppy
    RET	C
    CALL	m_fdc_seek_trk
    RET	C
    CALL	m_fdc_read_c_bytes
    RET	C
    XOR	A
    RET

; ------------------------------------------------------
;  Write data to floppy
;  Inp: A = 0..4 - select drives
;       HL -> buffer
;       C - command (0xA4) WRITE_SEC, single, 15ms delay
;  Out: A=0 if ok
;       CF is set if error
; ------------------------------------------------------
m_write_floppy:
    CALL	m_select_drive
    CALL	m_start_floppy
    RET	C
    CALL	m_fdc_seek_trk
    RET	C
    CALL	m_fdc_write_bytes
    RET	C
    XOR	A
    RET

; ------------------------------------------------------
;  Select or disable drive
;  Inp: A = 0 - disable drives
;       A = 1 - select + drsel + motor0 en
;       A = 2 - select + motor0 enanle
;       A = 3 - select
;       A = 4 - select + drsel
; ------------------------------------------------------
m_select_drive:
    PUSH	BC
    LD	B, 00000111b								; DRSEL, DSEL1, DSEL0
    CP	0x1
    JP	Z, mal_out_to_flop
    LD	B, 00100111b								; MOT0_EN, DRSEL, DSEL1, DSEL0
    CP	0x2
    JP	Z, mal_out_to_flop
    LD	B, 00000011b								; DSEL1, DSEL0
    CP	0x3
    JP	Z, mal_out_to_flop
    LD	B, 00100011b								; MOT0_EN, DSEL1, DSEL0
    CP	0x4
    JP	Z, mal_out_to_flop
    LD	B, 00000000b								; Turn off and deselect drives
mal_out_to_flop:
    LD	A, B
    OUT	(FLOPPY), A
    POP	BC
    RET

; ------------------------------------------------------
;  Start floppy
;  Out:
;     CF is set, A=0x20 if INTRQ
;     CF not set, A=0x00 if READY
; ------------------------------------------------------
m_start_floppy:
    IN	A, (FLOPPY)									; Get floppy ctrl state
    RLCA
    JP	C, .start_motor
    IN	A, (FDC_CMD)
    AND	FDC_NOT_READY
    RET	Z

.start_motor:
    PUSH	BC
    LD	BC, 64000									; timeout
    CALL	m_fdc_set_init

.wait_mot_start:
    IN	A, (FDC_CMD)
    AND	FDC_NOT_READY
    JP	Z, .delay_for_spin_up
    IN	A, (FLOPPY)
	; Check motor start bit
    RLCA
    JP	NC, .wait_mot_start
	; Time is out or not started
    LD	A, 0x20
    JP	.ok_exit
	; Delay for spindle spin-up
.delay_for_spin_up:
    DEC	C
    JP	NZ, .delay_for_spin_up
    DEC	B
    JP	NZ, .delay_for_spin_up
    XOR	A
.ok_exit:
    POP	BC
    RET

; ------------------------------------------------------
; Send INIT to FDC
; ------------------------------------------------------
m_fdc_set_init:
    IN	A, (FLOPPY)
    AND	01001110b									; Read SSEL, DDEN, MOT1, MOT0
    RRA
    OUT	(FLOPPY), A									; SSEL DRSEL MOT1 MOT0
    OR	00001000b									; INIT
    OUT	(FLOPPY), A
    RET

; ------------------------------------------------------
;  Seek track on floppy
;  Inp: DE - track/sector
; ------------------------------------------------------
m_fdc_seek_trk:
    PUSH	BC
    LD	B, 0x2										; try 2 times if error
fs_seek_again:
    LD	A, D
    OUT	(FDC_DATA), A								; Set track to search
    LD	A,FDC_SEEK_LV								; Seek, Load Head, Verify on dst track
    OUT	(FDC_CMD), A
    NOP
    NOP
    IN	A, (FDC_WAIT)
    IN	A, (FDC_CMD)
    AND	00011001b									; SEEK error, CRC error, BUSY flags
    CP	0x0
    JP	Z, fs_seek_ok
    LD	A, 0x20
    SCF												; set erro flag
    DEC	B
    JP	Z, fs_seek_ok
    LD	A, FDC_RESTORE_L							; restore with load head
    OUT	(FDC_CMD), A
    NOP
    NOP
    IN	A, (FDC_WAIT)
    JP	fs_seek_again
fs_seek_ok:
    PUSH	AF
    LD	A, E
    OUT	(FDC_SECT), A
    POP	AF
    POP	BC
    RET

; ------------------------------------------------------
;  Write bytes to FDC
;  Inp: C - count of bytes
;       HL -> buffer
;  Out: CF set if error,
;       C - error code if CF is set
; ------------------------------------------------------
m_fdc_write_bytes:
    LD	A, C
    OUT	(FDC_CMD), A
fw_next_byte:
    IN	A, (FDC_WAIT)
    RRCA
    LD	A, (HL)
    OUT	(FDC_DATA), A
    INC	HL
    JP	C,fw_next_byte
    JP	m_floppy_chk_error

; ------------------------------------------------------
;  Read bytes from FDC
;  Inp: C - command code for VG93
;       HL -> buffer
;  Out: CF set if error,
;       C - error code if CF is set
; ------------------------------------------------------
m_fdc_read_c_bytes:
    LD	A, C
    OUT	(FDC_CMD), A
    JP	.skip_first_inc
.read_next_byte:
    LD	(HL), A
    INC	HL
.skip_first_inc:
    IN	A, (FDC_WAIT)
    RRCA
    IN	A, (FDC_DATA)
    JP	C, .read_next_byte

m_floppy_chk_error:
    IN	A, (FDC_CMD)
    AND	11011111b									; mask 5th bit Write fault... ???
    CP	0x0
    RET	Z											; retutn in no errors
    IN	A, (FDC_CMD)
    LD	C, A
    SCF
    RET

m_msg_disk_error:
    db	"Disk Error - ", 0

m_msg_retr_abrt:
    db	"Retry, Abort -?", 0

m_msg_read:
    db	"Read/", 0

m_msg_write:
    db	"Write/", 0

m_msg_track:
    db	"/Track-", 0

tm_sector:
    db	"/Sekt-", 0

m_msg_num:
    db	"/N-", 0

m_msg_b_ok:
    db	" {OK}", 0

m_msg_io:
    db	"/(I/O)-", 0

esc_cmd_kod:
    db	ASCII_ESC, '@', ASCII_ESC, 'R', 3, ESC_CMD_END

tm_fill:
    LD	C, (HL)
    LD	A, 0xb0
.fill_nxt1:
    LD	(HL), C
    INC	HL
    CP	H
    JP	NZ, .fill_nxt1
    JP	tm_mon
tm_fill_nxt2:
    LD	C, (HL)
.fill_nxt3:
    LD	(HL), C
    INC	L
    JP	NZ, .fill_nxt3
    JP	tm_mon
    EX	DE, HL
    CALL	tm_hex_hl
    EX	DE, HL
    RET

; ------------------------------------------------------
;  Print word as hex
;  Inp: HL - value to print
; ------------------------------------------------------
tm_hex_hl:
    LD	A, H
    CALL	tm_hex_b
    LD	A, L

; ------------------------------------------------------
;  Print byte in HEX
;  Inp: A - Byte to print
; ------------------------------------------------------
tm_hex_b:
    PUSH	AF
    AND	0xf0
    RRCA
    RRCA
    RRCA
    RRCA
    CALL	tm_print_hex_nibble
    POP	AF
    PUSH	AF
    AND	0xf
    CALL	tm_print_hex_nibble
    POP	AF
    RET

tm_print_hex_nibble:
    PUSH	DE
    LD	DE,msg_digits								;= "0123456789ABCDEF"
    ADD	A, E
    JP	NC, .no_cf
    INC	D
.no_cf:
    LD	E, A
    LD	A, (DE)
    LD	C, A
    CALL	tm_sym_out
    POP	DE
    RET

msg_digits:
    db	"0123456789ABCDEF", 0

tm_print_LFCR_hexw:
    LD	C, ASCII_LF
    CALL	tm_sym_out

tm_print_CR_hexw:
    CALL	tm_print_CR
    CALL	tm_hex_hl

tm_print_SP:
    LD	C, ' '
    JP	tm_sym_out

tm_print_LFCR:
    LD	C, ASCII_LF
    CALL	tm_sym_out

tm_print_CR:
    LD	C, ASCII_CR
    JP	tm_sym_out

; ------------------------------------------------------
;  Get key from keyboard. Return to monitor
;  if Ctrl+C pressed
;  Out: C=A - key
; ------------------------------------------------------
tm_get_key_ctrl_c:
    CALL	tm_con_in
    LD	C, A
    CP	0x3
    JP	Z, tm_main
    RET

; TYPE
tm_print_t:
    LD	C, ASCII_US
    CALL	tm_sym_out
    EX	DE, HL
    CALL	tm_print
tm_cont:
    LD	DE, m_msg_b_ok								;= " {OK}"
    CALL	tm_print_w_key
    JP	tm_main

; ------------------------------------------------------
;  Print message and wait key
;  Ctrl+C to cansel current op and
;  return to monitor
;  Inp: DE -> strz
;  Out: A - key
; ------------------------------------------------------
tm_print_w_key:
    CALL	tm_out_strz
    JP	tm_get_key_ctrl_c

tm_out_strz:
    CALL	tm_print_LFCR
tm_print:
    LD	B,16
p11_print_next:
    LD	A, (DE)
    OR	A
    RET	Z
    CP	ASCII_CR
    JP	NZ, p11_no_CR
    DEC	B
    JP	NZ, p11_no_CR
    CALL	tm_get_key_ctrl_c
    LD	B, 16
    LD	A, (DE)
p11_no_CR:
    LD	C, A
    CALL	tm_sym_out
    INC	DE
    JP	p11_print_next

; ------------------------------------------------------
;  Out symbol
;  Inp: C - symbol
; ------------------------------------------------------
tm_sym_out:
    LD	A, C
    AND	0x80
    JP	Z, tm_rus
    LD	A, 0x1

tm_rus:
    LD	(TM_VARS.m_codepage), A
    CALL	m_con_out
    LD	A, (TM_VARS.tm_ltb+1)						; if 0x10, return, no out to printer;
    CP	0x10
    RET	NZ
    JP	tm_char_print

; ------------------------------------------------------
; Print FS (FileSeparator)
; ------------------------------------------------------
tm_print_verh:
    LD	C, 0xc
    JP	tm_sym_out
tm_screen:
    CALL	tm_print_verh
    LD	A, D
    OR	A
tm_scr0:
    JP	Z,tm_scr1
    LD	C, ASCII_LF
    CALL	tm_sym_out
    DEC	D
    JP	tm_scr0

; ------------------------------------------------------
; Print CAN symbol E times
; ------------------------------------------------------
tm_scr1:
    LD	A, E
    OR	A
    RET	Z
    LD	C, ASCII_CAN								; CAN (Cancel)
    CALL	tm_sym_out
    DEC	E
    JP	tm_scr1

tm_niz:
    LD	DE, 0x1500									; 21 x 0
    CALL	tm_screen
    LD	DE, 0x7f20									; 126 x ' '
    CALL	tm_rpt_print
    LD	DE, 0x1500									; 21 x 0
    JP	tm_screen

; ------------------------------------------------------
;  Print the character the specified number of times
;  Inp: E - character
;       D - count
; ------------------------------------------------------
tm_rpt_print:
    LD	C, E										; DE=363D
rpt_next:
    CALL	tm_sym_out
    DEC	D
    RET	Z
    JP	rpt_next

; Turn on duplicate output to printer
tm_ltab:
    LD	A,10h
    LD	(TM_VARS.tm_ltb), A
    JP	tm_mon

tm_lps:
    LD	A, (TM_VARS.tm_ltb)
    CP	0x10
    RET	NZ
    LD	(TM_VARS.tm_ltb+1), A
    LD	DE,esc_cmd_kod								;= 1Bh
    JP	tm_lprint

tm_lpr:
    XOR	A
    LD	(TM_VARS.tm_ltb), A
    LD	(TM_VARS.tm_ltb+1), A
    RET

tm_lprn:
    EX	DE, HL
    CALL	tm_lprint
    JP	tm_mon

; ------------------------------------------------------
;  Print string until SUB symbol
;  Inp: DE -> string ended with SUB (0x1A)
; ------------------------------------------------------
tm_lprint:
    LD	A, (DE)
    LD	C, A
    CP	ASCII_SUB
    RET	Z
    CALL	tm_char_print
    INC	DE
    JP	tm_lprint

; ------------------------------------------------------
;  Send character to printer
;  Inp: C - character
; ------------------------------------------------------
tm_char_print:
    IN	A, (PIC_DD75RS)
    AND	PRINTER_IRQ
    JP	Z, tm_char_print							; Wait printer ready
cp_wait_ack:
    IN	A, (KBD_DD78PB)
    AND	PRINTER_ACK
    JP	NZ, cp_wait_ack
    LD	A, C
    CPL
    OUT	(LPT_DD67PA), A
    LD	A, 00001001b								; set Printer Strobe (port C 4th bit)
    OUT	(DD67CTR), A
    LD	A, 00001000b								; reset Printer Strobe
    OUT	(DD67CTR), A
    RET

; ------------------------------------------------------
;  Wait and read data from UART
;  Out: A - 7 bit data
; ------------------------------------------------------
m_serial_in:
    IN	A, (UART_DD72RR)
    AND	RX_READY
    JP	Z, m_serial_in								; wait for rx data ready
    IN	A, (UART_DD72RD)
    AND	0x7f										; leave 7 bits
    RET

; ------------------------------------------------------
;  Send data by UART
;  Inp: C - data to transmitt
; ------------------------------------------------------
m_serial_out:
    IN	A, (UART_DD72RR)
    AND	TX_READY
    JP	Z, m_serial_out								; Wait for TX ready
    LD	A, C
	OUT	(UART_DD72RD), A
    RET
tm_plus:
    LD	HL, (TM_VARS.tm_hrg)
    INC	H
    JP	tm_ff
tm_minus:
    LD	HL, (TM_VARS.tm_hrg)
    DEC	H
    JP	tm_ff
tm_f1:
    LD	H, 0x1
    JP	tm_ff
tm_f2:
    LD	H, 0x40
    JP	tm_ff
tm_f3:
    LD	H, 0xb0
    JP	tm_ff
tm_ff:
    XOR	A
    LD	L, A
    LD	(TM_VARS.tm_hrg), HL
    JP	tm_mon
tm_f4:
    LD	A,H
    ADD	A, 0x10
    JP	tm_fa
tm_f5:
    LD	A,H
    SUB	0x10
tm_fa:
    LD	H, A
    JP	tm_ff

tm_msg_search:
    db	"\fSEARCH [", 0

tm_search:
    LD	(TM_VARS.tm_hrg), HL
tm_search0:
    LD	DE, tm_msg_search							;= "\fSEARCH ["
    CALL	tm_print
    LD	HL, TM_VARS.tm_stack
tm_s0:
    LD	B, 0x1
tm_s1:
    CALL	tm_get_key_ctrl_c
    CP	ASCII_BS
    JP	Z, tm_search0
    CP	ASCII_CR
    JP	Z, tm_do_search
    CP	'*'
    JP	Z, tm_s4
    LD	A, (TM_VARS.tm_tbu)
    CP	ASCII_TAB
    JP	NZ, tm_s2
tm_s4:
    LD	(HL), C
    CALL	tm_sym_out
    JP	tm_s5
tm_s2:
    LD	A, C
    CALL	tm_poke
    LD	A, B
    OR	A
    JP	NZ, tm_s1
tm_s5:
    INC	L
    JP	tm_s0

tm_do_search:
    LD	B,L
    LD	D,H
    XOR	A
    LD	E, A
    LD	HL, (TM_VARS.tm_hrg)
    INC	HL
    ADD	A,B
    JP	Z, tm_sea1
    LD	(TM_VARS.tm_stack+16), A
tm_sea1:
    LD	A, (DE)
    CP	(HL)
    JP	NZ, tm_s3
tm_s6:
    DEC	B
    JP	Z, tm_aga
    INC	E
tm_sea2:
    INC	L
    JP	NZ, tm_sea1
    INC	H
    JP	NZ, tm_sea1
    JP	tm_main
tm_s3:
    LD	A, (DE)
    CP	'*'
    JP	Z, tm_s6
    LD	A, (TM_VARS.tm_stack+16)
    LD	B, A
    LD	E, 0x0
    JP	tm_sea2

tm_aga:
    LD	A, (TM_VARS.tm_stack+16)

tm_ogo:
    DEC	A
    JP	Z,tm_rets
    DEC	HL
    JP	tm_ogo

tm_rets:
    LD	(TM_VARS.tm_hrg), HL
    JP	tm_main

m_print_log_sep:
    LD	C, ASCII_US
    CALL	tm_sym_out
    JP	EXT_RAM.JP_WBOOT

m_msg_contacts:
    db	"       (Chernogolovka Mosk.reg.  Tel 51-24)", 0

LAST        EQU     $
CODE_SIZE   EQU     LAST-0xE000
FILL_SIZE   EQU     8192-CODE_SIZE

    DISPLAY "Code size is: ",/A,CODE_SIZE

FILLER
    DS  FILL_SIZE, 0xFF
    DISPLAY "Filler size is: ",/A,FILL_SIZE

	ENDMODULE

	OUTEND

	OUTPUT tm_vars.bin
		; put in separate waste file
		INCLUDE "tm_vars.inc"
	OUTEND
