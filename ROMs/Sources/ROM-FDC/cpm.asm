; ======================================================
; Ocean-240.2
; CP/M Combine file. Includes all sources to build
; ROM 0xE000
;
; Disassembled by Romych 2025-09-09
; ======================================================

	DEFINE	BUILD_ROM

	DEVICE NOSLOT64K

;
;	|-----------|---------------|-----------|---------------------------------------|
;	| OFFSET	| SIZE			| Module	| Memory Address						|
;	|-----------|---------------|-----------|---------------------------------------|
;	| 0x0000	| 2048 (0x800)	| CCP_RAM	| 0xC000..0xC7FF -> RAM 0xB200..0xB5FF	|
;	| 0x0800	| 3584 (0xE00)	| BDOS		| 0xC800..								|
;	| 0x1600	| 1024 (0x400)	| BIOS		| 0xD600..D9FF							|
;	| 0x1B00	| 1280 (0x500)  | CCP_ROM	| 0xDB00..DFFF							|
;	|-----------|---------------|-----------|---------------------------------------|
;

    DISPLAY "|  Module\t|  Offset | Code   |  Free  |"
    DISPLAY "|-------------|---------|--------|--------|"


	OUTPUT cpm-C000.bin

	INCLUDE	"ccp_ram.asm"
	INCLUDE "bdos.asm"
	INCLUDE "bios.asm"
	INCLUDE "cpm_fill_1.asm"
	INCLUDE "ccp_rom.asm"

	OUTEND

	OUTPUT tm_vars.bin
		INCLUDE "tm_vars.inc"
	OUTEND


END