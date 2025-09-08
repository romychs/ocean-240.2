; =======================================================
; Ocean-240.2
;
; CP/M BIOS
;
; Disassembled by Romych 2025-09-09
; =======================================================

	INCLUDE "equates.inc"
	INCLUDE "external_ram.inc"
	INCLUDE "mon_entries.inc"

	IFNDEF	BUILD_ROM
		OUTPUT bios.bin
	ENDIF

	MODULE	BIOS

	ORG	0xD600

; -------------------------------------------------------
; BIOS JUMP TABLE
; -------------------------------------------------------
boot_f:		JP	bios_boot
wboot_f:    JP	bios_wboot

; -------------------------------------------------------
; console status to reg-a
; -------------------------------------------------------
const_f:    JP	MON_ENTRY.non_con_status

; -------------------------------------------------------
; console character to reg-a
; -------------------------------------------------------
conin_f:	JP	MON_ENTRY.mon_con_in

; -------------------------------------------------------
; console character from c to console out
; -------------------------------------------------------
conout_f:	JP	MON_ENTRY.mon_con_out

; -------------------------------------------------------
; list device out
; -------------------------------------------------------
list_f:		JP	MON_ENTRY.mon_char_print

; -------------------------------------------------------
; punch device out
; -------------------------------------------------------
punch_f:	JP	MON_ENTRY.mpn_serial_out

; -------------------------------------------------------
; reader character in to reg-a
; -------------------------------------------------------
reader_f:	JP	MON_ENTRY.mon_serial_in

; -------------------------------------------------------
; move to home position, treat as track 00 seek
; -------------------------------------------------------
home_f:		JP	home

; -------------------------------------------------------
; select disk given by register c
; -------------------------------------------------------
seldsk_f:	JP	seldsk
settrk_f:	JP	settrk
setsec_f:	JP	setsec

; -------------------------------------------------------
; Set DMA address from BC
; -------------------------------------------------------
setdma_f:	JP	setdma
read_f:		JP	read
write_f:	JP	write
listst_f:	JP	listst
sectran_f:	JP	sectran

; -------------------------------------------------------
; Reserved
; -------------------------------------------------------
			JP	EXT_RAM.JP_WBOOT
			JP	EXT_RAM.JP_WBOOT

; -------------------------------------------------------
; Tape read
; -------------------------------------------------------
tape_read_f:	JP	MON_ENTRY.mon_tape_read

; -------------------------------------------------------
; Tape write
; -------------------------------------------------------
tape_write_f:	JP	MON_ENTRY.mon_tape_write

; -------------------------------------------------------
; Tape wait block
; -------------------------------------------------------
tape_wait_f:	JP	MON_ENTRY.mon_tape_wait

; -------------------------------------------------------
; cold start
; -------------------------------------------------------
bios_boot:
    LD	HL, (EXT_RAM.BDOS_ENT_ADDR)
    LD	DE, 0x45fa
    ADD	HL, DE
    LD	A, H
    OR	L
    JP	Z, bios_signon
    LD	HL, 0x80
    LD	B, 0x80
boot_l1:

    LD	(HL), EMPTY
    INC	HL
    DEC	B
    JP	NZ, boot_l1
    LD	HL, 0x80
    LD	DE, 0x0
    LD	B, 0x8

boot_l2:
    PUSH	BC
    CALL	MON_ENTRY.ram_disk_write
    POP	BC
    INC	DE
    DEC	B
    JP	NZ, boot_l2
    XOR	A
    LD	(EXT_RAM.cur_user_no), A

bios_signon:
    LD	SP, 0x100
    LD	HL, msg_hello			;= 1Bh
    CALL	print_strz

; -------------------------------------------------------
; warm start
; -------------------------------------------------------
bios_wboot:
    LD	SP, 0x100
    LD	HL, CCP_DST_ADDR
    LD	DE, CCP_SRC_ADDR
    LD	BC, CCP_SIZE

; -------------------------------------------------------
; Move CPP from 0xC000 to 0xB200
; -------------------------------------------------------
wb_move_cpp:
    LD	A, (DE)
    LD	(HL), A
    INC	DE
    INC	HL
    DEC	BC
    LD	A, B
    OR	C
    JP	NZ, wb_move_cpp
	; Clear tail bytes with 00
    LD	HL, TM_VARS.bdos_compcol
    LD	BC, 213

