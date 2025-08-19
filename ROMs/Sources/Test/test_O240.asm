; =======================================================
; Исходный текст тестового ПЗУ ПК "Океан 240.2"
; Дизасемблировал Romych, 2025-08-20
; в мнемонике ассемблера Z80 в фомате sjasmplus
; =======================================================

			DEVICE NOSLOT64K

; КР580ВВ55 System
DD17RA		EQU		0xC0							; VShift[8..1]
DD17RB		EQU		0xC1							; [A14,A13,REST,ENROM,A18,A17,A16,32K]
DD17RC		EQU		0xC2							; HShift[HS5..1,SB3..1]
DD17RR		EQU		0xC3							; VV55 Sys CTR

; КР580ВВ55 LPT/Video/Tape
DD67RA		EQU		0xE0							; [LP7..0]
DD67RB		EQU		0xE1							; [VSU,C/M,FL3..1,COL3..1]
DD67RC		EQU		0xE2							; [USER3..1,STB-LP,BELL,TAPE3..1]
DD67RR		EQU		0xE3							; VV55 Video CTR

; КР580ВИ53
DD70C1		EQU		0x60							; VI53 TIM/CTR1
DD70C2		EQU		0x61							; VI53 TIM/CTR2
DD70C3		EQU		0x62							; VI53 TIM/CTR3
DD70RR		EQU		0x63							; VI53 TIM CTR

; КР580ВВ51
DD72RD		EQU		0xA0							; VV51
DD72RR		EQU		0xA1							; VV51 [RST,RQ_RX,RST_ERR,PAUSE,RX_EN,RX_RDY,TX_RDY]

; КР580ВН59
DD75RS		EQU		0x80							; VN59
DD75RM		EQU		0x81							; VN59

; КР580ВВ55 Порты A и С, B5-7 - Клавиатура
DD78RA		EQU		0x40							; VV55 [Keyboard]
DD78RB		EQU		0x41							; [JST3..1,ACK,TAPE5,TAPE4,GK,GC]
DD78RC		EQU		0x42							; VV55 [PC7..0]
DD78RR		EQU		0x43							; VV55 KBD CTL

; КР580ВВ55 Для внешних устройств пользователя
DD79RA		EQU		0x00							; VV55 User PA
DD79RB		EQU		0x01							; VV55 User PB
DD79RC		EQU		0x02							; VV55 User PC
DD79RR		EQU		0x03							; VV55 User CTR

; КР580ВВ55 Для устройств пользователя или FDC
DD80RA		EQU		0x20							; VV55 FDC PA
DD80RB		EQU		0x21							; VV55 FDC PB
DD80RC		EQU		0x22							; VV55 FDC PC
DD80RR		EQU		0x23							; VV55 FDC CTR

; Паттерны тестирования памяти
PATTERN1	EQU		0x55FF
PATTERN2	EQU		0x00FF
PATTERN3	EQU		0xFF00

; Размер блока
B32K		EQU		0x8000
B48K		EQU		0xC000

; Задержки
DELAY1		EQU		0xFFFF							; задержка
W_BUSY		EQU		0x9C40							; таймаут ожидания готовности принтера
W_BUTN		EQU		0xC350							; таймаут отпускания клавиши S1

; Переменные для прерывания
T_STACK		EQU		0x100							; временный стек для прерывания
INT_CALL	EQU		0x20							; код инструкции перехода
INT_ADDR	EQU		0x21							; адрес обработчика прерывания

; Флаги статуса ВВ51
TX_RDY		EQU		0x01							; передатчик готов
RX_RDY		EQU		0x02							; приемник готов
; TX_EMPTY	EQU		0x04							; буфер передатчика пуст
; TX_PE		EQU		0x08							; Parity error
; TX_OE		EQU		0x01							; Overrun error
; TX_FE		EQU		0x02							; Framing error
; TX_DSR	EQU		0x08

; Биты порта чтения с магнитофона
TAPE_4		EQU		0x04
TAPE_5		EQU		0x08

; Флаги прерывания ВН59
RST_1		EQU		0x02
RST_2		EQU		0x04
RST_3		EQU		0x08

; Бит порта строба клавиатуры
KBD_ACK		EQU		0x80

; Флаг гашения кадра
BIT_GK		EQU		0x02							; бит гашения кадра


