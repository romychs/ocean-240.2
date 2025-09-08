; =======================================================
; Ocean-240.2
; Module TM_VARS - Turbo monitor variables
; RAM Range: 0xBA09-0xBFFF
;
; Disassembled by Romych 2025-09-09
; =======================================================

	IFNDEF	_TM_VARS
	DEFINE	_TM_VARS

	MODULE TM_VARS
	ORG	0xBA09

bdos_compcol	db	0
bdos_strtcol	db	0
bdos_column		db	0
bdos_listcp		db	0
bdos_kbchar		db	0
bdos_entsp		ds	42, 0				; 0xba0e
BYTE_ram_ba38	dw	0
BYTE_ram_ba3a	dw	0
BYTE_ram_ba3c	dw  0
BYTE_ram_ba3e	dw	0

; -------------------------------------------------------
; Common values shared between bdosi and bdos
; -------------------------------------------------------

; current user number
bdos_usercode	db 0x00					; 0xba40

; current disk number
bdos_curdsk		db 0x00

; Information address
bdos_info		dw 0x0000				; 0xba42

; address value to return
bdos_aret		dw 0x0000				; 0xba44
bdos_efcb		db 0x00					; 0xba46
bdos_rodsk		db 0x00					; 0xba47
BYTE_ram_ba48	db 0x00					; 0xba48
bdos_dlog		dw 0x0000				; 0xba49
bdos_dmaad		dw 0x0000				; 0xba4b
bdos_cdrmaxa	dw 0x0000				; 0xba4d
bdos_curtrka	dw 0x0000				; 0xba4f
bdos_curreca	dw 0x0000				; 0xba51
bdos_buffa		db 0x00					; 0xba53
BYTE_ram_ba54	db 0x00					; 0xba54
bdos_dpbaddr	dw 0x0000				; 0xba55
BYTE_ram_ba57	dw 0x0000				; 0xba57
bdos_alloca		dw 0x0000				; 0xba59
dbos_sectpt		dw 0x0000				; 0xba5b
bdos_blkshf		db 0x00					; 0xba5d
bdos_blmsk		db 0x00					; 0xba5e
bdos_extmsk		db 0x00					; 0xba5f
bdos_maxall		dw 0x0000				; 0xba60
bdos_dirmax		dw 0x0000				; 0xba62
bdos_dirblk		dw 0x0000				; 0xba64
BYTE_ram_ba66	dw 0x0000				; 0xba66
bdos_offset		dw 0x0000				; 0xba68
bdos_tranv		dw 0x0000				; 0xba6a
bdos_fcb_copied	db 0x00					; 0xba6c
bdos_rfm		db 0x00					; 0xba6d
bdos_dirloc		db 0x00					; 0xba6e
bdos_seqio		db 0x00					; 0xba6f
bdos_linfo		db 0x00					; 0xba70
bdos_dminx		db 0x00					; 0xba71
bdos_searchl	db 0x00					; 0xba72
bdos_searcha	dw 0x0, 0x0				; 0xba73
bdos_single		db 0x00					; 0xba77
bdos_resel		db 0x00					; 0xba78
bdos_olddsk		db 0x00					; 0xba79
bdos_fcbdsk		db 0x00					; 0xba7a
bdos_rcount		db 0x00					; 0xba7b
bdos_extval		db 0x00					; 0xba7c
bdos_vrecord	dw 0x0000				; 0xba7d
bdos_arecord	db 0x00					; 0xba7f
BYTE_ram_ba80	db 0x00					; 0xba80
bdos_arecord1	dw 0x0000				; 0xba81
bdos_dptr		db 0x00					; 0xba83
bdos_dcnt		db 0x00					; 0xba84
bdos_dcnt_hi	db 0x00					; 0xba85
bdos_drec		ds 20, 0x00				; 0xba86
tmp_dir_total	dw 0x0000				; 0xba9a
saved_stack_ptr	ds 22, 0x00				; 0xba9c
WORD_ram_bab2	dw 0x0000				; 0xbab2
safe_stack_ptr	dw 0x0000				; 0xbab4

; --------------------------------------------------
; FCB
; --------------------------------------------------
; FCB offset 0 - drive letter to write file
ccp_FCB			db 0x00					; 0xbab6
; filename to write file
ccp_FCB_fn		ds 31,0x00				; 0xbab7

ccp_FCB_CR		db 0x00								; Current record
cco_FCB_Rn		db 0x00								; Random access record number
				dw 0x00
				dw 0x00
				dw 0x00

DPH_base		ds 78, 0x00				; 0xbade
cur_disk		db 0x00					; 0xbb2c
dma_addr		dw 0x0000				; 0xbb2d
curr_track		db 0x00					; 0xbb2f
curr_sec		db 0x00					; 0xbb30
slicer_disk		db 0x00					; 0xbb31
slicer_track	db 0x00					; 0xbb32
slicer_real_sector	db 0x00				; 0xbb33
tmp_slicer_real_sector	db 0x00			; 0xbb34
slicer_has_data	db 0x00					; 0xbb35
slicer_need_save	db 0x00				; 0xbb36

