; ======================================================
; Ocean-240.2
; CP/M CCP Resident part
; ORG C000 at RPM, moved to B200-BA09
;
; Disassembled by Romych 2025-09-09
; ======================================================

	INCLUDE	"io.inc"
	INCLUDE "equates.inc"
	INCLUDE "external_ram.inc"

	IFNDEF	BUILD_ROM
		OUTPUT ccp_ram.bin
	ENDIF

	MODULE	CCP_RAM

	ORG	0xB200

CCP_RAM_ENT:
    JP	LAB_ram_b55c
    JP	SUB_ram_b558
BYTE_ram_b206:
    db	7Fh
BYTE_ram_b207:
    db	0h

ccp_fname_addr:
    dw	2020h

MSG_COPYRIGHT:
    db "              COPYRIGHT (C) 1979, DIGITAL RESEARCH  ", 0x00
    ds 73, 0x0

ccp_name_addr:
    dw	ccp_fname_addr

WORD_ram_b28a:
    dw	0h

; ---------------------------------------------------
; Call BDOS function 2 (C_WRITE) - Console output
; Inp: A - char to output
; ---------------------------------------------------
ccp_bdos_c_write:
    LD	E, A
    LD	C, 2
    JP	EXT_RAM.jp_bdos_enter

; ---------------------------------------------------
; Put char to console
; Inp: A - char
; ---------------------------------------------------
ccp_putc:

    PUSH	BC
    CALL	ccp_bdos_c_write
    POP	 BC
    RET

ccp_out_crlf:
    LD	A, ASCII_CR
    CALL	ccp_putc
    LD	A, ASCII_LF
    JP	ccp_putc
ccp_out_space:
    LD	A,' '
    JP	ccp_putc

; ---------------------------------------------------
; Out message from new line
; Inp: BC -> Message
; ---------------------------------------------------
ccp_out_crlf_msg:

    PUSH	BC
    CALL	ccp_out_crlf
    POP	 HL
ccp_mse_next:
    LD	A, (HL)										;= "READ ERROR"
    OR	A
    RET	 Z
    INC	 HL
    PUSH	HL
    CALL	ccp_bdos_c_write
    POP	 HL
    JP	ccp_mse_next

; ---------------------------------------------------
; Call BDOS function 13 (DRV_ALLRESET) - Reset discs
; ---------------------------------------------------
ccp_bdos_drv_allreset:
    LD	C,13
    JP	EXT_RAM.jp_bdos_enter

; ---------------------------------------------------
; Call BDOS function 14 (DRV_SET) - Select disc
; ---------------------------------------------------
ccp_bdos_drv_set:
    LD	E, A
    LD	C,14
    JP	EXT_RAM.jp_bdos_enter

; ---------------------------------------------------
; Call BDOS fn and return result
; Inp: C - fn no
; Out: A - error + 1
; ---------------------------------------------------
ccp_call_bdos:
    CALL	EXT_RAM.jp_bdos_enter
    LD	(ccp_bdos_call_result), A
    INC	 A
    RET

; ---------------------------------------------------
; BDOS function 15 (F_OPEN) - Open file /Dir
; In: DE -> FCB
; ---------------------------------------------------
ccp_bdos_call_open:
    LD	C,15
    JP	ccp_call_bdos

; ---------------------------------------------------
; Open file
; Ret: A=0 for error, or 1-4 for success
; ---------------------------------------------------
ccp_open_f:
    XOR	 A
    LD	(ccp_cmd_line_buff+31), A
    LD	DE, ccp_current_fcb
    JP	ccp_bdos_call_open

; ---------------------------------------------------
; BDOS function 16 (F_CLOSE) - Close file
; ---------------------------------------------------
ccp_bdos_close_f:
    LD	C,16
    JP	ccp_call_bdos

; ---------------------------------------------------
; Call BDOS function 17 (F_SFIRST) - search for first
; Out: A = 0 in error, 1-4 if success
; ---------------------------------------------------
ccp_bdos_find_first:
    LD	C,17
    JP	ccp_call_bdos

; ---------------------------------------------------
; Call BDOS function 18 (F_SNEXT) - search for next
; Out: A = 0 in error, 1-4 if success
; ---------------------------------------------------
ccp_bdos_find_next:
    LD	C,18
    JP	ccp_call_bdos		       ; BDOS 18 (F_SNEXT) - search for next ?

; ---------------------------------------------------
; Call BDOS F_FIRST with current FCB
; ---------------------------------------------------
ccp_find_first:
    LD	DE, ccp_current_fcb
    JP	ccp_bdos_find_first