; =======================================================
; Код теста в памяти располагается с адреса 0xE000
; =======================================================

			ORG 	0xE000

	JP	  	TEST1
; -------------------------------------------------------
; TEST 1	Программирование портов ВВ55, Таймера ВИ53,
;			Последовательного порта ВВ51
; -------------------------------------------------------
TEST1
	DI
	; Программирование ВВ55
	LD		A, 0x80									; 1000 0000 -> PA mode 0 out, PC out, PB mode 0 out
	OUT		(DD17RR), A								; mem
	OUT		(DD67RR), A								; video
	OUT		(DD80RR), A								; user

	LD		A, 0x93									; 1001 0011 -> PA mode 0 inp, PB mode 0 inp, PC hi out, PC lo inp
	OUT		(DD78RR), A
	LD		A, 0x47									; 0100 0111 -> VSU=0, C/M=1, FL=000, COL=111
	OUT		(DD67RB), A
	LD		A, 0x07									; 0000 0111 -> H Shift HS=00000, SB=111
	OUT		(DD17RC), A
	LD		A, 0x04									; 0000 0100 -> TAPE3 = 1
	OUT		(DD67RC), A

	; Программирование порта ВВ51
	LD		A, 0xCE								; 1100 1110 -> Mode: 11 - 2S, 00-N, 11-8b, 76.8КГц/16=4800 бод
	OUT		(DD72RR), A
	LD		A, 0x25								; 0010 0101 -> 0-Norm, 0-No Rst, 1-RTS-=0, 0-No Err, 0-No brk, 1-RxEn, 0-DTR-=1, 1-TxEn
	OUT		(DD72RR), A

	; Программирование таймера ВИ53
	LD		A, 0x76								; 0111 0110 -> 01-CTR2, 11-LSB+MSB, 011-square wave gen, 0-binary
	OUT		(DD70RR), A
	LD		A, 20								; 1.536MHz/20=76.8КГц  -> /16=4800 бод
	OUT		(DD70C2), A
	LD		A, 0x00
	OUT		(DD70C2), A

	; Программирование rонтроллера прерываний ВН59
	LD		A, 0x12								; ICW1 (D4=1) 0001 0010 -> D1=1 - Single mode
	OUT		(DD75RS), A
	LD		A, 0x00								; ICW2 Interrup vector address = 0000
	OUT		(DD75RM), A
	LD		A, 0xFF								; OCW1 1111 1111 -> Маскируем все прерывания
	OUT		(DD75RM), A
	LD		A, 0x20								; OCW2 0010 0000 -> 001 - Non-specific EOI command, 000 - Active IR Level 0
	OUT		(DD75RS), A
	LD		A, 0x0A								; OCW3 0000 1010 -> D3=1 Pool command, 01-No OP, RIS=0
	OUT		(DD75RS), A

	LD		SP, TEST1_1							; возврат на TEST2
	LD		D, 0x00								; 0 - passed ok
	LD		E, 0x01								; номер теста
	JP		MSG

TEST1_1
	; инкремент данных на пользовательском порту
	LD		A, D
	OUT		(DD80RA), A
	OUT		(DD80RB), A
	OUT		(DD80RC), A
	INC		D
	; проверка нажатия SA1
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, TEST1_1

	XOR		A
	OUT		(DD80RA), A
	OUT		(DD80RB), A
	OUT		(DD80RC), A

	LD		SP, TEST2
	JP		WAIT_BTN

; -------------------------------------------------------
; Тест 2 	Проверка работы устройства отображения
; -------------------------------------------------------
TEST2
	; вкл доступа к видео-ЗУ
	LD		A, 0x01
	OUT		(DD17RB), A
	; вывод шахматки
	LD		C, 0x00
T4C
	LD		A, C
	AND		0x07
	LD		B, A
	LD		A, C
	RRA
	RRA
	RRA
	AND		0x01
	ADD		A, B
	LD		DE, 0x00
	RRA
	JP		NC, T46
	LD		DE, PATTERN1
	OR		A
	JP		Z, T46
	LD		DE, PATTERN2
	CP		0x01
	JP		Z, T46
	LD		DE, PATTERN3
	CP		0x02
	JP		Z, T46
	LD		E, 0xff
