; =======================================================
; Ocean-240.2
; Computer with FDC variant.
; IO Ports definitions
;
; By Romych 2025-09-09
; =======================================================

	IFNDEF _IO_PORTS
	DEFINE _IO_PORTS

; -------------------------------------------------------
; КР580ВВ55 DD79
; -------------------------------------------------------
; Port A - User port A
USR_DD79PA		EQU	0x00

; Port B - User port B
USR_DD79PB		EQU	0x01

; Port C - User port C
USR_DD79PC		EQU 0x02

;  Config: [1][ma1,ma0][0-aO|1-aI],[0-chO,1-chI],[mb],[0-bO|1-bI],[0-clO,1-clI]
; Set bit: [0][xxx][bbb][0|1]
USR_DD79CTR		EQU	0x03

; -------------------------------------------------------
; КР1818ВГ93
; -------------------------------------------------------
; CMD
FDC_CMD			EQU 0x20

; TRACK
FDC_TRACK		EQU 0x21

; SECTOR
FDC_SECT		EQU 0x22

; DATA
FDC_DATA		EQU 0x23

;
FDC_WAIT		EQU 0x24

; Controller port
FLOPPY			EQU 0x25


; -------------------------------------------------------
; КР580ВВ55 DD78
; -------------------------------------------------------
; Port A - Keyboard Data
KBD_DD78PA		EQU 0x40

; Port B - JST3,SHFT,CTRL,ACK,TAPE5,TAPE4,GK,GC
KBD_DD78PB		EQU 0x41

; Port C - [PC7..0]
KBD_DD78PC		EQU 0x42

;  Сonfig: [1][ma1,ma0][0-aO|1-aI],[0-chO,1-chI],[mb],[0-bO|1-bI],[0-clO,1-clI]
; Set bit: [0][xxx][bbb][0|1];
KBD_DD78CTR		EQU	0x43


; -------------------------------------------------------
; КР580ВИ53 DD70
; -------------------------------------------------------
; Counter 1
TMR_DD70C1		EQU 0x60

; Counter 2
TMR_DD70C2		EQU	0x61

; Counter 3
TMR_DD70C3		EQU	0x62

; Config: [sc1,sc0][rl1,rl0][m2,m1,m0][bcd]
;  sc - timer, rl=01-LSB, 10-MSB, 11-LSB+MSB
;  mode 000 - int on fin,
;       001 - one shot,
;       x10 - rate gen,
;       x11-sq wave
TMR_DD70CTR		EQU	0x63

; Programable Interrupt controller PIC  KR580VV59
PIC_DD75RS		EQU	0x80
PIC_DD75RM		EQU	0x81

; -------------------------------------------------------
; КР580ВВ51 DD72
; -------------------------------------------------------
; Data
UART_DD72RD		EQU	0xA0

; [RST,RQ_RX,RST_ERR,PAUSE,RX_EN,RX_RDY,TX_RDY]
UART_DD72RR		EQU	0xA1

; -------------------------------------------------------
; КР580ВВ55 DD17
; -------------------------------------------------------
; Port A - VShift[8..1]
SYS_DD17PA		EQU	0xC0

; Port B - [ROM14,13][REST][ENROM-][A18,17,16][32k]
SYS_DD17PB		EQU	0xC1

; Port C - HShift[HS5..1,SB3..1]
SYS_DD17PC		EQU	0xC2

;  Сonfig: [1][ma1,ma0][0-aO|1-aI],[0-chO,1-chI],[mb],[0-bO|1-bI],[0-clO,1-clI]
; Set bit: [0][xxx][bbb][0|1];
SYS_DD17CTR		EQU	0xC3

; -------------------------------------------------------
; КР580ВВ55 DD67
; -------------------------------------------------------
; Port A - LPT Data
LPT_DD67PA		EQU	0xE0

; Port B - [VSU,C/M,FL3..1,COL3..1]
VID_DD67PB		EQU	0xE1

; Port C - [USER3..1,STB-LP,BELL,TAPE3..1]
DD67PC			EQU 0xE2

;  Сonfig: [1][ma1,ma0][0-aO|1-aI],[0-chO,1-chI],[mb],[0-bO|1-bI],[0-clO,1-clI]
; Set bit: [0][xxx][bbb][0|1];
DD67CTR			EQU 0xE3

	ENDIF