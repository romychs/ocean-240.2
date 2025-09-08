; =======================================================
; Ocean-240.2
; CP/M BDOS at 0xC800:D5FF
;
; Disassembled by Romych 2025-09-09
; ======================================================

	INCLUDE	"io.inc"
	INCLUDE "equates.inc"
	INCLUDE "external_ram.inc"

	IFNDEF	BUILD_ROM
		OUTPUT bdos.bin
	ENDIF

	MODULE	BDOS

	ORG	0xC800

bdos_start:
    LD	SP, HL
    LD	D, 0x00
    NOP
    NOP
    LD	L, E
bdos_enter:
    JP	bdos_entrance

bdos_pere_addr:	dw	bdos_persub
bdos_sele_addr:	dw	bdos_selsub
bdos_rode_addr:	dw	bdos_rodsub
bdos_rofe_addr: dw	bdos_rofsub

; -------------------------------------------------------
; BDOS Handler
; Inp: C - func no
; DE - parameter
; Out: A or HL - result
; -------------------------------------------------------
bdos_entrance:
    EX	DE, HL
    LD	(TM_VARS.bdos_info), HL
    EX	DE, HL
    LD	A, E
    LD	(TM_VARS.bdos_linfo), A
    LD	HL, 0x00									; return val default = 0
    LD	(TM_VARS.bdos_aret), HL

	; Save user's stack pointer, set to local stack
    ADD	HL,SP
    LD	(TM_VARS.bdos_entsp), HL
    LD	SP, TM_VARS.bdos_usercode	     			; local stack setup
    XOR	A
    LD	(TM_VARS.bdos_fcbdsk), A	      			; fcbdsk,resel=false
    LD	(TM_VARS.bdos_resel), A
    LD	HL, bdos_goback
    PUSH	HL			   							; jmp goback equivalent to ret
    LD	A, C
    CP	BDOS_NFUNCS
    RET	NC
    LD	C, E			       						; possible output character to C
    LD	HL, functab									; DE=func, HL=.ciotab
    LD	E, A
    LD	D, 0x00
    ADD	HL, DE
    ADD	HL, DE
    LD	E, (HL)
    INC	HL
    LD	D, (HL)			    						; DE=functab(func)
    LD	HL, (TM_VARS.bdos_info)	       				; info in DE for later xchg
    EX	DE, HL
    JP	(HL)			      						; dispatched

; -------------------------------------------------------
; BDOS function handlers address table
; -------------------------------------------------------
functab:
    dw	BIOS.wboot_f
    dw	bdos_func1
    dw	bdos_tabout
    dw	bdos_func3
    dw	BIOS.punch_f
    dw	BIOS.list_f
    dw	bdos_func6
    dw	bdos_func7
    dw	bdos_func8
    dw	bdos_func9
    dw	bdos_read
    dw	bdos_func11
    dw	bdos_get_version
    dw	bdos_reset_disks
    dw	bdos_select_disk
    dw	bdos_open_file
    dw	bdos_close_file
    dw	bdos_search_first
    dw	bdos_search_next
    dw	bdos_rm_dir
    dw	bdos_read_file
    dw	bdos_write_file
    dw	bdos_make_file
    dw	bdos_ren_file
    dw	bdos_get_login_vec
    dw	bdos_get_cur_drive
    dw	bdos_set_dma_addr
    dw	bdos_get_logvect
    dw	bdos_set_ro
    dw	bdos_wr_protect
    dw	bdos_set_ind
    dw	bdos_get_dpb
    dw	bdos_set_user
    dw	bdos_rand_read
    dw	bdos_rand_write
    dw	bdos_compute_fs
    dw	bdos_set_random
    dw	bdos_reset_drives
    dw	bdos_not_impl
    dw	bdos_not_impl
    dw	bdos_rand_write_z

; -------------------------------------------------------
; Report permanent error
; -------------------------------------------------------
bdos_persub:
    LD	HL,permsg			 						; = 'B'
    CALL	bdos_errflag
    CP	BDOS_CTLC
    JP	Z, EXT_RAM.JP_WBOOT
    RET

; -------------------------------------------------------
; Report select error
; -------------------------------------------------------
bdos_selsub:
    LD	HL,selmsg									;= 'S'
    JP	bdos_wait_err

; -------------------------------------------------------
; Report write to read/only disk
; -------------------------------------------------------
bdos_rodsub:
    LD	HL,rodmsg			 						;= 'R'
    JP	bdos_wait_err

; -------------------------------------------------------
; Report read/only file
; -------------------------------------------------------
bdos_rofsub:
    LD	HL,rofmsg			 						;= 'F'

; -------------------------------------------------------
; Wait for response before boot
; -------------------------------------------------------
bdos_wait_err:
    CALL	bdos_errflag
    JP	EXT_RAM.JP_WBOOT

; -------------------------------------------------------
; Error messages
; -------------------------------------------------------
dskmsg:
    db	'Bdos Err On '
dskerr:
    db	" : $"
permsg:
    db	"Bad Sector$"
selmsg:
    db  "Select$"
rofmsg:
    db	"File "
rodmsg:
    db	"R/O$"

; -------------------------------------------------------
; Report error to console, message address in HL
; -------------------------------------------------------
bdos_errflag:
    PUSH	HL
    CALL	bdos_crlf
    LD	A, (TM_VARS.bdos_curdsk)
    ADD	A,'A'
    LD	(dskerr), A									;= ' '
    LD	BC,dskmsg									;= 'B'
    CALL	bdos_print
    POP	BC
    CALL	bdos_print

; -------------------------------------------------------
; Console handlers
; Read console character to A
; -------------------------------------------------------
bdos_conin:
    LD	HL, TM_VARS.bdos_kbchar
    LD	A, (HL)
    LD	(HL), 0x00
    OR	A
    RET	NZ
	;no previous keyboard character ready
    JP	BIOS.conin_f
; -------------------------------------------------------
; Read character from console with echo
; -------------------------------------------------------
bdos_conech:
    CALL	bdos_conin
    CALL	bdos_echoc
    RET	C
    PUSH	AF
    LD	C, A
    CALL	bdos_tabout
    POP	AF
    RET
; -------------------------------------------------------
; Echo character if cr, lf, tab, or backspace
; -------------------------------------------------------
bdos_echoc:
    CP	ASCII_CR
    RET	Z
    CP	ASCII_LF
    RET	Z
    CP	ASCII_TAB
    RET	Z
    CP	ASCII_BS
    RET	Z
    CP	' '
    RET
; -------------------------------------------------------
; check for character ready
; -------------------------------------------------------
bdos_conbrk:
    LD	A, (TM_VARS.bdos_kbchar)
    OR	A
    JP	NZ,conb1			  						; skip if active kbchar
    CALL	BIOS.const_f
    AND	0x1
    RET	Z											; return if no char ready
    CALL	BIOS.conin_f
    CP	CTLS
    JP	NZ,conb0
    CALL	BIOS.conin_f
    CP	CTLC
    JP	Z, EXT_RAM.JP_WBOOT
    XOR	A
    RET
conb0:
    LD	(TM_VARS.bdos_kbchar), A	      			; character in A, save it
conb1:
    LD	A, 0x1			     						; return with true set in accumulator
    RET
bdos_conout:

    LD	A, (TM_VARS.bdos_compcol)	     			; Compute character position/write con...
					      							;	compcol = true if computing column ...
    OR	A
    JP	NZ,compout
    PUSH	BC

    CALL	bdos_conbrk
    POP	BC
    PUSH	BC

    CALL	BIOS.conout_f
    POP	BC
    PUSH	BC
	; May be copying to the list device
    LD	A, (TM_VARS.bdos_listcp)
    OR	A
    CALL	NZ, BIOS.list_f
    POP	BC

; -------------------------------------------------------
; Compute column position
; -------------------------------------------------------
compout:
    LD	A, C
	; recall the character
	; and compute column position
    LD	HL, TM_VARS.bdos_column
    CP	RUB_OUT
    RET	Z
    INC	(HL)
    CP	' '
    RET	NC

	; not graphic, reset column position
    DEC	(HL)
    LD	A, (HL)
    OR	A
    RET	Z

    LD	A, C
    CP	ASCII_BS
    JP	NZ, notbacksp
	; backspace character
    DEC	(HL)
    RET

notbacksp:
    CP	ASCII_LF
    RET	NZ
    LD	(HL), 0x00
    RET

; -------------------------------------------------------
; Send C character with possible preceding up-arrow
; -------------------------------------------------------
bdos_ctlout:
    LD	A, C
    CALL	bdos_echoc								; cy if not graphic (or special case)
    JP	NC, bdos_tabout		      					; skip if graphic, tab, cr, lf, or ctlh
    PUSH	AF
    LD	C, CTL
    CALL	bdos_conout								; up arrow
    POP	AF
    OR	0x40										; becomes graphic letter
    LD	C, A										; ready to print
	; (drop through to tabout)

bdos_tabout:
    LD	A, C
	; Expand tabs to console
    CP	ASCII_TAB
    JP	NZ, bdos_conout

bpc_no_tabpos:
    LD	C,' '
    CALL	bdos_conout
    LD	A, (TM_VARS.bdos_column)
    AND	00000111b									; column mod 8 = 0 ?
    JP	NZ, bpc_no_tabpos
    RET

; -------------------------------------------------------
; Back-up one screen position
; -------------------------------------------------------
bdos_backup:
    CALL	bdos_pctlh
    LD	C, ' '
    CALL	BIOS.conout_f
; -------------------------------------------------------
; Send ctlh to console without affecting column count
; -------------------------------------------------------
bdos_pctlh:
    LD	C, ASCII_BS
    JP	BIOS.conout_f