T46
	LD		A,C
	AND		0x7
	ADD		A,A
	ADD		A,A
	ADD		A,A
	ADD		A,A
	ADD		A,A
	LD		L,A
	LD		B,0x20
T4B
	LD		A,C
	AND		0xf8
	ADD		A,0x40
	LD		H,A
	LD		A,0x4
T4A
	LD		(HL),E
	INC		H
	LD		(HL),D
	INC		H
	DEC		A
	JP		NZ,T4A
	INC		L
	DEC		B
	JP		NZ,T4B
	INC		C
	LD		A,C
	CP		0x40
	JP		NZ, T4C
	; нормальный маппинг ОЗУ/ПЗУ
	LD		A, 0x0
	OUT		(DD17RB), A

	LD		A, 0x40								; 0100 000 - Color mode ON
	OUT		(DD67RB),A
	LD		E, 0x0
	LD		D, 0x0
T57
	LD		BC, B48K
T4E
	DEC		BC
	LD		A,B
	OR		C
	JP		NZ,T4E
	LD		C, 0x80

	; ждем GK - гашение кадра
T2_WAIT_GK
	IN		A, (DD78RB)
	AND		BIT_GK
	JP		NZ, T2_WAIT_GK

T2_WAIT_N_GK
	IN		A, (DD78RB)
	AND		BIT_GK
	JP		Z, T2_WAIT_N_GK

	LD		A, E
	RRA
	JP		C, T51
	INC		D
	JP		T52
T51
	DEC		D
T52
	RRA
	JP		C, T53
	LD		A,D
	; горизонтальный битовый сдвиг
	ADD		A, 0x7
	OUT		(DD17RC), A
	JP		T54
T53
	LD		A,D
	; вертикальный сдвиг
	OUT		(DD17RA), A
T54
	DEC		C
	JP		NZ, T2_WAIT_GK
	LD		BC, B48K
T55
	DEC		BC
	LD		A,B
	OR		C
	JP		NZ, T55
	INC		E
	LD		A, E
	CP		0x4
	JP		P, T56
	OR		0x40									; 0100 000
	OUT		(DD67RB), A
	JP		T57
T56
	; Доступ к старшим 32К доп. ОЗУ
	LD		A, 0x3
	OUT		(DD17RB), A
	LD		C, 0x00
	; шахматка в mono режиме
T5B
	LD		A, C
	AND		0x07
	LD		B, A
	LD		A, C
	RRA
	RRA
	RRA
	AND		0x01
	ADD		A, B
	LD		D, 0x00
	RRA
	JP		NC, T58
	LD		D, 0xff
T58
	LD		A, C
	AND		0x07
	ADD		A, A
	ADD		A, A
	ADD		A, A
	ADD		A, A
	ADD		A, A
	LD		L, A
	LD		B, 0x20
T5A
	LD		A, C
	AND		0xF8
	ADD		A, 0x40
	LD		H, A
	LD		A, 0x04
T59
	LD		(HL), D
	INC		H
	LD		(HL), D
	INC		H
	DEC		A
	JP		NZ, T59
	INC		L
	DEC		B
	JP		NZ, T5A
	INC		C
	LD		A,C
	CP		0x40
	JP		NZ, T5B

	; Нормальный режим работы памяти
	LD		A, 0x00
	OUT		(DD17RB),A

	LD		A, 0x80								; 1000 0000 - VSU=1  Mono
	OUT		(DD67RB), A
	LD		E, 0x00
T5E
	LD		BC, DELAY1
T2_DLY2
	DEC		BC
	LD		A, B
	OR		C
	JP		NZ, T2_DLY2

	LD		A, E
	ADD		A, A
	ADD		A, A
	ADD		A, A
	OR		0x80
	OUT		(DD67RB), A							; VSU=1
	INC		E
	LD		A, E
	CP		0x07
	JP		C, T5E
	LD		SP, T2_W_S2
	LD		D, 0x00								; ok
	LD		E, 0x02								; test #2
	JP		MSG

T2_W_S2
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T2_W_S2

	LD		SP, TEST3
	JP		WAIT_BTN

