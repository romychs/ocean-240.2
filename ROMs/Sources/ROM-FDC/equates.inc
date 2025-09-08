; ======================================================
; Ocean-240.2
; Equates for all assembly sources
;
; By Romych 2025-09-09
; ======================================================

	IFNDEF	_EQUATES
	DEFINE	_EQUATES


ADDLIST				EQU	0x08
ASCII_BS			EQU	0x08
ASCII_CAN			EQU	0x18
ASCII_CR			EQU	0x0D
ASCII_EM			EQU	0x19
ASCII_ESC			EQU	0x1B
ASCII_FF			EQU	0x0C
ASCII_LF			EQU	0x0A
ASCII_SUB			EQU	0x1A
ASCII_TAB			EQU	0x09
ASCII_US			EQU	0x1F
; ------------------------------------------------------
BDOS_CTLC			EQU	0x03
BDOS_NFUNCS			EQU	0x29
BELL_CHAR			EQU	0x07
BELL_PIN			EQU	0x08
; ------------------------------------------------------
CCP_COMMAND_SIZE	EQU	0x05
CCP_COMMANDS_COUNT	EQU	0x04

CCP_SRC_ADDR		EQU	0xc000
CCP_DST_ADDR		EQU 0xb200
CCP_SIZE			EQU 0x809


CTL					EQU	0x5E
CTLC				EQU	0x03
CTLS				EQU	0x13
CTRL_C				EQU	0x03
; ------------------------------------------------------
DBPLIST				EQU	0x0F
DEF_DISK_A_SIZE		EQU	0x3F
DEF_DISK_B_SIZE		EQU	0x0168
DSK_MAP				EQU	0x10
DSK_MSK				EQU	0x03
DSK_SHF				EQU	0x02
DVERS				EQU	0x22
; ------------------------------------------------------
EMPTY				EQU	0xE5
ENDDIR				EQU	0xFFFF
ESC_CMD_END			EQU	0x1A
EXT_NUM				EQU	0x0C
; ------------------------------------------------------
FALSE				EQU	0x00
FCB_LEN				EQU	0x20
FCB_SHF				EQU	0x05
FDC_DD80RB			EQU	0x21
FDC_NOT_READY		EQU	0x80
FDC_RESTORE_L		EQU	0x08
FDC_SEEK_LV			EQU	0x1C
FWF_MASK			EQU	0x80
; ------------------------------------------------------
JP_OPCODE			EQU	0xC3
; ------------------------------------------------------
KBD_ACK				EQU	0x10
KBD_IRQ				EQU	0x02
KEY_ALF				EQU	0x0D
KEY_FIX				EQU	0x15
; ------------------------------------------------------
LST_REC				EQU	0x7F
; ------------------------------------------------------
MAX_EXT				EQU	0x1F
MAX_MOD				EQU	0x0F
MOD_NUM				EQU	0x0E
; ------------------------------------------------------
NAM_LEN				EQU	0x0F
NXT_REC				EQU	0x20
; ------------------------------------------------------
PIC_POLL_MODE		EQU	0x0A
PORT_C4				EQU	0x10
PRINTER_ACK			EQU	0x10
PRINTER_IRQ			EQU	0x08
; ------------------------------------------------------
RAN_REC				EQU	0x21
REC_CNT				EQU	0x0F
REC_SIZ				EQU	0x80
RO_FILE				EQU	0x09
RUB_OUT				EQU	0x7F
RX_READY			EQU	0x02
; ------------------------------------------------------
TAPE_D				EQU	0x08
TAPE_P				EQU	0x04
TIMER_IRQ			EQU	0x10
TL_HIGH				EQU	0x05
TL_LOW				EQU	0x03
TL_MID				EQU	0x04
TMR0_SQWAVE			EQU	0x36
TRUE				EQU	0xFF
TX_READY			EQU	0x01
; ------------------------------------------------------
U_BYTES				EQU	0x0D

	ENDIF