; -------------------------------------------------------
; print #, cr, lf for ctlx, ctlu, ctlr functions
; then move to strtcol (starting column)
; -------------------------------------------------------
bdos_crlfp:
    LD	C, '#'
    CALL	bdos_conout
    CALL	bdos_crlf
crlfp0:
    LD	A, (TM_VARS.bdos_column)
    LD	HL, TM_VARS.bdos_strtcol
    CP	(HL)
    RET	NC
    LD	C, ' '
    CALL	bdos_conout
    JP	crlfp0

; -------------------------------------------------------
; Out carriage return line feed sequence
; -------------------------------------------------------

bdos_crlf:
    LD	C, ASCII_CR
    CALL	bdos_conout
    LD	C, ASCII_LF
    JP	bdos_conout

; -------------------------------------------------------
; Print $-ended message BC -> str
; -------------------------------------------------------
bdos_print:
    LD	A, (BC)
    CP	'$'
    RET	Z
    INC	BC
    PUSH	BC
    LD	C, A
    CALL	bdos_tabout
    POP	BC
    JP	bdos_print

; -------------------------------------------------------
; Buffered console input
; Reads characters from the keyboard into a memory buffer
; until RETURN is pressed.
; Inp: C=0Ah
; DE=address or zero
; -------------------------------------------------------
bdos_read:
    LD	A, (TM_VARS.bdos_column)
    LD	(TM_VARS.bdos_strtcol), A
    LD	HL, (TM_VARS.bdos_info)
    LD	C, (HL)
    INC	HL
    PUSH	HL
    LD	B, 0x00
	; B = current buffer length,
	; C = maximum buffer length,
	; HL= next to fill - 1
readnx:
    PUSH	BC
    PUSH	HL
readn1:
    CALL	bdos_conin
    AND	0x7f
    POP	HL
    POP	BC
    CP	0xd
    JP	Z,readen
    CP	0xa
    JP	Z,readen
    CP	0x8
    JP	NZ,noth
    LD	A, B
    OR	A
    JP	Z,readnx
    DEC	B
    LD	A, (TM_VARS.bdos_column)
    LD	(TM_VARS.bdos_compcol), A
    JP	linelen
noth:
    CP	0x7f			      						; not a backspace
    JP	NZ, notrub
    LD	A, B
    OR	A
    JP	Z, readnx
    LD	A, (HL)
    DEC	B
    DEC	HL
    JP	rdech1
notrub:
    CP	0x5
    JP	NZ, note
    PUSH	BC
    PUSH	HL

    CALL	bdos_crlf
    XOR	A
    LD	(TM_VARS.bdos_strtcol), A
    JP	readn1
note:
    CP	0x10
    JP	NZ,notp
    PUSH	HL
    LD	HL, TM_VARS.bdos_listcp
    LD	A, 0x1
    SUB	(HL)
    LD	(HL), A
    POP	HL
    JP	readnx
notp:
    CP	0x18
    JP	NZ, notx
    POP	HL
backx:
    LD	A, (TM_VARS.bdos_strtcol)
    LD	HL, TM_VARS.bdos_column
    CP	(HL)
    JP	NC, bdos_read
    DEC	(HL)

    CALL	bdos_backup
    JP	backx
notx:
    CP	0x15
    JP	NZ, notu

    CALL	bdos_crlfp
    POP	HL
    JP	bdos_read
notu:
    CP	0x12
    JP	NZ, rdecho
linelen:
    PUSH	BC

    CALL	bdos_crlfp
    POP	BC
    POP	HL
    PUSH	HL
    PUSH	BC
rep0:
    LD	A, B
    OR	A
    JP	Z, rep1
    INC	HL
    LD	C, (HL)
    DEC	B
    PUSH	BC
    PUSH	HL
    CALL	bdos_ctlout
    POP	HL
    POP	BC
    JP	rep0
rep1:
    PUSH	HL
    LD	A, (TM_VARS.bdos_compcol)
    OR	A
    JP	Z, readn1
    LD	HL, TM_VARS.bdos_column
    SUB	(HL)
    LD	(TM_VARS.bdos_compcol), A
	; move back compcol-column spaces

backsp:
    CALL	bdos_backup
    LD	HL, TM_VARS.bdos_compcol
    DEC	(HL)
    JP	NZ, backsp
    JP	readn1

rdecho:
    INC	HL
    LD	(HL), A
    INC	B
rdech1:
    PUSH	BC
    PUSH	HL
    LD	C, A

    CALL	bdos_ctlout
    POP	HL
    POP	BC
    LD	A, (HL)
    CP	0x3
    LD	A, B
    JP	NZ, notc
    CP	0x1
    JP	Z, EXT_RAM.JP_WBOOT
notc:
    CP	C
    JP	C,readnx

	; End of read operation, store blen
readen:
    POP	HL
    LD	(HL), B
    LD	C, 0xd
    JP	bdos_conout

; -------------------------------------------------------
; Console input with echo (C_READ)
; Out: A=L=character
; -------------------------------------------------------

bdos_func1:
    CALL	bdos_conech
    JP	bdos_ret_a

; -------------------------------------------------------
; Console input chartacter
; Out: A=L=ASCII character
; -------------------------------------------------------
bdos_func3:
    CALL	BIOS.reader_f
    JP	bdos_ret_a

; -------------------------------------------------------
; Direct console I/O
; Inp: E=code.
; E=code. Returned values (in A) vary.
; 0xff  Return a character without echoing if one is
; waiting; zero if none
; 0xfe  Return console input status. Zero if no
; character is waiting
; Out: A
; -------------------------------------------------------
bdos_func6:
    LD	A, C
    INC	A
    JP	Z, dirinp									; ff?
    INC	A
    JP	Z, BIOS.const_f								; fe?
    JP	BIOS.conout_f								; con out otherwise
dirinp:
    CALL	BIOS.const_f
    OR	A
    JP	Z, bdos_ret_mon
    CALL	BIOS.conin_f
    JP	bdos_ret_a

; -------------------------------------------------------
; Get I/O byte
; Out: [3] = I/O byte.
; -------------------------------------------------------
bdos_func7:
    LD	A, (EXT_RAM.bdos_ioloc)
    JP	bdos_ret_a

; -------------------------------------------------------
; Set I/O byte
; Inp: E=I/O byte.
; -------------------------------------------------------
bdos_func8:
    LD	HL, EXT_RAM.bdos_ioloc
    LD	(HL), C
    RET

; -------------------------------------------------------
; Out $-ended string
; Inp: DE -> string.
; -------------------------------------------------------
bdos_func9:
    EX	DE, HL
    LD	C,L
    LD	B, H
    JP	bdos_print

; -------------------------------------------------------
; Get console status
; Inp: A=L=status
; -------------------------------------------------------
bdos_func11:
    CALL	bdos_conbrk
bdos_ret_a:
    LD	(TM_VARS.bdos_aret), A
bdos_not_impl:
    RET

setlret1:
    LD	A, 0x1
    JP	bdos_ret_a

; -------------------------------------------------------
; Report select error
; -------------------------------------------------------
bdos_sel_error:
    LD	HL, bdos_sele_addr		   					;= C8A5h
bdos_goerr:
    LD	E, (HL)										;= C8A5h
    INC	HL
    LD	D, (HL)										; ->bdos_sele_addr+1
    EX	DE, HL
    JP	(HL)										; ->bdos_selsub

; -------------------------------------------------------
; Move C bytes from [DE] to [HL]
; -------------------------------------------------------
bdos_move:

    INC	C
bmove_nxt:
    DEC	C
    RET	Z
    LD	A, (DE)
    LD	(HL), A
    INC	DE
    INC	HL
    JP	bmove_nxt

; -------------------------------------------------------
; Select the disk drive given by curdsk, and fill
; the base addresses curtrka - alloca, then fill
; the values of the disk parameter block
; -------------------------------------------------------
dbos_selectdisk:
    LD	A, (TM_VARS.bdos_curdsk)
    LD	C, A
    CALL	BIOS.seldsk_f							; HL filled by call
	; HL = 0000 if error, otherwise disk headers
    LD	A, H
    OR	L
    RET	Z
    LD	E, (HL)
    INC	HL
    LD	D, (HL)
    INC	HL
    LD	(TM_VARS.bdos_cdrmaxa), HL
    INC	HL
    INC	HL
    LD	(TM_VARS.bdos_curtrka), HL
    INC	HL
    INC	HL
    LD	(TM_VARS.bdos_curreca), HL
    INC	HL
    INC	HL
    EX	DE, HL
    LD	(TM_VARS.bdos_tranv), HL					; .tran vector
    LD	HL, TM_VARS.bdos_buffa						; DE= source for move, HL=dest
    LD	C, ADDLIST
    CALL	bdos_move
	; Fill the disk parameter block
    LD	HL, (TM_VARS.bdos_dpbaddr)
    EX	DE, HL
    LD	HL, TM_VARS.dbos_sectpt
    LD	C, DBPLIST
    CALL	bdos_move
	; Set single/double map mode
    LD	HL, (TM_VARS.bdos_maxall)	     			; largest allocation number
    LD	A, H
    LD	HL, TM_VARS.bdos_single
    LD	(HL), 0xFF
    OR	A
    JP	Z, retselect
    LD	(HL), 0x00
retselect:
    LD	A, 0xff
    OR	A
    RET

; -------------------------------------------------------
; Move to home position, then offset to start of dir
; -------------------------------------------------------
bdos_home:
    CALL	BIOS.home_f
    XOR	A
    LD	HL, (TM_VARS.bdos_curtrka)
    LD	(HL), A
    INC	HL
    LD	(HL), A
    LD	HL, (TM_VARS.bdos_curreca)
    LD	(HL), A
    INC	HL
    LD	(HL), A
    RET