;-------------------------------------------------------
; Тест3	Проверка ШД ОЗУ
; 	проверка шины данных ОЗУ) выполняет последовательную
;	проверку ячеек ОЗУ на соответствие записываемых и
;	считываемых 8-разрядных слов (для значений 00H и FFH)
;-------------------------------------------------------
TEST3
	LD		A, 0xC0								; 1100 0000 VSU=1 Color mode
	OUT		(DD67RB),A
	LD		E, 0x00
T3_TEST_PAGE
	LD		A, E
	; выбор режима доступа к озу
	AND		0x03
	OUT		(DD17RB), A
	LD		HL, 0x0000
	LD		BC, B32K
	; проверка записи и чтения ячейки ОЗУ
T3_TEST_CELL
	LD		(HL), 0x00
	LD		A, (HL)
	CP		0x00
	JP		NZ, T3_TEST_ERR

	LD		(HL), 0xFF
	LD		A, (HL)
	CP		0xFF
	JP		NZ, T3_TEST_ERR

	INC		HL									; addr++
	DEC		BC									; counter--
	LD		A, B
	OR		C
	JP		NZ, T3_TEST_CELL
	; переход к следующему банку ОЗУ
	INC		E
	LD		A, E
	; если E=4, закончим
	CP		0x04
	JP		M, T3_TEST_PAGE
	; тест успешен, вывод сообщения
	LD		D, 0x00
	LD		E, 0x03
	LD		SP, TEST4
	JP		MSG

	; тест ОЗУ завершен ошибкой
T3_TEST_ERR
	LD		A, E
	AND		0x01
	RRA
	RRA
	ADD		A, H
	LD		H, A
	LD		A, E
	LD		SP, T3_ERR_CONT
	; 0-осн. 1-доп ОЗУ
	AND		0x02
	LD		D, 0x01
	JP		Z, T3_EPN3
	LD		D, 0x05
T3_EPN3
	LD		E, 0x03
	JP		MSG

T3_ERR_CONT
	EX		DE, HL
	LD		A, H
	AND		0x7F
	LD		H, A

	; запись/чтение в ошибочную ячеку памяти и ожидание кнопки S1
T4_WR_WS1
	LD		(HL), 0x00
	LD		A, (HL)
	LD		(HL), 0xFF
	LD		A, (HL)
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T4_WR_WS1

	; обычный режим памяти
	LD		A, 0x00
	OUT		(DD17RB), A
	JP		T4_L1

;-------------------------------------------------------
; Тест 4	Проверка адресов и регенерации ОЗУ
;-------------------------------------------------------
TEST4

	; обычный режим памяти
	LD		A, 0x00
	OUT		(DD17RB), A
T4_WS1
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T4_WS1

T4_L1
	LD		SP, T4_L2
	JP		WAIT_BTN

T4_L2
	LD		E, 0x0

T4_W_PG
	LD		A, E
	; выбор страницы ОЗУ
	AND		0x03
	OUT		(DD17RB), A
	LD		HL, 0x0000
	LD		BC, B32K

T4_W_FN
	; value = (Addr AND 0FFH) + (Addr/8)
	LD		A, E
	AND		0x01
	RRA
	RRA
	ADD		A, H
	ADD		A, L
	LD		(HL), A
	INC		HL											; addr++
	DEC		BC											; ctr++
	LD		A,B
	OR		C
	JP		NZ,T4_W_FN

	INC		E
	LD		A,E
	CP		0x4
	JP		M, T4_W_PG

	; ожидание 0,5 сек
	LD		BC,DELAY1
T4_WS2
	DEC		BC
	LD		A, B
	OR		C
	JP		NZ, T4_WS2

	; чтение записанного, после паузы, проверка refresh
	LD		E, 0x00
T4_R_PG
	LD		A, E
	AND		0x03
	; выбор страниц ОЗУ
	OUT		(DD17RB), A
	LD		HL, 0x0000
	LD		BC, B32K
T4_R_FN
	LD		A, E
	AND		0x01
	RRA
	RRA
	ADD		A,H
	ADD		A,L
	; прочитали то, что писали?
	CP		(HL)
	JP		NZ, T4_R_ERR
	INC		HL											; addr++
	DEC		BC											; ctr--
	LD		A,B
	OR		C
	JP		NZ, T4_R_FN

	INC		E
	LD		A,E
	CP		0x04
	JP		M,T4_R_PG

	; тест завершен, нормальноая адресация ОЗУ
	LD		A, 0x00
	OUT		(DD17RB),A
	; вывод результата теста 4 ok
	LD		D, 0x00
	LD		E, 0x04
	LD		SP, TEST5
	JP		MSG

	; вывод ошибки теста 4