; ---------------------------------------------------
; Call BDOS function 19 (F_DELETE) - delete file
; ---------------------------------------------------
ccp_bdos_delete:
    LD	C,19
    JP	EXT_RAM.jp_bdos_enter
ccp_bdos_enter_or:
    CALL	EXT_RAM.jp_bdos_enter
    OR	A
    RET

; ---------------------------------------------------
; Read next 128 bytes of file
; Inp: DE -> FCB
; Out: a = 0 - ok;
; 1 - EOF;
; 9 - invalid FCB;
; 10 - Media changed;
; 0xFF - HW error.
; ---------------------------------------------------
ccp_bdos_read_f:
    LD	C, 20
    JP	ccp_bdos_enter_or
SUB_ram_b2fe:
    LD	DE, ccp_current_fcb
    JP	ccp_bdos_read_f

; ---------------------------------------------------
; Call BDOS function 21 (F_WRITE) - write next record
; ---------------------------------------------------
ccp_bdos_f_write:
    LD	C, 21
    JP	ccp_bdos_enter_or

; ---------------------------------------------------
; Call BDOS function 22 (F_MAKE) - create file
; ---------------------------------------------------
ccp_bdos_create_f:
    LD	C, 22
    JP	ccp_call_bdos

; ---------------------------------------------------
; Call BDOS function 23 (F_RENAME) - Rename file
; ---------------------------------------------------
ccp_bdos_rename_f:
    LD	C, 23
    JP	EXT_RAM.jp_bdos_enter

ccp_bdos_get_user:
    LD	E, 0xff

; ---------------------------------------------------
; Call BDOS function 32 (F_USERNUM) - get/set user number
; Inp: A - user no
; ---------------------------------------------------
ccp_bdos_set_user:
    LD	C, 32
    JP	EXT_RAM.jp_bdos_enter
SUB_ram_b31a:
    CALL	ccp_bdos_get_user
    ADD	 A, A
    ADD	 A, A
    ADD	 A, A
    ADD	 A, A
    LD	HL, ccp_new_drive
    OR	(HL)
    LD	(EXT_RAM.cur_user_no), A
    RET
SUB_ram_b329:
    LD	A, (ccp_new_drive)
    LD	(EXT_RAM.cur_user_no), A
    RET
SUB_ram_b330:
    CP	'a'
    RET	 C
    CP	'{'
    RET	 NC
    AND	 '_'
    RET
SUB_ram_b339:
    LD	A, (tmp_ccp_stack)
    OR	A
    JP	Z, LAB_ram_b396
    LD	A, (ccp_new_drive)
    OR	A
    LD	A, 0x0
    CALL	NZ, ccp_bdos_drv_set
    LD	DE, BYTE_ram_b9ac
    CALL	ccp_bdos_call_open
    JP	Z, LAB_ram_b396
    LD	A, (BYTE_ram_b9bb)
    DEC	 A
    LD	(BYTE_ram_b9cc), A
    LD	DE, BYTE_ram_b9ac
    CALL	ccp_bdos_read_f
    JP	NZ, LAB_ram_b396
    LD	DE, BYTE_ram_b207
    LD	HL, 0x80
    LD	B, 0x80
    CALL	SUB_ram_b642
    LD	HL, BYTE_ram_b9ba
    LD	(HL), 0x0
    INC	 HL
    DEC	 (HL)
    LD	DE, BYTE_ram_b9ac
    CALL	ccp_bdos_close_f
    JP	Z, LAB_ram_b396
    LD	A, (ccp_new_drive)
    OR	A
    CALL	NZ, ccp_bdos_drv_set
    LD	HL, ccp_fname_addr		   ;= 2020h
    CALL	ccp_mse_next
    CALL	ccp_getkey_no_wait
    JP	Z, LAB_ram_b3a7
    CALL	SUB_ram_b3dd
    JP	LAB_ram_b582
LAB_ram_b396:
    CALL	SUB_ram_b3dd
    CALL	SUB_ram_b31a
    LD	C,10
    LD	DE, BYTE_ram_b206		    ;= 7Fh

; Call BDOS C_READSTR DE -> inp buffer
    CALL	EXT_RAM.jp_bdos_enter
    CALL	SUB_ram_b329
LAB_ram_b3a7:
    LD	HL, BYTE_ram_b207
    LD	B, (HL)
LAB_ram_b3ab:
    INC	 HL
    LD	A, B
    OR	A
    JP	Z, LAB_ram_b3ba

    LD	A, (HL)		;= 2020h
    CALL	SUB_ram_b330
    LD	(HL), A		;= 2020h
    DEC	 B
    JP	LAB_ram_b3ab