; -------------------------------------------------------
; Read buffer and check condition
; -------------------------------------------------------
bdos_rdbuff:
    CALL	BIOS.read_f
    JP	diocomp			   							; check for i/o errors

; -------------------------------------------------------
; Write buffer and check condition
; Inp: C - write type
; 0 - normal write operation
; 1 - directory write operation
; 2 - start of new block
; -------------------------------------------------------
bdos_wrbuff:
    CALL	BIOS.write_f

; -------------------------------------------------------
; Check for disk errors
; -------------------------------------------------------
diocomp:
    OR	A
    RET	Z
    LD	HL, bdos_pere_addr		   					;= C899h
    JP	bdos_goerr

; -------------------------------------------------------
; Seek the record containing the current dir entry
; -------------------------------------------------------
bdos_seekdir:
    LD	HL, (TM_VARS.bdos_dcnt)
    LD	C, DSK_SHF
    CALL	bdos_hlrotr
    LD	(TM_VARS.bdos_arecord), HL
    LD	(TM_VARS.bdos_drec), HL

; -------------------------------------------------------
; Seek the track given by arecord (actual record)
; local equates for registers
; -------------------------------------------------------
bdos_seek:
    LD	HL, TM_VARS.bdos_arecord
    LD	C, (HL)
    INC	HL
    LD	B, (HL)
    LD	HL, (TM_VARS.bdos_curreca)
    LD	E, (HL)
    INC	HL
    LD	D, (HL)
    LD	HL, (TM_VARS.bdos_curtrka)
    LD	A, (HL)
    INC	HL
    LD	H, (HL)
    LD	L, A
bseek_l0:
    LD	A, C
    SUB	E
    LD	A, B
    SBC	A, D
    JP	NC, bseek_l1
    PUSH	HL
    LD	HL, (TM_VARS.dbos_sectpt)
    LD	A, E
    SUB	L
    LD	E, A
    LD	A, D
    SBC	A, H
    LD	D, A
    POP	HL
    DEC	HL
    JP	bseek_l0
bseek_l1:
    PUSH	HL
    LD	HL, (TM_VARS.dbos_sectpt)
    ADD	HL, DE
    JP	C, bseek_l2
    LD	A, C
    SUB	L
    LD	A, B
    SBC	A, H
    JP	C, bseek_l2
    EX	DE, HL
    POP	HL
    INC	HL
    JP	bseek_l1
bseek_l2:
    POP	HL
    PUSH	BC
    PUSH	DE
    PUSH	HL
	; Stack contains (lowest) BC=arecord, DE=currec, HL=curtrk
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_offset)
    ADD	HL, DE
    LD	B, H
    LD	C,L
    CALL	BIOS.settrk_f
    POP	DE
    LD	HL, (TM_VARS.bdos_curtrka)
    LD	(HL), E
    INC	HL
    LD	(HL), D
    POP	DE
    LD	HL, (TM_VARS.bdos_curreca)
    LD	(HL), E
    INC	HL
    LD	(HL), D
    POP	BC
    LD	A, C
    SUB	E
    LD	C, A
    LD	A, B
    SBC	A, D
    LD	B, A
    LD	HL, (TM_VARS.bdos_tranv)
    EX	DE, HL
    CALL	BIOS.sectran_f
    LD	C,L
    LD	B, H
    JP	BIOS.setsec_f

; -------------------------------------------------------
; Compute disk map position for vrecord to HL
; -------------------------------------------------------
bdos_dm_position:
    LD	HL, TM_VARS.bdos_blkshf
    LD	C, (HL)
    LD	A, (TM_VARS.bdos_vrecord)
dmpos_l0:
    OR	A
    RRA
    DEC	C
    JP	NZ, dmpos_l0
	; A = shr(vrecord, blkshf) = vrecord/2**(sect/block)
    LD	B, A
    LD	A, 0x8
    SUB	(HL)
    LD	C, A
    LD	A, (TM_VARS.bdos_extval)
dmpos_l1:
    DEC	C
    JP	Z, dmpos_l2
    OR	A
    RLA
    JP	dmpos_l1
dmpos_l2:
    ADD	A, B
    RET												; with dm_position in A

; -------------------------------------------------------
; Return disk map value from position given by BC
; -------------------------------------------------------
dbos_getdm:
    LD	HL, (TM_VARS.bdos_info)
    LD	DE, DSK_MAP
    ADD	HL, DE
    ADD	HL, BC
    LD	A, (TM_VARS.bdos_single)
    OR	A
    JP	Z,getdmd
    LD	L, (HL)
    LD	H, 0x00
    RET

getdmd:
    ADD	HL, BC
    LD	E, (HL)
    INC	HL
    LD	D, (HL)
    EX	DE, HL
    RET

; -------------------------------------------------------
; Compute disk block number from current FCB
; -------------------------------------------------------
bdos_index:
    CALL	bdos_dm_position
    LD	C, A
    LD	B, 0x00
    CALL	dbos_getdm
    LD	(TM_VARS.bdos_arecord), HL
    RET

; -------------------------------------------------------
; Called following index to see if block allocated
; -------------------------------------------------------
bdos_allocated:
    LD	HL, (TM_VARS.bdos_arecord)
    LD	A,L
    OR	H
    RET

; -------------------------------------------------------
; Compute actual record address, assuming index called
; -------------------------------------------------------
bdos_atran:
    LD	A, (TM_VARS.bdos_blkshf)
    LD	HL, (TM_VARS.bdos_arecord)
bdatarn_l0:
    ADD	HL, HL
    DEC	A
    JP	NZ, bdatarn_l0
    LD	(TM_VARS.bdos_arecord1), HL
    LD	A, (TM_VARS.bdos_blmsk)
    LD	C, A
    LD	A, (TM_VARS.bdos_vrecord)
    AND	C
    OR	L
    LD	L, A
    LD	(TM_VARS.bdos_arecord), HL
    RET

; -------------------------------------------------------
; Get current extent field address to A
; -------------------------------------------------------
bdos_getexta:
    LD	HL, (TM_VARS.bdos_info)
    LD	DE, EXT_NUM
    ADD	HL, DE			     						; HL -> .fcb(extnum)
    RET

; -------------------------------------------------------
; Compute reccnt and nxtrec addresses for get/setfcb
; -------------------------------------------------------
bdos_getfcba:
    LD	HL, (TM_VARS.bdos_info)
    LD	DE,REC_CNT
    ADD	HL, DE
    EX	DE, HL
    LD	HL, 0x11			   						; (nxtrec-reccnt)
    ADD	HL, DE
    RET

; -------------------------------------------------------
; Set variables from currently addressed fcb
; -------------------------------------------------------
bdos_getfcb:
    CALL	bdos_getfcba
    LD	A, (HL)
    LD	(TM_VARS.bdos_vrecord), A
    EX	DE, HL
    LD	A, (HL)
    LD	(TM_VARS.bdos_rcount), A
    CALL	bdos_getexta
    LD	A, (TM_VARS.bdos_extmsk)
    AND	(HL)
    LD	(TM_VARS.bdos_extval), A
    RET

; -------------------------------------------------------
; Place values back into current fcb
; -------------------------------------------------------
bdos_setfcb:
    CALL	bdos_getfcba
    LD	A, (TM_VARS.bdos_seqio)
    CP	0x2
    JP	NZ, bsfcb_l0
    XOR	A
bsfcb_l0:
    LD	C, A
    LD	A, (TM_VARS.bdos_vrecord)
    ADD	A, C
    LD	(HL), A
    EX	DE, HL
    LD	A, (TM_VARS.bdos_rcount)
    LD	(HL), A
    RET

; -------------------------------------------------------
; Rotate HL right by C bits
; -------------------------------------------------------
bdos_hlrotr:
    INC	C
bhlr_nxt:
    DEC	C
    RET	Z
    LD	A, H
    OR	A
    RRA
    LD	H, A
    LD	A,L
    RRA
    LD	L, A
    JP	bhlr_nxt

; -------------------------------------------------------
; Compute checksum for current directory buffer
; -------------------------------------------------------
bdos_compute_cs:
    LD	C, REC_SIZ									; size of directory buffer
    LD	HL, (TM_VARS.bdos_buffa)
    XOR	A
bcompcs_l0:
    ADD	A, (HL)
    INC	HL
    DEC	C
    JP	NZ, bcompcs_l0
    RET

; -------------------------------------------------------
; Rotate HL left by C bits
; -------------------------------------------------------
bdos_hlrotl:
    INC	C
brothll_nxt:
    DEC	C
    RET	Z
    ADD	HL, HL
    JP	brothll_nxt

; -------------------------------------------------------
; Set a "1" value in curdsk position of BC
; -------------------------------------------------------
bdos_set_cdisk:
    PUSH	BC
    LD	A, (TM_VARS.bdos_curdsk)
    LD	C, A
    LD	HL, 0x1
    CALL	bdos_hlrotl
    POP	BC
    LD	A, C
    OR	L
    LD	L, A
    LD	A, B
    OR	H
    LD	H, A
    RET

; -------------------------------------------------------
; Return true if dir checksum difference occurred
; -------------------------------------------------------
bdos_nowrite:
    LD	HL, (TM_VARS.bdos_rodsk)
    LD	A, (TM_VARS.bdos_curdsk)
    LD	C, A
    CALL	bdos_hlrotr
    LD	A,L
    AND	0x1
    RET

; -------------------------------------------------------
; Temporarily set current drive to be read-only;
; attempts to write to it will fail
; -------------------------------------------------------
bdos_set_ro:
    LD	HL, TM_VARS.bdos_rodsk
    LD	C, (HL)
    INC	HL
    LD	B, (HL)

    CALL	bdos_set_cdisk
    LD	(TM_VARS.bdos_rodsk), HL
	; high water mark in directory goes to max
    LD	HL, (TM_VARS.bdos_dirmax)
    INC	HL
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_cdrmaxa)
    LD	(HL), E
    INC	HL
    LD	(HL), D
    RET