T4_R_ERR
	; установка флага осн/доп ОЗУ
	LD		A, E
	AND		0x01
	RRA
	RRA
	ADD		A, H
	LD		H, A
	LD		A, E
	LD		SP, TEST5
	AND		0x02
	LD		D, 0x01
	JP		Z, T4_EPN3
	LD		D, 0x05
T4_EPN3
	LD		E, 0x04
	JP		MSG

;-------------------------------------------------------
; Тест 5	Запись на кассетный магнитофон тестового
;			сигнала
;-------------------------------------------------------
TEST5
	; обычный режим памяти
	LD		A, 0x0
	OUT		(DD17RB), A

T5_W_S1
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T5_W_S1

	LD		SP, T5_L1
	JP		WAIT_BTN

T5_L1
	LD		B, 0x04
T5_L2
	LD		C, 0x06
	LD		DE, T5_L5
T5_L3
	LD		A, (DE)
T5_L4
	ADD		HL, HL
	ADD		HL, HL
	DEC		H
	NOP
	NOP
	DEC		A
	JP		NZ, T5_L4

	LD		A, B
	XOR		0x02
	LD		B, A
	; вывод данных на ленту
	OUT		(DD67RC), A
	INC		DE
	DEC		C
	JP		NZ, T5_L3
	IN		A, (DD72RR)
	AND		0x2
	JP		Z, T5_L2
	LD		D, 0x0
	LD		E, 0x5
	LD		SP, TEST6
	JP		MSG

T5_L5
	DB	0x0F, 0x07, 0x0F, 0x0B, 0x07, 0x44

;-------------------------------------------------------
; Тест 6 	проверка правильности настройки усилителя-
;			формирователя (УФ) считывания
;-------------------------------------------------------
TEST6
	LD		SP, T6_L1
	JP		WAIT_BTN

	; ожидание паузы при чтении с ленты
T6_L1
	IN		A, (DD78RB)
	AND		TAPE_4
	LD		B, A
T6_L2
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END

	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L2
	LD		B, A
T6_INT_NXT
	LD		C, 0x00
T6_L4
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END									; лишнее

	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L4
	LD		B, A
	LD		A, C
	CP		0x19
	JP		C, T6_INT_NXT
	LD		C, 0x00

T6_L5
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END

	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L5

	LD		B,A
	LD		A,C
	CP		0x09
	JP		C, T6_INT_ERR
	CP		0x09
	JP		C, T6_INT_ERR
	LD		C, 0x00

T6_L6
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END

	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L6

	LD		B, A
	LD		A, C
	CP		0x07
	JP		NC, T6_INT_ERR
	CP		0x07
	JP		NC, T6_INT_ERR
	LD		C, 0x00

T6_L7
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END
	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L7

	LD		B, A
	LD		A, C
	CP		0x09
	JP		C, T6_INT_ERR
	CP		0x09
	JP		C, T6_INT_ERR
	LD		C, 0x00

T6_L9
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END

	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L9
	LD		B, A
	LD		A, C
	CP		0x09
	JP		NC, T6_INT_ERR
	CP		0x07
	JP		C, T6_INT_ERR
	LD		C, 0x00

T6_L10
	INC		C
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T6_END
	JP		NZ, T6_END
	IN		A, (DD78RB)
	AND		TAPE_4
	CP		B
	JP		Z, T6_L10
	LD		B, A
	LD		A, C
	CP		0x07
	JP		NC, T6_INT_ERR
	LD		E, '+'
	JP		T6_W_TX

	; вывод '-' при несоответствии интервала
T6_INT_ERR
	LD		E, '-'

	; ждем готовности передатчика и выводим
T6_W_TX
	IN		A, (DD72RR)
	AND		TX_RDY
	JP		Z, T6_W_TX
	LD		A, E
	OUT		(DD72RD), A

	CP		0x2B
	JP		Z, T6_L12
	; импульс 5мс на РА0 DD80
	LD		A, 0x01
	OUT		(DD80RA), A
	XOR		A
	OUT		(DD80RA), A

T6_L12
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T6_INT_NXT