LAB_ram_b3ba:
    LD	(HL), A
    LD	HL, ccp_fname_addr		   ;= 2020h
    LD	(ccp_name_addr), HL		  ;= B208h
    RET
ccp_getkey_no_wait:

    LD	C,11
	; Call BDOS (C_STAT) - Console status
    CALL	EXT_RAM.jp_bdos_enter
    OR	A
    RET	 Z				 ; ret if no character waiting
    LD	C,1
	; Call BDOS (C_READ) - Console input
    CALL	EXT_RAM.jp_bdos_enter
    OR	A
    RET

; ---------------------------------------------------
; Call BDOS function 25 (DRV_GET) - Return current drive
; Out: A - drive 0-A, 1-B...
; ---------------------------------------------------
ccp_bdos_drv_get:
    LD	C, 25
    JP	EXT_RAM.jp_bdos_enter

; ---------------------------------------------------
; Set DMA address to default buffer
; ---------------------------------------------------
ccp_set_dma_std_addr:

    LD	DE, EXT_RAM.std_dma_buff

; ---------------------------------------------------
; Call BDOS function 26 (F_DMAOFF) - Set DMA address
; Inp: DE - address
; ---------------------------------------------------
ccp_bdos_dma_set:
    LD	C, 26
    JP	EXT_RAM.jp_bdos_enter
SUB_ram_b3dd:
    LD	HL,tmp_ccp_stack
    LD	A, (HL)
    OR	A
    RET	 Z
    LD	(HL), 0x0
    XOR	 A
    CALL	ccp_bdos_drv_set
    LD	DE, BYTE_ram_b9ac
    CALL	ccp_bdos_delete
    LD	A, (ccp_new_drive)
    JP	ccp_bdos_drv_set
SUB_ram_b3f5:
    LD	DE, BYTE_ram_b528		    ;= F9h
    LD	HL, 0x0
    LD	B, 0x6
LAB_ram_b3fd:

    LD	A, (DE)		 ;= F9h
					      ;= 16h
    CP	(HL)
    NOP
    NOP
    NOP
    INC	 DE
    INC	 HL
    DEC	 B
    JP	NZ, LAB_ram_b3fd
    RET
SUB_ram_b409:
    CALL	ccp_out_crlf
    LD	HL, (WORD_ram_b28a)
LAB_ram_b40f:
    LD	A, (HL)
    CP	0x20
    JP	Z, LAB_ram_b422
    OR	A
    JP	Z, LAB_ram_b422
    PUSH	HL

    CALL	ccp_bdos_c_write
    POP	 HL
    INC	 HL
    JP	LAB_ram_b40f
LAB_ram_b422:
    LD	A, 0x3f

    CALL	ccp_bdos_c_write

    CALL	ccp_out_crlf

    CALL	SUB_ram_b3dd
    JP	LAB_ram_b582
SUB_ram_b430:
    LD	A, (DE)
    OR	A
    RET	 Z
    CP	' '
    JP	C, SUB_ram_b409
    RET	 Z
    CP	'='
    RET	 Z
    CP	'_'
    RET	 Z
    CP	'.'
    RET	 Z
    CP	':'
    RET	 Z
    CP	';'
    RET	 Z
    CP	'<'
    RET	 Z
    CP	'>'
    RET	 Z
    RET
ccp_find_nxt_par:
    LD	A, (DE)
    OR	A
    RET	 Z
    CP	0x20
    RET	 NZ
    INC	 DE
    JP	ccp_find_nxt_par

; ---------------------------------------------------
; HL=HL+A
; ---------------------------------------------------
sum_hl_a:
    ADD	 A, L
    LD	L, A
    RET	 NC
    INC	 H
    RET
ccp_get_parameter:



    LD	A, 0x0
SUB_ram_b460:
    LD	HL, ccp_current_fcb
    CALL	sum_hl_a
    PUSH	HL
    PUSH	HL
    XOR	 A
    LD	(ccp_cur_drive), A
    LD	HL, (ccp_name_addr)		  ;= B208h
    EX	DE, HL
    CALL	ccp_find_nxt_par
    EX	DE, HL
    LD	(WORD_ram_b28a), HL
    EX	DE, HL
    POP	 HL
    LD	A, (DE)		;= 2020h
    OR	A
    JP	Z, LAB_ram_b489
    SBC	 A, 0x40			    ; @
    LD	B, A
    INC	 DE
    LD	A, (DE)
    CP	0x3a			      ; :
    JP	Z, LAB_ram_b490
    DEC	 DE
LAB_ram_b489:
    LD	A, (ccp_new_drive)
    LD	(HL), A
    JP	LAB_ram_b496
LAB_ram_b490:
    LD	A, B
    LD	(ccp_cur_drive), A
    LD	(HL), B
    INC	 DE