; -------------------------------------------------------
; Check current directory element for read/only status
; -------------------------------------------------------
bdos_check_rodir:
    CALL	bdos_getdptra

; -------------------------------------------------------
; Check current buff(dptr) or fcb(0) for r/o status
; -------------------------------------------------------
bdos_check_rofile:
    LD	DE,RO_FILE
    ADD	HL, DE
    LD	A, (HL)
    RLA
    RET	NC
    LD	HL, bdos_rofe_addr							;= C8B1h
    JP	bdos_goerr

; -------------------------------------------------------
; Check for write protected disk
; -------------------------------------------------------
bdos_check_write:
    CALL	bdos_nowrite
    RET	Z
    LD	HL, bdos_rode_addr							;= C8ABh
    JP	bdos_goerr

; -------------------------------------------------------
; Compute the address of a directory element at
; positon dptr in the buffer
; -------------------------------------------------------
bdos_getdptra:
    LD	HL, (TM_VARS.bdos_buffa)
    LD	A, (TM_VARS.bdos_dptr)

; -------------------------------------------------------
; HL = HL + A
; -------------------------------------------------------
bdos_hl_add_a:
    ADD	A,L
    LD	L, A
    RET	NC
    INC	H
    RET

; -------------------------------------------------------
; Compute the address of the module number
; bring module number to accumulator
; (high order bit is fwf (file write flag)
; -------------------------------------------------------
bdos_getmodnum:
    LD	HL, (TM_VARS.bdos_info)
    LD	DE, MOD_NUM
    ADD	HL, DE
    LD	A, (HL)
    RET

; -------------------------------------------------------
; Clear the module number field for user open/make
; -------------------------------------------------------
bdos_clr_modnum:
    CALL	bdos_getmodnum
    LD	(HL), 0x00
    RET

; -------------------------------------------------------
; Set fwf (file write flag)
; -------------------------------------------------------
setfwf:
    CALL	bdos_getmodnum
    OR	FWF_MASK
    LD	(HL), A
    RET

; -------------------------------------------------------
; Return cy if cdrmax > dcnt
; -------------------------------------------------------
bdos_compcdr:
    LD	HL, (TM_VARS.bdos_dcnt)
    EX	DE, HL										; DE = directory counter
    LD	HL, (TM_VARS.bdos_cdrmaxa)					; HL=.cdrmax
    LD	A, E
    SUB	(HL)
    INC	HL
    LD	A, D
    SBC	A, (HL)
	;Condition dcnt - cdrmax  produces cy if cdrmax>dcnt
    RET

; -------------------------------------------------------
; If not (cdrmax > dcnt) then cdrmax = dcnt+1
; -------------------------------------------------------
bdos_setcdr:
    CALL	bdos_compcdr
    RET	C
    INC	DE
    LD	(HL), D
    DEC	HL
    LD	(HL), E
    RET

; -------------------------------------------------------
; HL = DE - HL
; -------------------------------------------------------
bdos_de_sub_hl:
    LD	A, E
    SUB	L
    LD	L, A
    LD	A, D
    SBC	A, H
    LD	H, A
    RET

bdos_newchecksum:
    LD	C, TRUE

bdos_checksum:
    LD	HL, (TM_VARS.bdos_drec)
    EX	DE, HL
    LD	HL, (TM_VARS.BYTE_ram_ba66)
    CALL	bdos_de_sub_hl
    RET	NC
    PUSH	BC
    CALL	bdos_compute_cs
    LD	HL, (TM_VARS.BYTE_ram_ba57)
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_drec)
    ADD	HL, DE
    POP	BC
    INC	C
    JP	Z, initial_cs
    CP	(HL)
    RET	Z
    CALL	bdos_compcdr
    RET	NC
    CALL	bdos_set_ro
    RET
initial_cs:
    LD	(HL), A
    RET

; -------------------------------------------------------
; Write the current directory entry, set checksum
; -------------------------------------------------------
bdos_wrdir:
    CALL	bdos_newchecksum
    CALL	bdos_setdir
    LD	C, 0x1
    CALL	bdos_wrbuff
    JP	bdos_setdata

; -------------------------------------------------------
; Read a directory entry into the directory buffer
; -------------------------------------------------------
bdos_rd_dir:
    CALL	bdos_setdir
    CALL	bdos_rdbuff

; -------------------------------------------------------
; Set data dma address
; -------------------------------------------------------
bdos_setdata:
    LD	HL, TM_VARS.bdos_dmaad
    JP	bdos_set_dma

; -------------------------------------------------------
; Set directory dma address
; -------------------------------------------------------
bdos_setdir:
    LD	HL, TM_VARS.bdos_buffa

; -------------------------------------------------------
; HL=.dma address to set (i.e., buffa or dmaad)
; -------------------------------------------------------
bdos_set_dma:
    LD	C, (HL)
    INC	HL
    LD	B, (HL)
    JP	BIOS.setdma_f

; -------------------------------------------------------
; Copy the directory entry to the user buffer
; after call to search or searchn by user code
; -------------------------------------------------------
bdos_dir_to_user:
    LD	HL, (TM_VARS.bdos_buffa)
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_dmaad)
    LD	C,REC_SIZ
    JP	bdos_move

; -------------------------------------------------------
; return zero flag if at end of directory, non zero
; if not at end (end of dir if dcnt = 0ffffh)
; -------------------------------------------------------
bdos_end_of_dir:
    LD	HL, TM_VARS.bdos_dcnt
    LD	A, (HL)
    INC	HL
    CP	(HL)
    RET	NZ
    INC	A
    RET

; -------------------------------------------------------
; Set dcnt to the end of the directory
; -------------------------------------------------------
bdos_set_end_dir:
    LD	HL, ENDDIR
    LD	(TM_VARS.bdos_dcnt), HL
    RET

; -------------------------------------------------------
; Read next directory entry, with C=true if initializing
; -------------------------------------------------------
bdos_read_dir:
    LD	HL, (TM_VARS.bdos_dirmax)
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_dcnt)
    INC	HL
    LD	(TM_VARS.bdos_dcnt), HL
    CALL	bdos_de_sub_hl
    JP	NC, bdrd_l0
    JP	bdos_set_end_dir
bdrd_l0:
    LD	A, (TM_VARS.bdos_dcnt)
    AND	DSK_MSK
    LD	B, FCB_SHF
bdrd_l1:
    ADD	A, A
    DEC	B
    JP	NZ, bdrd_l1
    LD	(TM_VARS.bdos_dptr), A
    OR	A
    RET	NZ
    PUSH	BC
    CALL	bdos_seekdir
    CALL	bdos_rd_dir
    POP	BC
    JP	bdos_checksum

; -------------------------------------------------------
; Given allocation vector position BC, return with byte
; containing BC shifted so that the least significant
; bit is in the low order accumulator position.  HL is
; the address of the byte for possible replacement in
; memory upon return, and D contains the number of shifts
; required to place the returned value back into position
; -------------------------------------------------------
bdos_getallocbit:
    LD	A, C
    AND	00000111b
    INC	A
    LD	E, A
    LD	D, A
    LD	A, C
    RRCA
    RRCA
    RRCA
    AND	00011111b
    LD	C, A
    LD	A, B
    ADD	A, A
    ADD	A, A
    ADD	A, A
    ADD	A, A
    ADD	A, A
    OR	C
    LD	C, A
    LD	A, B
    RRCA
    RRCA
    RRCA
    AND	00011111b
    LD	B, A
    LD	HL, (TM_VARS.bdos_alloca)					; Base address of allocation vector
    ADD	HL, BC
    LD	A, (HL)
ga_rotl:
    RLCA
    DEC	E
    JP	NZ, ga_rotl
    RET

; -------------------------------------------------------
; BC is the bit position of ALLOC to set or reset.  The
; value of the bit is in register E.
; -------------------------------------------------------
bdos_setallocbit:
    PUSH	DE
    CALL	bdos_getallocbit
    AND	11111110b
    POP	BC
    OR	C

; -------------------------------------------------------
; Byte value from ALLOC is in register A, with shift count
; in register C (to place bit back into position), and
; target ALLOC position in registers HL, rotate and replace
; -------------------------------------------------------
bdos_sab_rotr:
    RRCA
    DEC	D
    JP	NZ, bdos_sab_rotr
    LD	(HL), A
    RET

; -------------------------------------------------------
; Scan the disk map addressed by dptr for non-zero
; entries, the allocation vector entry corresponding
; to a non-zero entry is set to the value of C (0,1)
; -------------------------------------------------------
bdos_scandm:
    CALL	bdos_getdptra
	; HL addresses the beginning of the directory entry
    LD	DE, DSK_MAP
    ADD	HL, DE
    PUSH	BC
    LD	C, 0x11										; fcblen-dskmap+1 - size of single b...
scandm_l0:
    POP	DE
    DEC	C
    RET	Z
    PUSH	DE
    LD	A, (TM_VARS.bdos_single)
    OR	A
    JP	Z, scandm_l1
    PUSH	BC
    PUSH	HL
    LD	C, (HL)
    LD	B, 0x00
    JP	scandm_l2
scandm_l1:
    DEC	C
    PUSH	BC
    LD	C, (HL)
    INC	HL
    LD	B, (HL)
    PUSH	HL
scandm_l2:
    LD	A, C
    OR	B
    JP	Z, scandm_l3
    LD	HL, (TM_VARS.bdos_maxall)
    LD	A,L
    SUB	C
    LD	A, H
    SBC	A, B
    CALL	NC, bdos_setallocbit
