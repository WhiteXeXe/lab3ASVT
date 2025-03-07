.org $000
	JMP RESET
.org INT0addr			;Адреса для прерываний
	JMP EXIT_INT0
.org INT1addr
	JMP EXIT_INT1
.org $00E
	JMP TIMER1_COMP
.org $014
	JMP TIMER0_COMP
.org $016
	JMP TIMER0_OVF


.def TMP = R16
.def PAUSE_FLAG = R17
.def SETTINGS_FLAG  = R18
.def COUNTER = R19
.def MODE = R21
.def BAD_COUNTER = R22
.def NUM_OF_PRINT = R29

.def T1 = R0
.def T2 = R1
.def T3 = R2
.def T4 = R3

; определение чисел для вывода на индикаторы
.equ null = 0b00000000 
.equ zero = 0b00111111
.equ one = 0b00000110
.equ two = 0b01011011
.equ three = 0b01001111
.equ four = 0b01100110
.equ five = 0b01101101
.equ six = 0b01111101
.equ seven = 0b00000111
.equ eight = 0b01111111
.equ nine = 0b01101111




/* Регистры для данной работы
SFIOR: (работа с пределитель)
	7 ADTS2
	6 ADTS1
	5 ADTS0
	4 —
	3 ACME
	2 PUD
	1 PSR2 - очистка пределителя Т/C 2
	0 PSR10 - очистка пределителя Т/C 1, 0

TIMSK: (Timer/Counter Interrupt Mask Register)
	7 OCIE2 - Разрешение прерывания по совпадению ТС2
	6 TOIE2 - Разрешение прерывания по переполнению ТС2
	5 TICIE1 - Разрешение прерывания по захвату ТС1
	4 OCIE1A - Разрешение прерывания по совпадению регистра A с ТС1
	3 OCIE1B - Разрешение прерывания по совпадению регистра B с ТС1
	2 TOIE1 - Разрешение прерывания по переполнению ТС1
	1 OCIE0 - Разрешение прерывания по совпадению ТС0
	0 TOIE0 - Разрешение прерывания по переполнению ТС0

MCUCR (по большей части для INT0 и INYT):
	7 SE - Sleep Enable
	6 SM2 - Sleep Mode bit 2
	5 SM1 - Sleep Mode bit 1
	4 SM0 - Sleep Mode bit 0
	3 ISC11 - Interrupt Sense Control 1 bit 1
	2 ISC10 - Interrupt Sense Control 1 bit 0
	1 ISC01 - Interrupt Sense Control 0 bit 1
	0 ISC00 - Interrupt Sense Control 0 bit 0

TCCR0 (2) - (The Timer/Counter0 (1) Control Register)
	7 FOC0
	6 WGM00 - пределяют режим работы таймера-счетчика Т0
	5 COM01 - определяют поведение вывода OC0
	4 COM00 - определяют поведение вывода OC0
	3 WGM01 - пределяют режим работы таймера-счетчика Т0
	2 CS02 - задают для таймера Т0 коэффициент предделителя
	1 CS01 - задают для таймера Т0 коэффициент предделителя
	0 CS00 - задают для таймера Т0 коэффициент предделителя


CS02 (12) CS01 (11) CS00 (10)  Description
0 0 0			No clock source (Timer/Counter stopped).
0 0 1			clkI/O(No prescaling)
0 1 0			clkI/O/8 (From prescaler)
0 1 1			clkI/O/64 (From prescaler)
1 0 0			clkI/O/256 (From prescaler)
1 0 1			clkI/O/1024 (From prescaler)
1 1 0			External clock source on T0 pin. Clock on falling edge.
1 1 1			External clock source on T0 pin. Clock on rising edge.

OCR0 – это также 8-ми разрядный регистр счётчика сранение


GICR: General Interrupt Control Register
	7 INT1 - маска внешнего прерывания INT1
	6 INT0 - маска внешнего прерывания INT0;
	5 INT2 -  маска внешнего прерывания INT2;
	1 IVSEL (Interrupt Vector Select);		 ---------
	0 IVCE (Interrupt Vector Change Enable). ---------

GIFR - сам работает


PINx - нажатие порт
PORTx - взятие битов с порта
DDR - настройка (ввод/вывод)







- В режиме СТС у нас при совпадении в сравнении происходит обнуление
- В normal режиме у нас при совпадении в сравнении происходит действие, а потом идет далле до переполнения






*/



RESET:
	; настройка семисегментных индикаторов
	SER TMP
	OUT DDRA, TMP   ; (на каком индикаторе будет выводиться)
	OUT DDRC, TMP   ; замена ddrc (отвечает за число)

	; настройка порта Д на ввод (PD0 - PD3)
	CLR TMP
	OUT DDRD, TMP

	; очищаем порты
	OUT PORTA, TMP
	OUT PORTC, TMP
	OUT PORTC, TMP
	OUT PORTD, TMP

	; настройка стека
	LDI TMP, HIGH(RAMEND) ; Старшие разряды адреса
	OUT SPH, TMP ; Установка вершины стека в конец ОЗУ
	LDI TMP, LOW(RAMEND) ; Младшие разряды адреса
	OUT SPL, TMP ; Установка вершины стека в конец ОЗУ

	; очищаем предделитель SIFOR по дефолту = 0
	LDI TMP, 0b00000011
	OUT SFIOR, TMP		   ; сбрасываем регистры PSR2 (для Т/C 2), PSR10 (для Т/C 0, 1) и 
	
	; обнуляем счетчик
	LDI COUNTER, 0

	

	LDI TMP, 4
	MOV T1, TMP
	LDI TMP, 0
	MOV T2, TMP
	LDI TMP, 0
	MOV T3, TMP
	LDI TMP, 0
	MOV T4, TMP

	LDI TMP, 0b00001111
	MOV R7, TMP

	; настройка таймера
	LDI TMP, 0b00001101
	OUT TCCR0, TMP
	LDI TMP, 0b00001101
	OUT TCCR1B, TMP      ;  01 - стс    101 Тактовая частота МК/1024   