LAB_ram_b496:
    LD	B, 0x8
LAB_ram_b498:
    CALL	SUB_ram_b430
    JP	Z, LAB_ram_b4b9
    INC	 HL
    CP	0x2a
    JP	NZ, LAB_ram_b4a9

    LD	(HL), 0x3f
    JP	LAB_ram_b4ab
LAB_ram_b4a9:
    LD	(HL), A
    INC	 DE
LAB_ram_b4ab:
    DEC	 B
    JP	NZ, LAB_ram_b498
LAB_ram_b4af:
    CALL	SUB_ram_b430
    JP	Z, LAB_ram_b4c0
    INC	 DE
    JP	LAB_ram_b4af
LAB_ram_b4b9:
    INC	 HL

    LD	(HL), 0x20
    DEC	 B
    JP	NZ, LAB_ram_b4b9
LAB_ram_b4c0:
    LD	B, 0x3
    CP	0x2e
    JP	NZ, LAB_ram_b4e9
    INC	 DE
LAB_ram_b4c8:
    CALL	SUB_ram_b430
    JP	Z, LAB_ram_b4e9
    INC	 HL
    CP	0x2a
    JP	NZ, LAB_ram_b4d9

    LD	(HL), 0x3f
    JP	LAB_ram_b4db
LAB_ram_b4d9:
    LD	(HL), A
    INC	 DE
LAB_ram_b4db:
    DEC	 B
    JP	NZ, LAB_ram_b4c8
LAB_ram_b4df:
    CALL	SUB_ram_b430
    JP	Z, LAB_ram_b4f0
    INC	 DE
    JP	LAB_ram_b4df
LAB_ram_b4e9:
    INC	 HL

    LD	(HL), 0x20
    DEC	 B
    JP	NZ, LAB_ram_b4e9
LAB_ram_b4f0:
    LD	B, 0x3
LAB_ram_b4f2:
    INC	 HL

    LD	(HL), 0x0
    DEC	 B
    JP	NZ, LAB_ram_b4f2
    EX	DE, HL
    LD	(ccp_name_addr), HL		  ;= B208h
    POP	 HL
    LD	BC, 0xb
LAB_ram_b501:
    INC	 HL

    LD	A, (HL)
    CP	0x3f
    JP	NZ, LAB_ram_b509
    INC	 B
LAB_ram_b509:
    DEC	 C
    JP	NZ, LAB_ram_b501
    LD	A, B
    OR	A
    RET

cpm_cmd_str:
    db	'$DIRERA TYPESAVEREN USER'

BYTE_ram_b528:
    db	0xF9
BYTE_ram_b529:
    db	0x16, 0, 0, 0, 0x6B

SUB_ram_b52e:
    LD	HL, cpm_cmd_str		     					;= '$'
    LD	C, 0x0

LAB_ram_b533:
    LD	A, C
    CP	0x6
    RET	 NC
    LD	DE, ccp_cmd_line_buff
    LD	B, 0x4
LAB_ram_b53c:
    LD	A, (DE)
    CP	(HL)		  								;= '$'
    JP	NZ, LAB_ram_b54f
    INC	 DE
    INC	 HL
    DEC	 B
    JP	NZ, LAB_ram_b53c
    LD	A, (DE)
    CP	0x20
    JP	NZ, LAB_ram_b554
    LD	A, C
    RET
LAB_ram_b54f:
    INC	 HL
    DEC	 B
    JP	NZ, LAB_ram_b54f
LAB_ram_b554:
    INC	 C
    JP	LAB_ram_b533
SUB_ram_b558:
    XOR	 A
    LD	(BYTE_ram_b207), A

LAB_ram_b55c:
    LD	SP,tmp_ccp_stack
    PUSH	BC; =tmp_ccp_stack_1
    LD	A, C
    RRA
    RRA
    RRA
    RRA
    AND	 0xf
    LD	E, A
    CALL	ccp_bdos_set_user
    CALL	ccp_bdos_drv_allreset
    LD	(tmp_ccp_stack), A
    POP	 BC											; =tmp_ccp_stack_1
    LD	A, C
    AND	 0xf
    LD	(ccp_new_drive), A
    CALL	ccp_bdos_drv_set
    LD	A, (BYTE_ram_b207)
    OR	A
    JP	NZ, LAB_ram_b598

LAB_ram_b582:
    LD	SP,tmp_ccp_stack
    CALL	ccp_out_crlf
    CALL	ccp_bdos_drv_get
    ADD	 A, 0x41
    CALL	ccp_bdos_c_write
    LD	A, 0x3e
    CALL	ccp_bdos_c_write
    CALL	SUB_ram_b339