T6_END
	; тест 6 ок
	LD		D, 0x00
	LD		E, 0x06
	LD		SP, TEST7
	JP		MSG

;-------------------------------------------------------
; Тест 7 	ввод с клавиатуры 7-разрядных кодов символов
;			и передача их на терминал
;-------------------------------------------------------
TEST7
	LD		SP, T7_W_STB
	JP		WAIT_BTN
	; ждем сигнала запроса прерывания от клавиатуры (STB-)
T7_W_STB
	IN		A, (DD75RS)
	AND		RST_1
	JP		NZ, T7_KBD_RQ

	IN		A, (DD72RR)
	AND		RX_RDY
	JP		Z, T7_W_STB
	; Выход из теста по кнопке S1 с сообшением об успехе
	LD		D, 0x0
	LD		E, 0x7
	LD		SP, TEST8
	JP		MSG

	; обработка клавиши
T7_KBD_RQ
	; чтение кода клавиши
	IN		A, (DD78RA)
	; код клавиши в порт PA DD80
	OUT		(DD80RA), A
	LD		B, A
	LD		A, KBD_ACK
	; подтверждение чтения клавиатуры сигналом ACK
	OUT		(DD78RC), A
	; ожидаем реакции клавиатуры
T7_W_STB1
	IN		A, (DD75RS)
	AND		RST_1
	JP		NZ, T7_W_STB1
	; убираем сигнал ACK
	XOR		A
	OUT		(DD78RC), A
	; ждем готовности передатчика
T7_W_TXR
	IN		A, (DD72RR)
	AND		TX_RDY
	JP		Z, T7_W_TXR
	; вывод кода клавиши в последовательный порт
	LD		A, B
	OUT		(DD72RD), A
	JP		T7_W_STB

;-------------------------------------------------------
; Тест 8 	Проверки контроллера прерываний
;			и системного таймера
;-------------------------------------------------------
TEST8
	LD		E, 4
	; ждем 2с
T8_W2
	LD		BC, DELAY1
T8_W05
	DEC		BC
	LD		A, B
	OR		C
	JP		NZ, T8_W05
	DEC		E
	JP		NZ, T8_W2

	; программируем таймер
	LD		A, 0x36									; 0011 0110 -> 00 - канал , 11 - запись слова, 011 - режим 3, 0 - двоичный счет
	OUT		(DD70RR), A
	; сброс счетчика
	XOR		A
	OUT		(DD70C1), A
	OUT		(DD70C1), A

	LD		SP, T_STACK
	LD		A, 0xC3									; CALL xxxx
	LD		(INT_CALL), A
	LD		HL, T9_INT_HNDL
	LD		(INT_ADDR), HL

	; программируем контроллер на прерывание от таймера
	LD		A, 0xEF									; 1110 1111 -> вкл RST4
	OUT		(DD75RM), A
	LD		A,0x20
	OUT		(DD75RS), A

	; пауза на ловлю прерывания
	LD		DE, DELAY1
	EI
T9_W_IRQ
	DEC		DE
	LD		A, D
	OR		E
	JP		NZ, T9_W_IRQ

	; не поймали, ошибка и переход на тест 9
	DI
	LD		E, 0x08
	LD		D, 0x02
	LD		SP, TEST9
	JP		MSG

T9_INT_HNDL
	DI
	; поймали прерывание без ошибок
	LD		E, 0x08
	LD		D, 0x00
	LD		SP,TEST9
	JP		MSG

;-------------------------------------------------------
; Тест 9	Проверка печати на принтер
;-------------------------------------------------------
TEST9
	; ждем кнопку S1
	LD		SP, T9_W_S1
	JP		WAIT_BTN
T9_W_S1
	IN		A,(DD72RR)
	AND		RX_RDY
	JP		Z,T9_W_S1

	LD		SP, T9_L1
	JP		WAIT_BTN
T9_L1

	LD		C, 0x20 								; ' '
T9_LE_127
	LD		DE, W_BUSY 								; 9C40

	; статус сигнала BUSY от принтера
T9_W_BUSY
	IN		A, (DD75RS)
	AND		RST_3
	JP		NZ, T9_STROBE_ON

	DEC		DE
	LD		A,D
	OR		E
	JP		NZ, T9_W_BUSY
	; принтер не освободился
	JP		T9_T_OUT

	; выдаем строб