scandm_l3:
    POP	HL
    INC	HL
    POP	BC
    JP	scandm_l0

; -------------------------------------------------------
; Initialize the current disk
; lret = false, set to true if $ file exists
; compute the length of the allocation vector - 2
; -------------------------------------------------------
bdos_initialize:
    LD	HL, (TM_VARS.bdos_maxall)
    LD	C, 0x3
    CALL	bdos_hlrotr
    INC	HL
    LD	B, H
    LD	C,L
    LD	HL, (TM_VARS.bdos_alloca)
binitial_l0:
    LD	(HL), 0x00
    INC	HL
    DEC	BC
    LD	A, B
    OR	C
    JP	NZ, binitial_l0
    LD	HL, (TM_VARS.bdos_dirblk)
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_alloca)
    LD	(HL), E
    INC	HL
    LD	(HL), D
    CALL	bdos_home
    LD	HL, (TM_VARS.bdos_cdrmaxa)
    LD	(HL), 0x3
    INC	HL
    LD	(HL), 0x00
    CALL	bdos_set_end_dir
binitial_l2:
    LD	C, TRUE
    CALL	bdos_read_dir
    CALL	bdos_end_of_dir
    RET	Z
    CALL	bdos_getdptra
    LD	A, EMPTY
    CP	(HL)
    JP	Z, binitial_l2
    LD	A, (TM_VARS.bdos_usercode)
    CP	(HL)
    JP	NZ, sbdos_pdollar
    INC	HL
    LD	A, (HL)
    SUB	'$'
    JP	NZ, sbdos_pdollar
	; dollar file found, mark in lret
    DEC	A
    LD	(TM_VARS.bdos_aret), A

sbdos_pdollar:
    LD	C, 0x1
    CALL	bdos_scandm
    CALL	bdos_setcdr
    JP	binitial_l2

; -------------------------------------------------------
; copy directory location to lret following
; delete, rename, ...
; -------------------------------------------------------
bdos_copy_dirloc:
    LD	A, (TM_VARS.bdos_dirloc)
    JP	bdos_ret_a

; -------------------------------------------------------
; Compare extent# in A with that in C, return nonzero
; if they do not match
; -------------------------------------------------------
bdos_compex:
    PUSH	BC
    PUSH	AF
    LD	A, (TM_VARS.bdos_extmsk)
    CPL
    LD	B, A
    LD	A, C
    AND	B
    LD	C, A
    POP	AF
    AND	B
    SUB	C
    AND	MAX_EXT
    POP	BC
    RET

; -------------------------------------------------------
; Search for directory element of length C at info
; -------------------------------------------------------
bdos_search:
    LD	A, 0xff
    LD	(TM_VARS.bdos_dirloc), A
    LD	HL, TM_VARS.bdos_searchl
    LD	(HL), C
    LD	HL, (TM_VARS.bdos_info)
    LD	(TM_VARS.bdos_searcha), HL
    CALL	bdos_set_end_dir
    CALL	bdos_home

; -------------------------------------------------------
; search for the next directory element, assuming
; a previous call on search which sets searcha and
; searchl
; -------------------------------------------------------
bdos_searchn:
    LD	C, FALSE
    CALL	bdos_read_dir
    CALL	bdos_end_of_dir
    JP	Z, bdos_search_fin
    LD	HL, (TM_VARS.bdos_searcha)
    EX	DE, HL
    LD	A, (DE)
    CP	EMPTY
    JP	Z, search_next
    PUSH	DE
    CALL	bdos_compcdr
    POP	DE
    JP	NC, bdos_search_fin
search_next:
    CALL	bdos_getdptra
    LD	A, (TM_VARS.bdos_searchl)
    LD	C, A
    LD	B, 0x00
search_loop:
    LD	A, C
    OR	A
    JP	Z, search_end
    LD	A, (DE)
    CP	0x3f
    JP	Z, search_ok
    LD	A, B
    CP	0xd
    JP	Z, search_ok
    CP	0xc
    LD	A, (DE)
    JP	Z, search_ext
    SUB	(HL)
    AND	0x7f
    JP	NZ, bdos_searchn
    JP	search_ok
	; A has fcb character attempt an extent # match
search_ext:
    PUSH	BC
    LD	C, (HL)
    CALL	bdos_compex
    POP	BC
    JP	NZ, bdos_searchn
	; current character matches
search_ok:
    INC	DE
    INC	HL
    INC	B
    DEC	C
    JP	search_loop
	; entiry name matches, return dir position
search_end:
    LD	A, (TM_VARS.bdos_dcnt)
    AND	0x3
    LD	(TM_VARS.bdos_aret), A
    LD	HL, TM_VARS.bdos_dirloc
    LD	A, (HL)
    RLA
    RET	NC
    XOR	A
    LD	(HL), A
    RET

	; end of directory, or empty name
bdos_search_fin:
    CALL	bdos_set_end_dir
    LD	A, 0xff
    JP	bdos_ret_a

; -------------------------------------------------------
; Delete the currently addressed file
; -------------------------------------------------------
bdos_delete:
    CALL	bdos_check_write
    LD	C, EXT_NUM
    CALL	bdos_search
bdelete_l0:
    CALL	bdos_end_of_dir
    RET	Z
    CALL	bdos_check_rodir
    CALL	bdos_getdptra
    LD	(HL), EMPTY
    LD	C, 0x00
    CALL	bdos_scandm
    CALL	bdos_wrdir
    CALL	bdos_searchn
    JP	bdelete_l0

; -------------------------------------------------------
; Given allocation vector position BC, find the zero bit
; closest to this position by searching left and right.
; if found, set the bit to one and return the bit position
; in hl.  if not found (i.e., we pass 0 on the left, or
; maxall on the right), return 0000 in hl
; -------------------------------------------------------
bdos_get_block:
    LD	D, B
    LD	E, C
bgb_lefttst:
    LD	A, C
    OR	B
    JP	Z, bgb_righttst
    DEC	BC
    PUSH	DE
    PUSH	BC
    CALL	bdos_getallocbit
    RRA
    JP	NC, bgb_retblock
    POP	BC
    POP	DE

bgb_righttst:
    LD	HL, (TM_VARS.bdos_maxall)
    LD	A, E
    SUB	L
    LD	A, D
    SBC	A, H
    JP	NC, bgb_retblock0
    INC	DE
    PUSH	BC
    PUSH	DE
    LD	B, D
    LD	C, E
    CALL	bdos_getallocbit
    RRA
    JP	NC, bgb_retblock
    POP	DE
    POP	BC
    JP	bgb_lefttst
bgb_retblock:
    RLA
    INC	A
    CALL	bdos_sab_rotr
    POP	HL
    POP	DE
    RET
bgb_retblock0:
    LD	A, C
    OR	B
    JP	NZ, bgb_lefttst
    LD	HL, 0x00
    RET

; -------------------------------------------------------
; Copy the entire file control block
; -------------------------------------------------------
bdos_copy_fcb:
    LD	C, 0x00
    LD	E, FCB_LEN
; -------------------------------------------------------
; copy fcb information starting at C for E bytes
; into the currently addressed directory entry
; -------------------------------------------------------
dbos_copy_dir:
    PUSH	DE
    LD	B, 0x00
    LD	HL, (TM_VARS.bdos_info)
    ADD	HL, BC
    EX	DE, HL
    CALL	bdos_getdptra
    POP	BC
    CALL	bdos_move

; -------------------------------------------------------
; Enter from close to seek and copy current element
; -------------------------------------------------------
bdos_seek_copy:
    CALL	bdos_seekdir
    JP	bdos_wrdir

; -------------------------------------------------------
; Rename the file described by the first half of
; the currently addressed file control block. the
; new name is contained in the last half of the
; currently addressed file conrol block.  the file
; name and type are changed, but the reel number
; is ignored.  the user number is identical
; -------------------------------------------------------
bdos_rename:
    CALL	bdos_check_write
    LD	C, EXT_NUM
    CALL	bdos_search
    LD	HL, (TM_VARS.bdos_info)
    LD	A, (HL)
    LD	DE, 0x10
    ADD	HL, DE
    LD	(HL), A
brn_l0:
    CALL	bdos_end_of_dir
    RET	Z
    CALL	bdos_check_rodir
    LD	C, DSK_MAP
    LD	E, EXT_NUM
    CALL	dbos_copy_dir
    CALL	bdos_searchn
    JP	brn_l0

; -------------------------------------------------------
; Set file indicators for current fcb
; -------------------------------------------------------
bdos_indicators:
    LD	C, EXT_NUM
    CALL	bdos_search
bdi_l0:
    CALL	bdos_end_of_dir
    RET	Z
    LD	C, 0x00
    LD	E, EXT_NUM
    CALL	dbos_copy_dir
    CALL	bdos_searchn
    JP	bdi_l0

; -------------------------------------------------------
; Search for the directory entry, copy to FCB
; -------------------------------------------------------
open:
    LD	C,NAM_LEN
    CALL	bdos_search
    CALL	bdos_end_of_dir
    RET	Z

bdos_open_copy:
    CALL	bdos_getexta
    LD	A, (HL)
    PUSH	AF
    PUSH	HL
    CALL	bdos_getdptra
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_info)
    LD	C, 0x20
    PUSH	DE
    CALL	bdos_move
    CALL	setfwf
    POP	DE
    LD	HL, 0xc
    ADD	HL, DE
    LD	C, (HL)
    LD	HL, 0xf
    ADD	HL, DE
    LD	B, (HL)
    POP	HL
    POP	AF
    LD	(HL), A
    LD	A, C
    CP	(HL)
    LD	A, B
    JP	Z, bdos_open_rcnd
    LD	A, 0x00
    JP	C, bdos_open_rcnd
    LD	A, 0x80