LAB_ram_b598:
    LD	DE, 0x80
    CALL	ccp_bdos_dma_set
    CALL	ccp_bdos_drv_get
    LD	(ccp_new_drive), A
    CALL	ccp_get_parameter
    CALL	NZ, SUB_ram_b409
    LD	A, (ccp_cur_drive)
    OR	A
    JP	NZ, ccp_ret_func
    CALL	SUB_ram_b52e
    LD	HL, LAB_ram_b5c1
    LD	E, A
    LD	D, 0x0
    ADD	 HL, DE
    ADD	 HL, DE
    LD	A, (HL)
    INC	 HL
    LD	H, (HL)
    LD	L, A
    JP	(HL)

LAB_ram_b5c1:
    LD	(HL), A
    OR	(HL)
    RRA
    OR	A
    LD	E, L
    OR	A
    XOR	 L
    OR	A
    DJNZ	LAB_ram_b582+1
    ADC	 A, (HL)
    CP	B
    NOP
    IN	A, (FDC_TRACK)		 						;= FDC tracks count
    DI
    HALT
    LD	(CCP_RAM_ENT), HL
    LD	HL, CCP_RAM_ENT
    JP	(HL)

ccp_out_rd_erro:
    LD	BC,msg_read_error		   					;= "READ ERROR"
    JP	ccp_out_crlf_msg

msg_read_error:
    db	"READ ERROR", 0x00

; ---------------------------------------------------
; Out message 'NO FILE'
; ---------------------------------------------------
ccp_out_no_file:
    LD	BC,msg_no_file		      					;= "NO FILE"
    JP	ccp_out_crlf_msg
msg_no_file:
    db	"NO FILE", 0x00
SUB_ram_b5f8:
    CALL	ccp_get_parameter
    LD	A, (ccp_cur_drive)
    OR	A
    JP	NZ, SUB_ram_b409
    LD	HL, ccp_cmd_line_buff
    LD	BC, 0xb
LAB_ram_b608:
    LD	A, (HL)
    CP	0x20
    JP	Z, LAB_ram_b633
    INC	 HL
    SUB	 0x30
    CP	0xa
    JP	NC, SUB_ram_b409
    LD	D, A
    LD	A, B
    AND	 0xe0
    JP	NZ, SUB_ram_b409
    LD	A, B
    RLCA
    RLCA
    RLCA
    ADD	 A, B
    JP	C, SUB_ram_b409
    ADD	 A, B
    JP	C, SUB_ram_b409
    ADD	 A, D
    JP	C, SUB_ram_b409
    LD	B, A
    DEC	 C
    JP	NZ, LAB_ram_b608
    RET
LAB_ram_b633:
    LD	A, (HL)
    CP	0x20
    JP	NZ, SUB_ram_b409
    INC	 HL
    DEC	 C
    JP	NZ, LAB_ram_b633
    LD	A, B
    RET
SUB_ram_b640:
    LD	B, 0x3
SUB_ram_b642:
    LD	A, (HL)
    LD	(DE), A
    INC	 HL
    INC	 DE
    DEC	 B
    JP	NZ, SUB_ram_b642
    RET
SUB_ram_b64b:
    LD	HL, 0x80
    ADD	 A, C
    CALL	sum_hl_a
    LD	A, (HL)
    RET
ccp_drive_sel:
    XOR	 A
    LD	(ccp_current_fcb), A
    LD	A, (ccp_cur_drive)
    OR	A
    RET	 Z
    DEC	 A
    LD	HL, ccp_new_drive
    CP	(HL)
    RET	 Z
    JP	ccp_bdos_drv_set
SUB_ram_b666:
    LD	A, (ccp_cur_drive)
    OR	A
    RET	 Z
    DEC	 A
    LD	HL, ccp_new_drive
    CP	(HL)
    RET	 Z
    LD	A, (ccp_new_drive)
    JP	ccp_bdos_drv_set
    CALL	ccp_get_parameter
    CALL	ccp_drive_sel
    LD	HL, ccp_cmd_line_buff
    LD	A, (HL)
    CP	0x20
    JP	NZ, LAB_ram_b68f
    LD	B, 0xb
LAB_ram_b688:
    LD	(HL), 0x3f
    INC	 HL
    DEC	 B
    JP	NZ, LAB_ram_b688
LAB_ram_b68f:
    LD	E, 0x0
    PUSH	DE
    CALL	ccp_find_first
    CALL	Z, ccp_out_no_file