T9_STROBE_ON
	LD		A, C
	OUT		(DD67RA), A								; вывод символа
	LD		A, 0x14									; 0001 0100  STROBE + TAPE3
	OUT		(DD67RC), A
	; ждем реакции принтера
	LD		DE, W_BUSY
T9_W_BUSY1
	IN		A,(DD75RS)
	AND		RST_3

	JP		Z, T9_STROBE_OFF
	DEC		DE
	LD		A,D
	OR		E
	JP		NZ,T9_W_BUSY1
	JP		T9_T_OUT
	; убираем строб
T9_STROBE_OFF
	LD		A, 0x04									; 0000 0100
	OUT		(DD67RC), A

T9_T_OUT
	IN		A, (DD72RR)
	AND		RX_RDY
	JP		NZ, T9_S1
	INC		C										; следующий код символа
	LD		A, C
	CP		127										; печатные символы с кодом <127
	JP		C, T9_LE_127
	LD		C, ' '
	JP		T9_LE_127

	; выход из теста по клавише S1
T9_S1
	LD		E, 0x09
	LD		D, 0x00
	LD		SP, TEST_END
	JP		MSG

;-------------------------------------------------------
; Окончание тестов
;-------------------------------------------------------
TEST_END
	; вывод сообщения об окончании в последовательный порт
	LD		HL, MS4
TE_OUT_CHAR
	; проверка конца строки
	LD		A, (HL)
	OR		A
	JP		Z, TE_STOP

	LD		B, A
	; ждем готовности передатчика
TE_W_S1
	IN		A, (DD72RR)
	AND		TX_RDY
	JP		Z, TE_W_S1
	; передаем байт в последовательный порт
	LD		A, B
	OUT		(DD72RD),A
	INC		HL										; addr++
	JP		TE_OUT_CHAR
TE_STOP
	JP		TE_STOP

;-------------------------------------------------------
; Ожидание отпускания кнопки S1
;-------------------------------------------------------
WAIT_BTN
	; очистить буфер приема
	IN		A, (DD72RD)
	IN		A, (DD72RD)
	; прочитать статус
	IN		A, (DD72RR)
	; пока нажата S1 ждем
	AND		RX_RDY
	JP		NZ, WAIT_BTN
	LD		BC, W_BUTN
WB_DELAY
	DEC		BC
	LD		A,B
	OR		C
	JP		NZ,WB_DELAY
	; очистить буфер приема
	IN		A, (DD72RD)
	IN		A, (DD72RD)
	LD		HL, 0x0000
	; возврат к точке перехода
	ADD		HL, SP
	JP		(HL)

;-------------------------------------------------------
; Вывод сообщения
; Inp:	D - результат теста (0-PASSED, 1-ERROR AT, 2-ERROR)
;  	  	E - номер теста
;		HL - адрес
;-------------------------------------------------------
MSG
	LD		C, E									; число гудков
	; ------ beep
MSG_RPT0
	LD		B, 125
MSG_RPT1
	LD		A, D
	OR		A
	LD		A, 0x3C
	JP		Z, MSG_DLY1
	LD		A, 120
MSG_DLY1
	DEC		A
	JP		NZ, MSG_DLY1
	LD		A, 0x0C								; 0000 1100  [STB,BELL]=00 [TAPE3..2]=11
	OUT		(DD67RC), A
	LD		A, D
	OR		A
	LD		A, 0x3C								; 0011 1100  [STB,BELL]=11 [TAPE3..2]=11
	JP		Z, MSG_DLY2
	LD		A, 120
MSG_DLY2
	DEC		A
	JP		NZ, MSG_DLY2
	LD		A, 0x04								; 0000 0100 [TAPE3]=1
	OUT		(DD67RC), A
	DEC		B
	JP		NZ, MSG_RPT1
	; пауза после гудка 50*200 раз
	LD		B, 50
MSG_DLY3
	LD		A, 200
MSG_DLY4
	DEC		A
	JP		NZ, MSG_DLY4
	DEC		B
	JP		NZ, MSG_DLY3
	DEC		C
	JP		NZ, MSG_RPT0
	; вывод строки в последовательный порт
	LD		BC, MSG_TEST
