# Ocean-240.2 ROM Sources

Source codes for personal computer Ocean-240.2 ROM (Z80 mnemonics, but limited for i8080 instruction set).

This version for Ocean-240.2 with Floppy controller.

1) 0xC000..0xDFFF	- CP/M v2.2
	Compile:
	sjasmplus --sld=cpm.sld --sym=cpm.labels --raw=cpm.obj --fullpath cpm.asm


2) 0xE000..0xFFFF - HW Monitor and Turbo Monitor
	Compile:
	sjasmplus --sld=turbo_mon.sld --sym=turbo_mon.labels --raw=turbo_mon.obj --fullpath turbo_mon.asm


To compile sources, use [sjasmplus Z80 assembler](https://github.com/z00m128/sjasmplus).