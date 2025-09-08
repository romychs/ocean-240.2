; ======================================================
; Ocean-240.2
;
; Monitor entries to compile CP/M modules
;
; By Romych 2025-09-09
; ======================================================

	IFNDEF	_MON_ENTRY
	DEFINE	_MON_ENTRY

	MODULE	MON_ENTRY

mon_init		EQU 0xe000
mon_cold_start	EQU 0xe003
non_con_status	EQU 0xe006
mon_con_in		EQU 0xe009
mon_con_out		EQU 0xe00c
mon_serial_in	EQU 0xe00f
mpn_serial_out	EQU 0xe012
mon_char_print	EQU 0xe015
mon_tape_read	EQU 0xe018
mon_tape_write	EQU 0xe01b
ram_disk_read	EQU 0xe01e
ram_disk_write	EQU 0xe021
mon_res_f1		EQU 0xe024
mon_res_f2		EQU 0xe027
mon_tape_wait	EQU 0xe02a
mon_tape_detect	EQU 0xe02d
read_floppy		EQU 0xe030
write_floppy	EQU 0xe033

	ENDMODULE

	ENDIF