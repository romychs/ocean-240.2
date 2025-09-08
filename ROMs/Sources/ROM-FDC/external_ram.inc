; =======================================================
; Ocean-240.2
;
; External addresses references to build
; CP/M and HW-Monitor
; By Romych 2025-09-09
; =======================================================

	IFNDEF	_EXT_RAM
	DEFINE	_EXT_RAM

	MODULE	EXT_RAM

JP_WBOOT			EQU 0x0000
wboot_addr			EQU 0x0001
bdos_ioloc			EQU 0x0003
cur_user_no			EQU 0x0004
jp_bdos_enter		EQU 0x0005
BDOS_ENT_ADDR		EQU 0x0006
RST1				EQU 0x0008
RST1_handler_addr	EQU 0x0009
RST2				EQU 0x0010
RST3				EQU 0x0018
RST4				EQU 0x0020
RST5				EQU 0x0028
RST6				EQU 0x0030
RST7				EQU 0x0038
reserve1			EQU 0x003b
bios_var1			EQU 0x0041
bios_var2			EQU 0x0042
bios_var3			EQU 0x0043
reserve2			EQU 0x0050
FSR_STD				EQU 0x005c
NMI_ISR				EQU 0x0066
FSB_R0				EQU 0x007d
FSB_R1				EQU 0x007e
FSB_R2				EQU 0x007f
std_dma_buff		EQU 0x0080
;std_dma_buff+1		EQU 0x0081
;std_dma_buff_82	EQU 0x0082
;std_dma_buff_83	EQU 0x0083
;std_dma_buff+12	EQU 0x008c
fcb_ra_record_num	EQU 0x00a1
loaded_program		EQU	0x0100
video_ram			EQU	0x4000

	ENDMODULE

	ENDIF