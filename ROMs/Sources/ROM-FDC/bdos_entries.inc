; =======================================================
; Ocean-240.2
; CP/M BDOS Entries to build other depended modules
;
; By Romych 2025-09-09
; ======================================================

	IFNDEF	_BDOS
	DEFINE	_BDOS

	MODULE	BDOS

bdos_enter		EQU	0xba06
bdos_compcol	EQU	0xba09
bdos_strtcol	EQU	0xba0a
bdos_column		EQU	0xba0b
bdos_listcp		EQU	0xba0c
bdos_kbchar		EQU 0xba0d

bdos_entrance	EQU 0xc811

	ENDMODULE

	ENDIF