bdos_open_rcnd:
    LD	HL, (TM_VARS.bdos_info)						; A has record count to fill
    LD	DE,REC_CNT
    ADD	HL, DE
    LD	(HL), A
    RET

; -------------------------------------------------------
; HL = .fcb1(i), DE = .fcb2(i),
; if fcb1(i) = 0 then fcb1(i) := fcb2(i)
; -------------------------------------------------------
bdos_mergezero:
    LD	A, (HL)
    INC	HL
    OR	(HL)
    DEC	HL
    RET	NZ
    LD	A, (DE)
    LD	(HL), A
    INC	DE
    INC	HL
    LD	A, (DE)
    LD	(HL), A
    DEC	DE
    DEC	HL
    RET

bdos_close:
    XOR	A
    LD	(TM_VARS.bdos_aret), A
    LD	(TM_VARS.bdos_dcnt), A
    LD	(TM_VARS.bdos_dcnt_hi), A
    CALL	bdos_nowrite
    RET	NZ
    CALL	bdos_getmodnum
    AND	FWF_MASK
    RET	NZ
    LD	C,NAM_LEN
    CALL	bdos_search
    CALL	bdos_end_of_dir
    RET	Z
    LD	BC, DSK_MAP
    CALL	bdos_getdptra
    ADD	HL, BC
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_info)
    ADD	HL, BC
    LD	C, 0x10										; (fcblen-dskmap) ;length of single ...
bdos_merge0:
    LD	A, (TM_VARS.bdos_single)
    OR	A
    JP	Z, bdos_merge
    LD	A, (HL)
    OR	A
    LD	A, (DE)
    JP	NZ, bdm_fcbnzero
    LD	(HL), A
bdm_fcbnzero:
    OR	A
    JP	NZ, bdm_buffnzero
    LD	A, (HL)
    LD	(DE), A
bdm_buffnzero:
    CP	(HL)
    JP	NZ, bdm_mergerr
    JP	bdm_dmset									; merged ok
bdos_merge:
    CALL	bdos_mergezero
    EX	DE, HL
    CALL	bdos_mergezero
    EX	DE, HL
    LD	A, (DE)
    CP	(HL)
    JP	NZ, bdm_mergerr
    INC	DE
    INC	HL
    LD	A, (DE)
    CP	(HL)
    JP	NZ, bdm_mergerr
    DEC	C
bdm_dmset:
    INC	DE
    INC	HL
    DEC	C
    JP	NZ, bdos_merge0
    LD	BC, 0xffec			 						; -(fcblen-extnum)
    ADD	HL, BC
    EX	DE, HL
    ADD	HL, BC
    LD	A, (DE)
    CP	(HL)
    JP	C, bdm_endmerge
    LD	(HL), A
    LD	BC, 0x3			    						; (reccnt-extnum)
    ADD	HL, BC
    EX	DE, HL
    ADD	HL, BC
    LD	A, (HL)
    LD	(DE), A
bdm_endmerge:
    LD	A, 0xff
    LD	(TM_VARS.bdos_fcb_copied), A
    JP	bdos_seek_copy
bdm_mergerr:
    LD	HL, TM_VARS.bdos_aret
    DEC	(HL)
    RET

; -------------------------------------------------------
; Create a new file by creating a directory entry
; then opening the file
; -------------------------------------------------------
bdos_make:
    CALL	bdos_check_write
    LD	HL, (TM_VARS.bdos_info)
    PUSH	HL
    LD	HL, TM_VARS.bdos_efcb
	; Save FCB address, look for 0xE5
    LD	(TM_VARS.bdos_info), HL
    LD	C, 0x1
    CALL	bdos_search
    CALL	bdos_end_of_dir
    POP	HL
    LD	(TM_VARS.bdos_info), HL
    RET	Z
    EX	DE, HL
    LD	HL, NAM_LEN
    ADD	HL, DE
    LD	C, 0x11										; fcblen-namlen
    XOR	A
bdm_set0:
    LD	(HL), A
    INC	HL
    DEC	C
    JP	NZ, bdm_set0
    LD	HL,U_BYTES
    ADD	HL, DE
    LD	(HL), A			    						; Current record within extent?
    CALL	bdos_setcdr
    CALL	bdos_copy_fcb
    JP	setfwf

; -------------------------------------------------------
; Close the current extent, and open the next one
; if possible.  RMF is true if in read mod
; -------------------------------------------------------
bdos_open_reel:
    XOR	A
    LD	(TM_VARS.bdos_fcb_copied), A
    CALL	bdos_close
    CALL	bdos_end_of_dir
    RET	Z
    LD	HL, (TM_VARS.bdos_info)
    LD	BC, EXT_NUM
    ADD	HL, BC
    LD	A, (HL)
    INC	A
    AND	MAX_EXT
    LD	(HL), A
    JP	Z, bor_open_mod
    LD	B, A
    LD	A, (TM_VARS.bdos_extmsk)
    AND	B
    LD	HL, TM_VARS.bdos_fcb_copied
    AND	(HL)
    JP	Z, bor_open_reel0
    JP	bor_open_reel1
bor_open_mod:
    LD	BC, 0x2										; (modnum-extnum)
    ADD	HL, BC
    INC	(HL)
    LD	A, (HL)
    AND	MAX_MOD
    JP	Z, bor_oper_r_err
bor_open_reel0:
    LD	C,NAM_LEN
    CALL	bdos_search
    CALL	bdos_end_of_dir
    JP	NZ, bor_open_reel1
    LD	A, (TM_VARS.bdos_rfm)
    INC	A
    JP	Z, bor_oper_r_err
    CALL	bdos_make
    CALL	bdos_end_of_dir
    JP	Z, bor_oper_r_err
    JP	bor_open_reel2
bor_open_reel1:
    CALL	bdos_open_copy
bor_open_reel2:
    CALL	bdos_getfcb
    XOR	A
    JP	bdos_ret_a
bor_oper_r_err:
    CALL	setlret1
    JP	setfwf

; -------------------------------------------------------
; Sequential disk read operation
; -------------------------------------------------------
bdos_seq_disk_read:
    LD	A, 0x1
    LD	(TM_VARS.bdos_seqio), A
	; drop through to diskread

bdos_disk_read:
    LD	A, TRUE
    LD	(TM_VARS.bdos_rfm), A
    CALL	bdos_getfcb
    LD	A, (TM_VARS.bdos_vrecord)
    LD	HL, TM_VARS.bdos_rcount
    CP	(HL)
    JP	C, bdr_recordok
    CP	128
    JP	NZ, bdr_diskeof
    CALL	bdos_open_reel
    XOR	A
    LD	(TM_VARS.bdos_vrecord), A
    LD	A, (TM_VARS.bdos_aret)
    OR	A
    JP	NZ, bdr_diskeof
bdr_recordok:
    CALL	bdos_index
    CALL	bdos_allocated
    JP	Z, bdr_diskeof
    CALL	bdos_atran
    CALL	bdos_seek
    CALL	bdos_rdbuff
    JP	bdos_setfcb
bdr_diskeof:
    JP	setlret1

; -------------------------------------------------------
; Sequential write disk
; -------------------------------------------------------
bdos_seq_disk_write:
    LD	A, 0x1
    LD	(TM_VARS.bdos_seqio), A
bdos_disk_write:
    LD	A, FALSE
    LD	(TM_VARS.bdos_rfm), A
    CALL	bdos_check_write
    LD	HL, (TM_VARS.bdos_info)
    CALL	bdos_check_rofile
    CALL	bdos_getfcb
    LD	A, (TM_VARS.bdos_vrecord)
    CP	0x80										; lstrec+1
    JP	NC,setlret1
    CALL	bdos_index
    CALL	bdos_allocated
    LD	C, 0x00
    JP	NZ, bdw_disk_wr1
    CALL	bdos_dm_position
    LD	(TM_VARS.bdos_dminx), A
    LD	BC, 0x00
    OR	A
    JP	Z, bdw_nopblock
    LD	C, A
    DEC	BC
    CALL	dbos_getdm
    LD	B, H
    LD	C,L
bdw_nopblock:
    CALL	bdos_get_block
    LD	A,L
    OR	H
    JP	NZ, bdw_block_ok
    LD	A, 0x2
    JP	bdos_ret_a
bdw_block_ok:
    LD	(TM_VARS.bdos_arecord), HL
    EX	DE, HL
    LD	HL, (TM_VARS.bdos_info)
    LD	BC, DSK_MAP
    ADD	HL, BC
    LD	A, (TM_VARS.bdos_single)
    OR	A
    LD	A, (TM_VARS.bdos_dminx)
    JP	Z, bdw_alloc_w
    CALL	bdos_hl_add_a
    LD	(HL), E
    JP	bdw_disk_wru
bdw_alloc_w:
    LD	C, A
    LD	B, 0x00
    ADD	HL, BC
    ADD	HL, BC
    LD	(HL), E
    INC	HL
    LD	(HL), D
	; Disk write to previously unallocated block
bdw_disk_wru:
    LD	C, 0x2
bdw_disk_wr1:
    LD	A, (TM_VARS.bdos_aret)
    OR	A
    RET	NZ
    PUSH	BC
    CALL	bdos_atran
    LD	A, (TM_VARS.bdos_seqio)
    DEC	A
    DEC	A
    JP	NZ, bdw_disk_wr11
    POP	BC
    PUSH	BC
    LD	A, C
    DEC	A
    DEC	A
    JP	NZ, bdw_disk_wr11
    PUSH	HL
    LD	HL, (TM_VARS.bdos_buffa)
    LD	D, A
bdw_fill0:
    LD	(HL), A
    INC	HL
    INC	D
    JP	P, bdw_fill0
    CALL	bdos_setdir
    LD	HL, (TM_VARS.bdos_arecord1)
    LD	C, 0x2