; загрузка значения для сравнения 
	LDI TMP, 0xFF
	OUT OCR0, TMP

	LDI TMP, 0x1E
	OUT OCR1AH, TMP
	LDI TMP, 0x84      
	OUT OCR1AL, TMP

	
; разрешаем прерывания таймера для сравнения
	LDI TMP, 0b00010001  ; (для TС0 (по overflow) и для ТС1 (по совпадению))
	OUT TIMSK, TMP

; настройка прерываний при нажатии кнопок PD2 & PD3
	LDI TMP, 0x0F ; выставляем в регистре 0b00001111
	OUT MCUCR, TMP ; управляем прерываниями
	LDI TMP, 0xC0 ; выставляем в регистре 0b11000000
	OUT GICR, TMP ; разрешаем прерывания
	CLR TMP ; очищаем регистр
	OUT GIFR, TMP ; выставляем в регистре, который управляет внешними прерываниями, нули
	SEI ; глобальное разрешение прерываний
	LDI COUNTER, 0

main:
	MOV T1, COUNTER 
	RJMP TR_T2
	
	

TR_T2:
	MOV TMP, T1
	CLC
	CPI TMP, 10
	BRLO printNUM
	INC T2
	SUBI TMP, 10
	MOV T1, TMP
	CLR COUNTER

TR_T3:
	MOV TMP, T2
	CLC
	CPI TMP, 6
	BRLO printNUM
	INC T3
	SUBI TMP, 6
	MOV T2, TMP

TR_T4:
	MOV TMP, T3
	CLC
	CPI TMP, 9
	BRLO printNUM
	INC T4
	SUBI TMP, 9
	MOV T3, TMP


printNUM:
	CPI NUM_OF_PRINT, 1
	BREQ oneP
	CPI NUM_OF_PRINT, 2
	BREQ twoP
	CPI NUM_OF_PRINT, 3
	BREQ threeP
	CPI NUM_OF_PRINT, 4
	BREQ fourP
	JMP printNUM


oneP:
	LDI TMP, 0b00000111
	OUT PORTA, TMP
	PUSH T1
	RJMP display_num

twoP:
	LDI TMP, 0b00001011
	OUT PORTA, TMP
	PUSH T2
	RJMP display_num

threeP:
	LDI TMP, 0b00001101
	OUT PORTA, TMP
	PUSH T3
	RJMP display_num

fourP:
	LDI TMP, 0b00001110
	OUT PORTA, TMP
	PUSH T4
	RJMP display_num



display_num:    ;  (0.5 сек ++counter)
	POP TMP
	CPI TMP, 0
	BREQ out_0
	CPI TMP, 1
	BREQ out_1
	CPI TMP, 2
	BREQ out_2
	CPI TMP, 3
	BREQ out_3
	CPI TMP, 4
	BREQ out_4
	CPI TMP, 5
	BREQ out_5
	CPI TMP, 6
	BREQ out_6
	CPI TMP, 7
	BREQ out_7
	CPI TMP, 8
	BREQ out_8
	CPI TMP, 9
	BREQ out_9
	
	

blink:
	IN TMP, PORTA
	EOR TMP, R7
	OUT PORTA, TMP
	RJMP main

out_0:
	
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, zero
	OUT PORTC, TMP
	JMP main

out_1:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, one
	OUT PORTC, TMP
	JMP main

out_2:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, two
	OUT PORTC, TMP
	JMP main

out_3:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, three
	OUT PORTC, TMP
	JMP main

out_4:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, four
	OUT PORTC, TMP
	JMP main

out_5:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, five
	OUT PORTC, TMP
	JMP main

out_6:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, six
	OUT PORTC, TMP
	JMP main

out_7:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, seven
	OUT PORTC, TMP
	JMP main

out_8:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, eight
	OUT PORTC, TMP
	JMP main

out_9:
	CLR TMP
	OUT PORTC, TMP
	LDI TMP, nine
	OUT PORTC, TMP
	JMP main

	                   

EXIT_INT0:
	RETI
EXIT_INT1:
	RETI
TIMER1_COMP:
	IN R20, SREG
	PUSH R20
	INC COUNTER
	POP R20
	OUT SREG, R20
	RETI

obnull:
	LDI NUM_OF_PRINT, 1
	JMP ret_obnull


TIMER0_OVF:
	IN R20, SREG
	PUSH R20
	INC NUM_OF_PRINT
	CPI NUM_OF_PRINT, 5
	BREQ obnull
ret_obnull:
	POP R20
	OUT SREG, R20
	RETI


TIMER0_COMP:
	RETI
	