LAB_ram_b698:
    JP	Z, LAB_ram_b71b
    LD	A, (ccp_bdos_call_result)
    RRCA
    RRCA
    RRCA
    AND	 0x60
    LD	C, A
    LD	A, 0xa
    CALL	SUB_ram_b64b
    RLA
    JP	C, LAB_ram_b70f
    POP	 DE
    LD	A, E
    INC	 E
    PUSH	DE
    AND	 0x3
    PUSH	AF
    JP	NZ, LAB_ram_b6cc
    CALL	ccp_out_crlf
    PUSH	BC
    CALL	ccp_bdos_drv_get
    POP	 BC
    ADD	 A, 0x41
    CALL	ccp_putc
    LD	A, 0x3a
    CALL	ccp_putc
    JP	LAB_ram_b6d4
LAB_ram_b6cc:
    CALL	ccp_out_space
    LD	A, 0x3a
    CALL	ccp_putc
LAB_ram_b6d4:
    CALL	ccp_out_space
    LD	B, 0x1
LAB_ram_b6d9:
    LD	A, B
    CALL	SUB_ram_b64b
    AND	 0x7f
    CP	0x20
    JP	NZ, LAB_ram_b6f9
    POP	 AF
    PUSH	AF
    CP	0x3
    JP	NZ, LAB_ram_b6f7
    LD	A, 0x9
    CALL	SUB_ram_b64b
    AND	 0x7f
    CP	0x20
    JP	Z, LAB_ram_b70e
LAB_ram_b6f7:
    LD	A, 0x20
LAB_ram_b6f9:
    CALL	ccp_putc
    INC	 B
    LD	A, B
    CP	0xc
    JP	NC, LAB_ram_b70e
    CP	0x9
    JP	NZ, LAB_ram_b6d9
    CALL	ccp_out_space
    JP	LAB_ram_b6d9
LAB_ram_b70e:
    POP	 AF
LAB_ram_b70f:
    CALL	ccp_getkey_no_wait
    JP	NZ, LAB_ram_b71b
    CALL	ccp_bdos_find_next
    JP	LAB_ram_b698
LAB_ram_b71b:
    POP	 DE
    JP	ccp_proc_interupted
    CALL	ccp_get_parameter
    CP	0xb
    JP	NZ, LAB_ram_b742
    LD	BC,msg_all_yn		       ;= "ALL (Y/N)?"
    CALL	ccp_out_crlf_msg
    CALL	SUB_ram_b339
    LD	HL, BYTE_ram_b207
    DEC	 (HL)
    JP	NZ, LAB_ram_b582
    INC	 HL
    LD	A, (HL)		;= 2020h
    CP	'Y'
    JP	NZ, LAB_ram_b582
    INC	 HL
    LD	(ccp_name_addr), HL		  ;= B208h
LAB_ram_b742:
    CALL	ccp_drive_sel
    LD	DE, ccp_current_fcb
    CALL	ccp_bdos_delete
    INC	 A
    CALL	Z, ccp_out_no_file
    JP	ccp_proc_interupted

msg_all_yn:
    db	"ALL (Y/N)?", 0x00

    CALL	ccp_get_parameter
    JP	NZ, SUB_ram_b409
    CALL	ccp_drive_sel
    CALL	ccp_open_f
    JP	Z, LAB_ram_b7a7
    CALL	ccp_out_crlf
    LD	HL, ccp_cur_drive+1
    LD	(HL), 0xff
LAB_ram_b774:
    LD	HL, ccp_cur_drive+1
    LD	A, (HL)
    CP	0x80
    JP	C, LAB_ram_b787
    PUSH	HL
    CALL	SUB_ram_b2fe
    POP	 HL
    JP	NZ, LAB_ram_b7a0
    XOR	 A
    LD	(HL), A
LAB_ram_b787:
    INC	 (HL)
    LD	HL, EXT_RAM.std_dma_buff
    CALL	sum_hl_a
    LD	A, (HL)
    CP	0x1a
    JP	Z, ccp_proc_interupted
    CALL	ccp_bdos_c_write
    CALL	ccp_getkey_no_wait
    JP	NZ, ccp_proc_interupted
    JP	LAB_ram_b774
LAB_ram_b7a0:
    DEC	 A
    JP	Z, ccp_proc_interupted
    CALL	ccp_out_rd_erro
LAB_ram_b7a7:
    CALL	SUB_ram_b666
    JP	SUB_ram_b409
    CALL	SUB_ram_b5f8
    PUSH	AF
    CALL	ccp_get_parameter
    JP	NZ, SUB_ram_b409
    CALL	ccp_drive_sel
    LD	DE, ccp_current_fcb
    PUSH	DE
    CALL	ccp_bdos_delete
    POP	 DE
    CALL	ccp_bdos_create_f
    JP	Z, ccp_no_space_l1
    XOR	 A
    LD	(ccp_cmd_line_buff+31), A
    POP	 AF
    LD	L, A
    LD	H, 0x0
    ADD	 HL, HL
    LD	DE, 0x100