wb_clr_ba09:
    LD	(HL), 0x0
    INC	HL
    DEC	BC
    LD	A, B
    OR	C
    JP	NZ,wb_clr_ba09
    LD	A, 0xe5
    LD	(TM_VARS.bdos_efcb), A
    LD	A, 0x80
    LD	(TM_VARS.bdos_dmaad), A
    LD	HL, TM_VARS.DPH_base
	; Move DPH
    LD	DE,dph
    LD	BC, 78
wb_mv_dph_next:
    LD	A, (DE)
    LD	(HL), A
    INC	HL
    INC	DE
    DEC	BC
    LD	A, B
    OR	C
    JP	NZ,wb_mv_dph_next

    LD	BC, 0x80			   						; DMA default buffer addr
    CALL	setdma_f
    LD	A, JP_OPCODE	    						; JP
    LD	(EXT_RAM.JP_WBOOT), A
    LD	HL,wboot_f
    LD	(EXT_RAM.wboot_addr), HL
    LD	(EXT_RAM.jp_bdos_enter), A
    LD	HL, CCP_RAM.BDOS_ENTER_JUMP
    LD	(EXT_RAM.BDOS_ENT_ADDR), HL
    XOR	A
    LD	(TM_VARS.slicer_has_data), A
    LD	(TM_VARS.slicer_uninited_count), A
    LD	A, (EXT_RAM.cur_user_no)
    LD	C, A
    JP	CCP_DST_ADDR


listst:
    XOR	A
    RET

; -------------------------------------------------------
; Select disk given by register c
; -------------------------------------------------------
seldsk:
    LD	A, C
    LD	(TM_VARS.cur_disk), A
    OR	A
    JP	Z,sd_no_chnged
    LD	A, E										; bit 0 is set if disk already selected
    AND	0x1
    JP	NZ,sd_no_chnged

; -------------------------------------------------------
; reread disk
; -------------------------------------------------------
    LD	(TM_VARS.slicer_has_data), A
    LD	(TM_VARS.slicer_uninited_count), A
	; calc DPH address
sd_no_chnged:
    LD	L, C
    LD	H, 0x0
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    LD	DE, TM_VARS.DPH_base
    ADD	HL, DE
    RET

; -------------------------------------------------------
; move to track 00
; -------------------------------------------------------
home:
    LD	A, (TM_VARS.cur_disk)
    OR	A
    JP	Z,ho_no_chg
    LD	A, (TM_VARS.slicer_need_save)
    OR	A
    JP	NZ,ho_no_chg
    LD	(TM_VARS.slicer_has_data), A
ho_no_chg:
    LD	C, 0x0

; -------------------------------------------------------
; set track address (0,...76) for subsequent read/write
; -------------------------------------------------------
settrk:
    LD	HL, TM_VARS.curr_track
    LD	(HL), C
    RET

; -------------------------------------------------------
; set sector address (1,..., 26) for subsequent read/write
; -------------------------------------------------------
setsec:
    LD	HL, TM_VARS.curr_sec
    LD	(HL), C
    RET

; -------------------------------------------------------
; set subsequent dma address (initially 80h)
; -------------------------------------------------------
setdma:
    LD	L, C
    LD	H, B
    LD	(TM_VARS.dma_addr), HL
    RET
sectran:
    LD	L, C
    LD	H, B
    RET

; -------------------------------------------------------
; read track/sector to preset dma address
; -------------------------------------------------------
read:
    LD	A, (TM_VARS.cur_disk)
    OR	A
    JP	NZ,read_phys			; for physical disk use special routine
    CALL	ram_disk_calc_addr
    CALL	MON_ENTRY.ram_disk_read
    XOR	A
    RET

; -------------------------------------------------------
; write track/sector from preset dma address
; -------------------------------------------------------
write:
    LD	A, (TM_VARS.cur_disk)
    OR	A
    JP	NZ,write_phys
    CALL	ram_disk_calc_addr
    CALL	MON_ENTRY.ram_disk_write
    XOR	A
    RET

; -------------------------------------------------------
; Calculate address for current sector and track
; -------------------------------------------------------
ram_disk_calc_addr:
    LD	HL, TM_VARS.curr_track
	; HL = cur_track * 16
    LD	L, (HL)
    LD	H, 0x0
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
	; DE = HL + cur_sec
    EX	DE, HL
    LD	HL, TM_VARS.curr_sec
    LD	L, (HL)
    LD	H, 0x0
    ADD	HL, DE
    EX	DE, HL
	; store address
    LD	HL, (TM_VARS.dma_addr)
    RET

read_phys:
    CALL	read_phys_op
    RET