slicer_uninited_count	db 0x00			; 0xbb37
slicer_uninited_disk	db 0x00			; 0xbb38
slicer_uninited_track	db 0x00			; 0xbb39
slicer_uninited_sector_128	db 0x00		; 0xbb3a
tmp_slicer_result	db 0x00				; 0xbb3b
tmp_slicer_can_read	db 0x00				; 0xbb3c
tmp_slicer_operation	db 0x00			; 0xbb3d
tmp_slicer_flush	db 0x00				; 0xbb3e
				ds 449, 0x00
slicer_buffer	ds 512, 0x00			; 0xbd00

tm_stack		ds 80, 0x00				; 0xbf00 search text or buffer to search?
tm_ltb 			ds 32, 0x00				; 0xbf50
tm_strt			ds 16, 0x00				; 0xbf70
tm_track_no		db 0x00					; 0xbf80
tm_sector_no	db 0x00					; 0xbf81
tm_num_sect		db 0x00					; 0xbf82
tm_disk_op		db 0x00					; 0xbf83
tm_rw_disk		db 0x00					; 0xbf84
tm_drive		dw 0x00					; 0xbf85
tm_tbu			db 0x00					; 0xbf87

; user entered command buffer
tm_hrg			ds 48, 0x00				; 0xbf88
tm_stack_top	dw 0x0000				; 0xbfb8
tm_stsp			dw 0x0, 0x0, 0x0		; 0xbfba
rst_af_save		dw 0x0000				; 0xbfc0
rst_bc_save		dw 0x0000				; 0xbfc2
rst_de_save		dw 0x00					; 0xbfc4
rst_hl_save		dw 0x00					; 0xbfc6
rst_sp_save		dw 0x0000				; 0xbfc8
rst_ret_JP		db 0x00					; 0xbfca
rst_ret_addr	dw 0x00					; 0xbfcb
				db 0
				dw 0x00, 0x00
tm_stack_0	    dw 0x00, 0x00			; 0xbfd2
				db 0x00					; 0xbfd6
				dw 0x0000				; 0xbfd7
m_esc_mode		db 0x00					; 0xbfd9
m_esc_cmd		db 0x00					; 0xbfda
m_esc_param_cnt	db 0x00					; 0xbfdb
m_esc_param_1	db 0x00					; 0xbfdc
m_esc_param_2	db 0x00					; 0xbfdd
m_esc_param_3	db 0x00					; 0xbfde
m_esc_param_4	db 0x00					; 0xbfdf
m_esc_hex_cmd	db 0x00					; 0xbfe0
m_esc_param_6	db 0x00					; 0xbfe1
				ds 4, 0x00				; 0xbfe2
m_screen_mode	db 0x00					; 0xbfe6
m_cursor_row	db 0x00					; 0xbfe7
m_cursor_col	db 0x00					; 0xbfe8
m_curr_color	dw 0x0000				; 0xbfe9
m_row_shift		db 0x00					; 0xbfeb
m_codepage		db 0x00					; 0xbfec
m_cur_palette	db 0x00					; 0xbfed
m_beep_period	dw 0x0000				; 0xbfee
m_beep_duration	dw 0x0000				; 0xbff0
m_pix_shift		db 0x00					; 0xbff2
m_strobe_state	db 0x00					; 0xbff3
m_print_pos_x	dw 0x0000				; 0xbff4
				dw 0x0000
				dw 0x0000
m_last_key		db 0x00					; 0xbffa
m_last_shifts	db 0x00					; 0xbffb
mc_fix_state	db 0x00					; 0xbffc
mc_stored_key	db 0x00					; 0xbffd

	ASSERT tm_stack_top   = 0xbfb8
	ASSERT tmp_dir_total  = 0xba9a
	ASSERT saved_stack_ptr= 0xba9c
	ASSERT WORD_ram_bab2  = 0xbab2
	ASSERT ccp_FCB_fn     = 0xbab7
	ASSERT DPH_base       = 0xbade
	ASSERT slicer_uninited_count = 0xbb37
	ASSERT slicer_buffer  = 0xbd00
	ASSERT tm_stack       = 0xbf00
	ASSERT tm_hrg         = 0xbf88
	ASSERT rst_hl_save    = 0xbfc6
	ASSERT rst_ret_addr	  =  0xbfcb
	ASSERT tm_stack_0     = 0xbfd2
	ASSERT m_esc_mode 	  = 0xbfd9
	ASSERT m_screen_mode  = 0xbfe6
	ASSERT mc_stored_key  = 0xbffd

	; DISPLAY " BYTE_ram_bfd2 is: ", BYTE_ram_bfd2
	; DISPLAY "     m_esc_mode is: ", m_esc_mode
	; DISPLAY "   rst_ret_addr is: ", rst_ret_addr
	; DISPLAY " tm_stack_top is: ", tm_stack_top
	; DISPLAY " mc_stored_key is: ", mc_stored_key

	ENDMODULE

	ENDIF