LAB_ram_b7d4:
    LD	A, H
    OR	L
    JP	Z, ccp_close_f_cur
    DEC	 HL
    PUSH	HL
    LD	HL, EXT_RAM.std_dma_buff
    ADD	 HL, DE
    PUSH	HL
    CALL	ccp_bdos_dma_set
    LD	DE, ccp_current_fcb
    CALL	ccp_bdos_f_write
    POP	 DE
    POP	 HL
    JP	NZ, ccp_no_space_l1
    JP	LAB_ram_b7d4
; Close current file
ccp_close_f_cur:
    LD	DE, ccp_current_fcb
    CALL	ccp_bdos_close_f
    INC	 A
    JP	NZ, ccp_restore_dma_intr
ccp_no_space_l1:
    LD	BC,msg_no_space		     ;= "NO SPACE"
    CALL	ccp_out_crlf_msg
ccp_restore_dma_intr:
    CALL	ccp_set_dma_std_addr
    JP	ccp_proc_interupted
msg_no_space:
    db	"NO SPACE", 0x00
    CALL	ccp_get_parameter
    JP	NZ, SUB_ram_b409
    LD	A, (ccp_cur_drive)
    PUSH	AF
    CALL	ccp_drive_sel
    CALL	ccp_find_first
    JP	NZ, ccp_file_exists_l1
    LD	HL, ccp_current_fcb
    LD	DE, ccp_cmd_line_buff+15
    LD	B, 0x10
    CALL	SUB_ram_b642
    LD	HL, (ccp_name_addr)		  ;= B208h
    EX	DE, HL
    CALL	ccp_find_nxt_par
    CP	0x3d
    JP	Z, LAB_ram_b83f
    CP	0x5f
    JP	NZ, LAB_ram_b873
LAB_ram_b83f:
    EX	DE, HL
    INC	 HL
    LD	(ccp_name_addr), HL		  ;= B208h
    CALL	ccp_get_parameter
    JP	NZ, LAB_ram_b873
    POP	 AF
    LD	B, A
    LD	HL, ccp_cur_drive
    LD	A, (HL)
    OR	A
    JP	Z, LAB_ram_b859
    CP	B
    LD	(HL), B
    JP	NZ, LAB_ram_b873
LAB_ram_b859:
    LD	(HL), B
    XOR	 A
    LD	(ccp_current_fcb), A
    CALL	ccp_find_first
    JP	Z, LAB_ram_b86d
    LD	DE, ccp_current_fcb
    CALL	ccp_bdos_rename_f
    JP	ccp_proc_interupted
LAB_ram_b86d:
    CALL	ccp_out_no_file
    JP	ccp_proc_interupted
LAB_ram_b873:
    CALL	SUB_ram_b666
    JP	SUB_ram_b409
ccp_file_exists_l1:
    LD	BC,msg_file_exists		  ;= "FILE EXISTS"
    CALL	ccp_out_crlf_msg
    JP	ccp_proc_interupted
msg_file_exists:
    db	"FILE EXISTS", 0x00
    CALL	SUB_ram_b5f8
    CP	0x10
    JP	NC, SUB_ram_b409
    LD	E, A
    LD	A, (ccp_cmd_line_buff)
    CP	0x20
    JP	Z, SUB_ram_b409
    CALL	ccp_bdos_set_user
    JP	LAB_ram_b989

ccp_ret_func:
    CALL	SUB_ram_b3f5
    LD	A, (ccp_cmd_line_buff)
    CP	0x20
    JP	NZ, LAB_ram_b8c4
    LD	A, (ccp_cur_drive)
    OR	A
    JP	Z, LAB_ram_b989
    DEC	 A
    LD	(ccp_new_drive), A

    CALL	SUB_ram_b329

    CALL	ccp_bdos_drv_set
    JP	LAB_ram_b989
LAB_ram_b8c4:
    LD	DE, ccp_cmd_line_buff+8
    LD	A, (DE)
    CP	0x20
    JP	NZ, SUB_ram_b409
    PUSH	DE; =tmp_ccp_stack_1

    CALL	ccp_drive_sel
    POP	 DE; =tmp_ccp_stack_1
    LD	HL,msg_com			;= 'C'

    CALL	SUB_ram_b640

    CALL	ccp_open_f
    JP	Z, LAB_ram_b96b
    LD	HL, 0x100