write_phys:
    CALL	write_phys_op
    RET

read_phys_op:
    XOR	A
	; reset counter
    LD	(TM_VARS.slicer_uninited_count), A
    LD	A, 0x1
    LD	(TM_VARS.tmp_slicer_operation), A       ; 0 - write; 1 - read
    LD	(TM_VARS.tmp_slicer_can_read), A	; enable read fron disk
    LD	A, 0x2
    LD	(TM_VARS.tmp_slicer_flush), A	 ; disable flush data to disk
    JP	base_read_write

write_phys_op:
    XOR	A
    LD	(TM_VARS.tmp_slicer_operation), A
    LD	A, C
    LD	(TM_VARS.tmp_slicer_flush), A
    CP	0x2
    JP	NZ, LAB_ram_d7a0
    LD	A, 0x10			    ; 2048/128
    LD	(TM_VARS.slicer_uninited_count), A
    LD	A, (TM_VARS.cur_disk)
    LD	(TM_VARS.slicer_uninited_disk), A
    LD	A, (TM_VARS.curr_track)
    LD	(TM_VARS.slicer_uninited_track), A
    LD	A, (TM_VARS.curr_sec)
    LD	(TM_VARS.slicer_uninited_sector_128), A
LAB_ram_d7a0:
    LD	A, (TM_VARS.slicer_uninited_count)
    OR	A
    JP	Z,slicer_read_write
    DEC	A
    LD	(TM_VARS.slicer_uninited_count), A
    LD	A, (TM_VARS.cur_disk)
    LD	HL, TM_VARS.slicer_uninited_disk
    CP	(HL)
    JP	NZ,slicer_read_write
    LD	A, (TM_VARS.curr_track)
    LD	HL, TM_VARS.slicer_uninited_track
    CP	(HL)
    JP	NZ,slicer_read_write
    LD	A, (TM_VARS.curr_sec)
    LD	HL, TM_VARS.slicer_uninited_sector_128
    CP	(HL)
    JP	NZ,slicer_read_write
    INC	(HL)
    LD	A, (HL)
    CP	36				; Sectors per track
    JP	C,wpo_no_inc_track
    LD	(HL), 0x0
    LD	A, (TM_VARS.slicer_uninited_track)
    INC	A
    LD	(TM_VARS.slicer_uninited_track), A

wpo_no_inc_track:
    XOR	A
    LD	(TM_VARS.tmp_slicer_can_read), A
    JP	base_read_write

slicer_read_write:
    XOR	A
    LD	(TM_VARS.slicer_uninited_count), A
    INC	A
    LD	(TM_VARS.tmp_slicer_can_read), A

base_read_write:
    XOR	A
    LD	(TM_VARS.tmp_slicer_result), A
    LD	A, (TM_VARS.curr_sec)
    OR	A
    RRA
    OR	A
    RRA
    LD	(TM_VARS.tmp_slicer_real_sector), A
    LD	HL, TM_VARS.slicer_has_data
    LD	A, (HL)
    LD	(HL), 0x1
    OR	A
    JP	Z, LAB_ram_d825
    LD	A, (TM_VARS.cur_disk)
    LD	HL, TM_VARS.slicer_disk
    CP	(HL)
    JP	NZ, LAB_ram_d81e
    LD	A, (TM_VARS.curr_track)
    LD	HL, TM_VARS.slicer_track
    CP	(HL)
    JP	NZ, LAB_ram_d81e
    LD	A, (TM_VARS.tmp_slicer_real_sector)
    LD	HL, TM_VARS.slicer_real_sector
    CP	(HL)
    JP	Z,calc_sec_addr_in_bfr
LAB_ram_d81e:
    LD	A, (TM_VARS.slicer_need_save)
    OR	A
    CALL	NZ,slicer_save_buffer
LAB_ram_d825:
    LD	A, (TM_VARS.cur_disk)
    LD	(TM_VARS.slicer_disk), A
    LD	A, (TM_VARS.curr_track)
    LD	(TM_VARS.slicer_track), A
    LD	A, (TM_VARS.tmp_slicer_real_sector)
    LD	(TM_VARS.slicer_real_sector), A
    LD	A, (TM_VARS.tmp_slicer_can_read)
    OR	A
    CALL	NZ,slicer_read_buffer
    XOR	A
    LD	(TM_VARS.slicer_need_save), A

