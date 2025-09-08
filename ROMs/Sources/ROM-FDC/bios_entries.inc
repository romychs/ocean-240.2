
; =======================================================
; Ocean-240.2
; Definition of CPM BIOS entries to compile depended
; modules
;
; By Romych 2025-09-09
; ======================================================
	IFNDEF  _BIOS
	DEFINE	_BIOS

	MODULE	BIOS

boot_f			EQU	0xD600
wboot_f			EQU	0xD603
const_f 		EQU	0xD606
conin_f			EQU	0xD609
conout_f		EQU	0xD60C
list_f			EQU	0xD60F
punch_f			EQU	0xD612
reader_f		EQU	0xD615
home_f			EQU	0xD618
seldsk_f		EQU	0xD61B
settrk_f		EQU	0xD61E
setsec_f		EQU	0xD621
setdma_f		EQU	0xD624
read_f			EQU	0xD627
write_f			EQU 0xD62A
sectran_f		EQU 0xD630
reserved_f1		EQU	0xD633
reserved_f2  	EQU	0xD636
tape_read_f		EQU	0xD639
tape_write_f	EQU	0xD63C
tape_wait_f		EQU 0xD63F

	ENDMODULE


	ENDIF