LAB_ram_b8e1:
    PUSH	HL; =tmp_ccp_stack_1
    EX	DE, HL

    CALL	ccp_bdos_dma_set
    LD	DE, ccp_current_fcb

    CALL	ccp_bdos_read_f
    JP	NZ, LAB_ram_b901
    POP	 HL; =tmp_ccp_stack_1
    LD	DE, 0x80
    ADD	 HL, DE
    LD	DE, CCP_RAM_ENT
    LD	A, L
    SUB	 E
    LD	A, H
    SBC	 A, D
    JP	NC, ccp_bad_load_l1
    JP	LAB_ram_b8e1
LAB_ram_b901:
    POP	 HL; =tmp_ccp_stack_1
    DEC	 A
    JP	NZ, ccp_bad_load_l1
    CALL	SUB_ram_b666
    CALL	ccp_get_parameter
    LD	HL, ccp_cur_drive
    PUSH	HL; =tmp_ccp_stack_1
    LD	A, (HL)
    LD	(ccp_current_fcb), A
    LD	A, 0x10
    CALL	SUB_ram_b460
    POP	 HL; =tmp_ccp_stack_1
    LD	A, (HL)
    LD	(ccp_cmd_line_buff+15), A
    XOR	 A
    LD	(ccp_cmd_line_buff+31), A
    LD	DE, 0x5c
    LD	HL, ccp_current_fcb
    LD	B,FDC_DD80RB
    CALL	SUB_ram_b642
    LD	HL, ccp_fname_addr		   ;= 2020h
LAB_ram_b930:
    LD	A, (HL)		;= 2020h
    OR	A
    JP	Z, LAB_ram_b93e
    CP	0x20
    JP	Z, LAB_ram_b93e
    INC	 HL
    JP	LAB_ram_b930
LAB_ram_b93e:
    LD	B, 0x0
    LD	DE, 0x81

inc_copy_len:
    LD	A, (HL)
    LD	(DE), A
    OR	A
    JP	Z, eos_copyright
    INC	 B
    INC	 HL
    INC	 DE
    JP	inc_copy_len

eos_copyright:
    LD	A, B
    LD	(EXT_RAM.std_dma_buff), A
    CALL	ccp_out_crlf
    CALL	ccp_set_dma_std_addr
    CALL	SUB_ram_b31a
    CALL	EXT_RAM.loaded_program
    LD	SP, tmp_ccp_stack
    CALL	SUB_ram_b329
    CALL	ccp_bdos_drv_set
    JP	LAB_ram_b582

LAB_ram_b96b:
    CALL	SUB_ram_b666
    JP	SUB_ram_b409
ccp_bad_load_l1:
    LD	BC,msg_bad_load		     ;= "BAD LOAD"
    CALL	ccp_out_crlf_msg
    JP	ccp_proc_interupted

msg_bad_load:
    db	"BAD LOAD", 0x0

msg_com:
    db	'COM'

ccp_proc_interupted:
    CALL	SUB_ram_b666
LAB_ram_b989:

    CALL	ccp_get_parameter
    LD	A, (ccp_cmd_line_buff)
    SUB	 0x20
    LD	HL, ccp_cur_drive
    OR	(HL)
    JP	NZ, SUB_ram_b409
    JP	LAB_ram_b582

tmp_ccp_stack_bottom:
    dw	0h, 0h, 0h, 0h, 0h, 0h

tmp_ccp_stack_0:
    dw	0h
    dw	0h
tmp_ccp_stack:
    db	0h
BYTE_ram_b9ac:
    db	0h, '$$$     SUB', 0h, 0h
BYTE_ram_b9ba:
    db	0h
BYTE_ram_b9bb:
    ds 17, 0x00
BYTE_ram_b9cc:
    db	0h
ccp_current_fcb:
    db	0h
ccp_cmd_line_buff:
    ds	32, 0x0

ccp_bdos_call_result:
    db	0h

ccp_new_drive:
    db	0h
ccp_cur_drive:
    ds 16, 0

; head of BDOS, copyed at start form ROM to RAM
;   LD	SP,HL
;   LD	D,0
;   NOP
;   NOP
;   LD L,E
;	JP BDOS.bdos_entrance

BDOS_ENTER_JUMP		EQU	$+6

; -------------------------------------------------------
; Filler to align blocks in ROM
; -------------------------------------------------------
LAST        EQU     $
CODE_SIZE   EQU     LAST-0xB200
;FILL_SIZE   EQU     0x500-CODE_SIZE

    DISPLAY "| CCP_RAM\t| ",/H,CCP_RAM_ENT,"  | ",/H,CODE_SIZE," | \t    |"

	ENDMODULE

	IFNDEF	BUILD_ROM
		OUTEND
	ENDIF