MSG_SEND_CHAR
	LD		A, (BC)
	OR		A
	JP		Z, MSG_TEST_END
	; ждем готовности ВВ51
MSG_W_TX_EN1
	IN		A,(DD72RR)
	AND		TX_RDY
	JP		Z,MSG_W_TX_EN1
	; передача символа
	LD		A,(BC)
	OUT		(DD72RD),A
	INC		BC
	JP		MSG_SEND_CHAR
	; Ожидание конца передачи
MSG_TEST_END
	IN		A, (DD72RR)
	AND		TX_RDY
	JP		Z, MSG_TEST_END

	; номер теста в строку и передача
	LD		A, E
	AND		0x0F
	ADD		A, 0x30
	OUT		(DD72RD), A

	; вывод результата теста
	LD		BC, MSG_PASS
	LD		A, D
	OR		A
	JP		Z, MSG_OUT_RES
	LD		BC, MSG_ERR_AT
	RRA
	JP		C, MSG_OUT_RES
	LD		BC, MSG_ERR
MSG_OUT_RES
	LD		A, (BC)
	OR		A
	JP		Z, MSG_ERR_END
	; посимвольная отпр сообщения об ошибке
MSG_NXT_ERR
	IN		A,(DD72RR)
	AND		TX_RDY
	JP		Z, MSG_NXT_ERR
	LD		A, (BC)
	OUT		(DD72RD), A
	INC		BC
	JP		MSG_OUT_RES
MSG_ERR_END
	;  отправка нулей в порты пользователя/FDC
	XOR		A
	OUT		(DD80RA),A
	OUT		(DD80RB),A
	OUT		(DD80RC),A
	LD		A, D
	; надо выводить адрес?
	AND		0x01
	JP		Z, MSG_EXIT
	LD		A, D
	RRA
	RRA
	AND		0x01
	; PC0 <- 0/1 - осн/доп ОЗУ
	OUT		(DD80RC),A
	ADD		A, 0x30
	LD		B, A
MSG_W_TX_EN2
	IN		A,(DD72RR)
	AND		TX_RDY
	JP		Z,MSG_W_TX_EN2

	LD		A, B
	OUT		(DD72RD), A
	LD		B, 4									; addr len 4 bytes
	; вывод адреса ошибки на порт пользователя A и B
	LD		A, L
	OUT		(DD80RA),A
	LD		A, H
	OUT		(DD80RB),A
	LD		D, H
	LD		E, L

	; вывод адреса в HEX
MSG_TO_HEX
	LD		A, H
	RRA
	RRA
	RRA
	RRA
	AND		0x0F
	ADD		A, 0x90
	DAA
	ADC		A, 0x40
	DAA
	LD		C,A
	; вывод HEX символа адреса
MSG_W_TX_EN3
	IN		A,(DD72RR)
	AND		0x1
	JP		Z, MSG_W_TX_EN3
	LD		A, C
	OUT		(DD72RD),A

	LD		C, 0x4
MSG_A_SR4
	LD		A, L
	RLA
	LD		L, A
	LD		A, H
	RLA
	LD		H, A
	DEC		C
	JP		NZ, MSG_A_SR4
	; вывод следующего символа адреса, если не закончили
	DEC		B
	JP		NZ, MSG_TO_HEX
	; возврат назад к точке указанной в SP
MSG_EXIT
	LD		HL, 0x0000
	ADD		HL, SP
	JP		(HL)

; -------------------------------------------------------
; Сообщения
; -------------------------------------------------------
MSG_TEST
	DB	"\r\nTEST ", 0

MSG_PASS
	DB	" PASSED", 0

MSG_ERR
	DB	" ERROR!", 0

MSG_ERR_AT
	DB	" ERROR AT ADDR ", 0

MS4
	DB	"\r\nEND", 0
	DB 	0x22

; -------------------------------------------------------
; Заполнение остатака ПЗУ байтами FF до 2КБ
; -------------------------------------------------------
LAST		EQU 	$
CODE_SIZE	EQU		LAST-0xE000
FILL_SIZE	EQU		2048-CODE_SIZE

	DISPLAY "Code size is: ",/A,CODE_SIZE

FILLER
	DS	2048-CODE_SIZE, 0xFF
	DISPLAY "Filler size is: ",/A,FILL_SIZE

	END