calc_sec_addr_in_bfr:
    LD	A, (TM_VARS.curr_sec)
    AND	0x3
    LD	L, A
    LD	H, 0x0
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    ADD	HL, HL
    LD	DE, TM_VARS.slicer_buffer
    ADD	HL, DE
    EX	DE, HL
    LD	HL, (TM_VARS.dma_addr)
    LD	C, 0x80
    LD	A, (TM_VARS.tmp_slicer_operation)
    OR	A
    JP	NZ,csa_no_save
    LD	A, 0x1
    LD	(TM_VARS.slicer_need_save), A
    EX	DE, HL
csa_no_save:
    LD	A, (DE)
    INC	DE
    LD	(HL), A
    INC	HL
    DEC	C
    JP	NZ,csa_no_save
    LD	A, (TM_VARS.tmp_slicer_flush)
    CP	0x1
    LD	A, (TM_VARS.tmp_slicer_result)
    RET	NZ
    OR	A
    RET	NZ
    XOR	A
    LD	(TM_VARS.slicer_need_save), A
    CALL	slicer_save_buffer
    LD	A, (TM_VARS.tmp_slicer_result)
    RET

slicer_save_buffer:
    CALL	slicer_get_floppy_args
    LD	C, 0xA4			    						; VG93 CMD
    CALL	MON_ENTRY.write_floppy
    LD	(TM_VARS.tmp_slicer_result), A
    RET

slicer_read_buffer:
    CALL	slicer_get_floppy_args
    LD	C, 0x84			    						; VG93 CMD
    CALL	MON_ENTRY.read_floppy
    LD	(TM_VARS.tmp_slicer_result), A
    RET

slicer_get_floppy_args:
    LD	HL,sector_128_interleave_b	    			;= 1h
    LD	A, (TM_VARS.slicer_real_sector)
    ADD	A, L
    LD	L, A
    LD	E, (HL)
    LD	A, (TM_VARS.slicer_track)
    LD	D, A
    LD	HL, TM_VARS.slicer_buffer
    LD	A, (TM_VARS.slicer_disk)
    RET

sector_128_interleave_b:
    db	1, 8, 6, 4, 2, 9, 7, 5, 3

; -------------------------------------------------------
; Print zerro ended string; HL -> string
; -------------------------------------------------------
print_strz:
    LD	A, (HL)
    OR	A
    RET	Z
    LD	C, A
    PUSH	HL
    CALL	conout_f
    POP	HL
    INC	HL
    JP	print_strz

msg_hello:
    db	ASCII_ESC, "60"		       					; Режим 32x18 <ESC>60
    db	ASCII_ESC, "8", 2       					; Выбор палтитры <ESC>82
    db	ASCII_ESC, "42"								; Выбор цвета <ESC>42
    db	"48K CP/M (V2.2) REL.7/2D\r\n64K RAM DISK (A:)\r\n180K FD (B:)\r\n", 0

dph:
    dw	0h				; Disk A
    dw	0h
    dw	0h
    dw	0h
    dw	0xBB3F
    dw	0xBB0E
    dw	0xBBDE
    dw	0xBBBF

dph1:
    dw	0h				; Disk B
    dw	0h
    dw	0h
    dw	0h
    dw	0xBB3F
    dw	0xBB1D
    dw	0xBC05
    dw	0xBBEE

dph2:
    dw	0h				; Disk C
    dw	0h
    dw	0h
    dw	0h
    dw	0xBB3F
    dw	0xBB1D
    dw	0xBC2C
    dw	0xBC15

dpb_192:
    dw	16				; Sector per track
    db	3				; block shift 3->1k
    db	7				; block mask: 7->1k
    db	0				; extent mask
    dw	63				; block count - 1
    dw	31				; Dir size - 1
    dw	80h			       ; Dir bitmap
    dw	8h				; checksum vector size
    dw	0h				; reserved

dpb_720:
    dw	36
    db	4
    db	15
    db	1
    dw	179
    dw	63
    dw	80h
    dw	10h
    dw	0h
    db	4h

; -------------------------------------------------------
; Filler to align blocks in ROM
; -------------------------------------------------------
LAST        EQU     $
CODE_SIZE   EQU     LAST-0xD600
FILL_SIZE   EQU     0x400-CODE_SIZE

	DISPLAY "| BIOS\t| ",/H,boot_f,"  | ",/H,CODE_SIZE," | ",/H,FILL_SIZE," |"

FILLER
    DS  FILL_SIZE, 0x00

	ENDMODULE

	IFNDEF	BUILD_ROM
		OUTEND
	ENDIF