bdw_fill1:
    LD	(TM_VARS.bdos_arecord), HL
    PUSH	BC
    CALL	bdos_seek
    POP	BC
    CALL	bdos_wrbuff
    LD	HL, (TM_VARS.bdos_arecord)
    LD	C, 0x00
    LD	A, (TM_VARS.bdos_blmsk)
    LD	B, A
    AND	L
    CP	B
    INC	HL
    JP	NZ, bdw_fill1
    POP	HL
    LD	(TM_VARS.bdos_arecord), HL
    CALL	bdos_setdata
bdw_disk_wr11:
    CALL	bdos_seek
    POP	BC
    PUSH	BC
    CALL	bdos_wrbuff
    POP	BC
    LD	A, (TM_VARS.bdos_vrecord)
    LD	HL, TM_VARS.bdos_rcount
    CP	(HL)
    JP	C, bdw_disk_wr2
    LD	(HL), A
    INC	(HL)
    LD	C, 0x2
bdw_disk_wr2:
    DEC	C
    DEC	C
    JP	NZ, bwd_no_update
    PUSH	AF
    CALL	bdos_getmodnum
    AND	0x7f			      						; (not fwfmsk) and 0ffh
    LD	(HL), A
    POP	AF
bwd_no_update:
    CP	LST_REC
    JP	NZ, bdw_disk_wr3
    LD	A, (TM_VARS.bdos_seqio)
    CP	0x1
    JP	NZ, bdw_disk_wr3
    CALL	bdos_setfcb
    CALL	bdos_open_reel
    LD	HL, TM_VARS.bdos_aret
    LD	A, (HL)
    OR	A
    JP	NZ, bdw_no_space
    DEC	A
    LD	(TM_VARS.bdos_vrecord), A
bdw_no_space:
    LD	(HL), 0x00
bdw_disk_wr3:
    JP	bdos_setfcb

; -------------------------------------------------------
; Random access seek operation, C=0ffh if read mode
; FCB is assumed to address an active file control block
; (modnum has been set to 1100$0000b if previous bad seek)
; -------------------------------------------------------
bdos_rseek:
    XOR	A
    LD	(TM_VARS.bdos_seqio), A
bdos_rseek1:
    PUSH	BC
    LD	HL, (TM_VARS.bdos_info)
    EX	DE, HL
    LD	HL,RAN_REC
    ADD	HL, DE
    LD	A, (HL)
    AND	7Fh
    PUSH	AF
    LD	A, (HL)
    RLA
    INC	HL
    LD	A, (HL)
    RLA
    AND	00011111b
    LD	C, A
    LD	A, (HL)
    RRA
    RRA
    RRA
    RRA
    AND	0xf
    LD	B, A
    POP	AF
    INC	HL
    LD	L, (HL)
    INC	L
    DEC	L
    LD	L, 0x6
    JP	NZ, brs_seek_err
    LD	HL, NXT_REC
    ADD	HL, DE
    LD	(HL), A
    LD	HL, 0xc
    ADD	HL, DE
    LD	A, C
    SUB	(HL)
    JP	NZ, brs_close
    LD	HL,MOD_NUM
    ADD	HL, DE
    LD	A, B
    SUB	(HL)
    AND	0x7f
    JP	Z, brs_seek_ok
brs_close:
    PUSH	BC
    PUSH	DE
    CALL	bdos_close
    POP	DE
    POP	BC
    LD	L, 0x3			     						; Cannot close error #3
    LD	A, (TM_VARS.bdos_aret)
    INC	A
    JP	Z, brs_bad_seek
    LD	HL, EXT_NUM
    ADD	HL, DE
    LD	(HL), C
    LD	HL, MOD_NUM
    ADD	HL, DE
    LD	(HL), B
    CALL	open
    LD	A, (TM_VARS.bdos_aret)
    INC	A
    JP	NZ, brs_seek_ok
    POP	BC
    PUSH	BC
    LD	L, 0x4			     						; Seek to unwritten extent #4
    INC	C
    JP	Z, brs_bad_seek
    CALL	bdos_make
    LD	L, 0x5			     						; Cannot create new extent #5
    LD	A, (TM_VARS.bdos_aret)
    INC	A
    JP	Z, brs_bad_seek
brs_seek_ok:
    POP	BC
    XOR	A
    JP	bdos_ret_a
brs_bad_seek:
    PUSH	HL
    CALL	bdos_getmodnum
    LD	(HL), 11000000b
    POP	HL
brs_seek_err:
    POP	BC
    LD	A,L
    LD	(TM_VARS.bdos_aret), A
    JP	setfwf

; -------------------------------------------------------
; Random disk read operation
; -------------------------------------------------------
bdos_rand_disk_read:
    LD	C, TRUE
    CALL	bdos_rseek
    CALL	Z, bdos_disk_read
    RET

; -------------------------------------------------------
; Random disk write operation
; -------------------------------------------------------
bdos_rand_disk_write:
    LD	C, FALSE
    CALL	bdos_rseek
    CALL	Z, bdos_disk_write
    RET

; -------------------------------------------------------
; Compute random record position for
; getfilesize/setrandom
; -------------------------------------------------------
bdos_compute_rr:
    EX	DE, HL
    ADD	HL, DE
    LD	C, (HL)
    LD	B, 0x00
    LD	HL, EXT_NUM
    ADD	HL, DE
    LD	A, (HL)
    RRCA
    AND	0x80
    ADD	A, C
    LD	C, A
    LD	A, 0x00
    ADC	A, B
    LD	B, A
    LD	A, (HL)
    RRCA
    AND	0xf
    ADD	A, B
    LD	B, A
    LD	HL,MOD_NUM
    ADD	HL, DE
    LD	A, (HL)
    ADD	A, A
    ADD	A, A
    ADD	A, A
    ADD	A, A
    PUSH	AF
    ADD	A, B
    LD	B, A
    PUSH	AF
    POP	HL
    LD	A,L
    POP	HL
    OR	L
    AND	0x1
    RET

; -------------------------------------------------------
; Compute logical file size for current FCB
; -------------------------------------------------------
bdos_get_file_size:
    LD	C, EXT_NUM
    CALL	bdos_search
    LD	HL, (TM_VARS.bdos_info)
    LD	DE,RAN_REC
    ADD	HL, DE
    PUSH	HL
    LD	(HL), D
    INC	HL
    LD	(HL), D
    INC	HL
    LD	(HL), D
bgf_get_size:
    CALL	bdos_end_of_dir
    JP	Z, bgf_set_size
    CALL	bdos_getdptra
    LD	DE,REC_CNT
    CALL	bdos_compute_rr
    POP	HL
    PUSH	HL
    LD	E, A
    LD	A, C
    SUB	(HL)
    INC	HL
    LD	A, B
    SBC	A, (HL)
    INC	HL
    LD	A, E
    SBC	A, (HL)
    JP	C, bgf_get_nxt_size
    LD	(HL), E
    DEC	HL
    LD	(HL), B
    DEC	HL
    LD	(HL), C
bgf_get_nxt_size:
    CALL	bdos_searchn
    JP	bgf_get_size
bgf_set_size:
    POP	HL
    RET

; -------------------------------------------------------
; Set the random record count bytes of the FCB to the number
; of the last record read/written by the sequential I/O calls.
; Inp: DE -> FCB
; -------------------------------------------------------
bdos_set_random:
    LD	HL, (TM_VARS.bdos_info)
    LD	DE,NXT_REC

    CALL	bdos_compute_rr
    LD	HL,RAN_REC
    ADD	HL, DE										; HL = .fcb(ranrec)
    LD	(HL), C
    INC	HL
    LD	(HL), B
    INC	HL
    LD	(HL), A
    RET

; -------------------------------------------------------
; Select disk info for subsequent input or output ops
; -------------------------------------------------------
bdos_select:
    LD	HL, (TM_VARS.bdos_dlog)
    LD	A, (TM_VARS.bdos_curdsk)
    LD	C, A
    CALL	bdos_hlrotr
    PUSH	HL
    EX	DE, HL
    CALL	dbos_selectdisk
    POP	HL
    CALL	Z, bdos_sel_error
    LD	A,L
    RRA
    RET	C
    LD	HL, (TM_VARS.bdos_dlog)
    LD	C,L
    LD	B, H
    CALL	bdos_set_cdisk
    LD	(TM_VARS.bdos_dlog), HL
    JP	bdos_initialize

; -------------------------------------------------------
; Select disc
; Inp: E=drive number 0 for A:, 1 for B: up to 15 for P
; Out: L=A=0 - ok or 0FFh - error
; -------------------------------------------------------
bdos_select_disk:
    LD	A, (TM_VARS.bdos_linfo)
    LD	HL, TM_VARS.bdos_curdsk
    CP	(HL)
    RET	Z
    LD	(HL), A
    JP	bdos_select

; -------------------------------------------------------
bdos_reselect:
    LD	A, TRUE
    LD	(TM_VARS.bdos_resel), A
    LD	HL, (TM_VARS.bdos_info)
    LD	A, (HL)
    AND	00011111b
    DEC	A
    LD	(TM_VARS.bdos_linfo), A
    CP	30
    JP	NC, brs_noselect
    LD	A, (TM_VARS.bdos_curdsk)
    LD	(TM_VARS.bdos_olddsk), A
    LD	A, (HL)
    LD	(TM_VARS.bdos_fcbdsk), A
    AND	11100000b
    LD	(HL), A
    CALL	bdos_select_disk
brs_noselect:
    LD	A, (TM_VARS.bdos_usercode)
    LD	HL, (TM_VARS.bdos_info)
    OR	(HL)
    LD	(HL), A
    RET

; -------------------------------------------------------
; Return version number
; -------------------------------------------------------
bdos_get_version:
    LD	A, DVERS			   						; 0x22 - v2.2
    JP	bdos_ret_a

; -------------------------------------------------------
; Reset disk system - initialize to disk 0
; -------------------------------------------------------
bdos_reset_disks:
    LD	HL, 0x00
    LD	(TM_VARS.bdos_rodsk), HL
    LD	(TM_VARS.bdos_dlog), HL
    XOR	A
    LD	(TM_VARS.bdos_curdsk), A
    LD	HL, EXT_RAM.std_dma_buff
    LD	(TM_VARS.bdos_dmaad), HL

    CALL	bdos_setdata
    JP	bdos_select

; -------------------------------------------------------
; Open file
; Inp: DE -> FCB
; Out: BA and HL - error.
; -------------------------------------------------------
bdos_open_file:
    CALL	bdos_clr_modnum
    CALL	bdos_reselect
    JP	open

; -------------------------------------------------------
; Close file
; Inp: DE -> FCB
; Out: BA and HL - error.
; -------------------------------------------------------
bdos_close_file:
    CALL	bdos_reselect
    JP	bdos_close

; -------------------------------------------------------
; Search for first occurrence of a file
; Inp: DE -> FCB
; Out: BA and HL - error.
; -------------------------------------------------------
bdos_search_first:
    LD	C, 0x00
    EX	DE, HL
    LD	A, (HL)
    CP	'?'
    JP	Z, bsf_qselect
    CALL	bdos_getexta
    LD	A, (HL)
    CP	'?'
    CALL	NZ, bdos_clr_modnum
    CALL	bdos_reselect
    LD	C, NAM_LEN
bsf_qselect:
    CALL	bdos_search
    JP	bdos_dir_to_user

; -------------------------------------------------------
; Search for next occurrence of a file name
; Inp: DE -> FCB
; Out: BA and HL - error.
; -------------------------------------------------------
bdos_search_next:
    LD	HL, (TM_VARS.bdos_searcha)
    LD	(TM_VARS.bdos_info), HL
    CALL	bdos_reselect
    CALL	bdos_searchn
    JP	bdos_dir_to_user

; -------------------------------------------------------
; Remove directory
; Inp: DE -> FCB
; Out: BA and HL - error.
; -------------------------------------------------------
bdos_rm_dir:
    CALL	bdos_reselect
    CALL	bdos_delete
    JP	bdos_copy_dirloc

; -------------------------------------------------------
; Read next 128b record
; Inp: DE -> FCB
; Out: BA and HL - error.
; A=0 - Ok,
; 1 - end of file,
; 9 - invalid FCB,
; 10 - media changed,
; 0FFh - hardware error.
; -------------------------------------------------------
bdos_read_file:
    CALL	bdos_reselect
    JP	bdos_seq_disk_read

; -------------------------------------------------------
; Write next 128b record
; Inp: DE -> FCB
; Out: BA and HL - error.
; A=0 - Ok,
; 1 - directory full,
; 2 - disc full,
; 9 - invalid FCB,
; 10 - media changed,
; 0FFh - hardware error.
; -------------------------------------------------------
bdos_write_file:
    CALL	bdos_reselect
    JP	bdos_seq_disk_write

; -------------------------------------------------------
; Create file
; Inp: DE -> FCB.
; Out: Error in BA and HL
; A=0 - Ok,
; 0FFh - directory is full.
; -------------------------------------------------------
bdos_make_file:
    CALL	bdos_clr_modnum
    CALL	bdos_reselect
    JP	bdos_make

; -------------------------------------------------------
; Rename file. New name, stored at FCB+16
; Inp: DE -> FCB.
; Out: Error in BA and HL
; A=0-3 if successful;
; A=0FFh if error.
; -------------------------------------------------------
bdos_ren_file:
    CALL	bdos_reselect
    CALL	bdos_rename
    JP	bdos_copy_dirloc

; -------------------------------------------------------
; Return bitmap of logged-in drives
; Out: bitmap in HL.
; -------------------------------------------------------
bdos_get_login_vec:
    LD	HL, (TM_VARS.bdos_dlog)
    JP	sthl_ret

; -------------------------------------------------------
; Return current drive
; Out: A - currently selected drive. 0 => A:, 1 => B: etc.
; -------------------------------------------------------
bdos_get_cur_drive:
    LD	A, (TM_VARS.bdos_curdsk)
    JP	bdos_ret_a

; -------------------------------------------------------
; Set DMA address
; Inp: DE - address of DMA buffer
; -------------------------------------------------------
bdos_set_dma_addr:
    EX	DE, HL
    LD	(TM_VARS.bdos_dmaad), HL
    JP	bdos_setdata

; -------------------------------------------------------
; Return the login vector address
; Out: HL - address
; -------------------------------------------------------
bdos_get_logvect:
    LD	HL, (TM_VARS.bdos_alloca)
    JP	sthl_ret

; -------------------------------------------------------
; Temporarily set current drive to be read-only
; -------------------------------------------------------
bdos_wr_protect:
    LD	HL, (TM_VARS.bdos_rodsk)
    JP	sthl_ret

; -------------------------------------------------------
; Set file indicators
; -------------------------------------------------------
bdos_set_ind:
    CALL	bdos_reselect
    CALL	bdos_indicators
    JP	bdos_copy_dirloc

; -------------------------------------------------------
; Return address of disk parameter block
; -------------------------------------------------------
bdos_get_dpb:
    LD	HL, (TM_VARS.bdos_dpbaddr)
sthl_ret:
    LD	(TM_VARS.bdos_aret), HL
    RET

; -------------------------------------------------------
; Get/set user number
; Inp: E - number 0-15. If E=0FFh, returns number in A.
;
; -------------------------------------------------------
bdos_set_user:
    LD	A, (TM_VARS.bdos_linfo)
    CP	0xff
    JP	NZ, bsu_set_user
    LD	A, (TM_VARS.bdos_usercode)
    JP	bdos_ret_a
bsu_set_user:
    AND	0x1f
    LD	(TM_VARS.bdos_usercode), A
    RET

; -------------------------------------------------------
; Random read. Record specified in the random record count area of the FCB, at the DMA address*
; Inp: DE -> FCB
; Out: Error codes in BA and HL.
; -------------------------------------------------------
bdos_rand_read:
    CALL	bdos_reselect
    JP	bdos_rand_disk_read

; -------------------------------------------------------
; Random access write record.
; Record specified in the random record count area of the FCB, at the DMA address
; Inp: DE -> FCB
; Out: Error codes in BA and HL.
; -------------------------------------------------------
bdos_rand_write:

    CALL	bdos_reselect
    JP	bdos_rand_disk_write

; -------------------------------------------------------
; Compute file size.
; Set the random record count bytes of the FCB to the
; number of 128-byte records in the file.
; -------------------------------------------------------
bdos_compute_fs:
    CALL	bdos_reselect
    JP	bdos_get_file_size

; -------------------------------------------------------
; Selectively reset disc drives
; Inp: DE - bitmap of drives to reset.
; Out: A=0 - Ok, 0FFh if error
; -------------------------------------------------------
bdos_reset_drives:
    LD	HL, (TM_VARS.bdos_info)
    LD	A,L
    CPL
    LD	E, A
    LD	A, H
    CPL
    LD	HL, (TM_VARS.bdos_dlog)
    AND	H
    LD	D, A
    LD	A,L
    AND	E
    LD	E, A
    LD	HL, (TM_VARS.bdos_rodsk)
    EX	DE, HL
    LD	(TM_VARS.bdos_dlog), HL
    LD	A,L
    AND	E
    LD	L, A
    LD	A, H
    AND	D
    LD	H, A
    LD	(TM_VARS.bdos_rodsk), HL
    RET

; -------------------------------------------------------
; Arrive here at end of processing to return to user
; -------------------------------------------------------
bdos_goback:
    LD	A, (TM_VARS.bdos_resel)
    OR	A
    JP	Z, bdos_ret_mon
    LD	HL, (TM_VARS.bdos_info)
    LD	(HL), 0x00
    LD	A, (TM_VARS.bdos_fcbdsk)
    OR	A
    JP	Z, bdos_ret_mon
    LD	(HL), A
    LD	A, (TM_VARS.bdos_olddsk)
    LD	(TM_VARS.bdos_linfo), A
    CALL	bdos_select_disk

; -------------------------------------------------------
; Return from the disk monitor
; -------------------------------------------------------
bdos_ret_mon:
    LD	HL, (TM_VARS.bdos_entsp)
    LD	SP, HL
    LD	HL, (TM_VARS.bdos_aret)
    LD	A,L
    LD	B, H
    RET

; -------------------------------------------------------
; Random disk write with zero fill of
; unallocated block
; -------------------------------------------------------
bdos_rand_write_z:
    CALL	bdos_reselect
    LD	A, 0x2
    LD	(TM_VARS.bdos_seqio), A
    LD	C, FALSE
    CALL	bdos_rseek1
    CALL	Z, bdos_disk_write
    RET

; -------------------------------------------------------
; Initialized data ?
; -------------------------------------------------------
filler:
	db 0xF1, 0xE1

; -------------------------------------------------------
; Filler to align blocks in ROM
; -------------------------------------------------------
LAST        EQU     $
CODE_SIZE   EQU     LAST-0xC800
FILL_SIZE   EQU     0xE00-CODE_SIZE

	DISPLAY "| BDOS\t| ",/H,bdos_start,"  | ",/H,CODE_SIZE," | ",/H,FILL_SIZE," |"

FILLER
    DS  FILL_SIZE, 0xFF

	ENDMODULE

	IFNDEF	BUILD_ROM
		OUTEND
	ENDIF
