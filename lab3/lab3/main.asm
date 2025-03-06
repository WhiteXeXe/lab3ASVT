.org $000
	JMP RESET
.org INT0addr			;������ ��� ����������
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

; ����������� ����� ��� ������ �� ����������
.equ zero = 0b00000000
.equ one = 0b00000001
.equ two = 0b00000011
.equ three = 0b00000111
.equ four = 0b00001111
.equ five = 0b00011111
.equ six = 0b00111111
.equ seven = 0b01111111
.equ eight = 0b11111111


/* �������� ��� ������ ������
SFIOR: (������ � �����������)
	7 ADTS2
	6 ADTS1
	5 ADTS0
	4 �
	3 ACME
	2 PUD
	1 PSR2 - ������� ����������� �/C 2
	0 PSR10 - ������� ����������� �/C 1, 0

TIMSK: (Timer/Counter Interrupt Mask Register)
	7 OCIE2 - ���������� ���������� �� ���������� ��2
	6 TOIE2 - ���������� ���������� �� ������������ ��2
	5 TICIE1 - ���������� ���������� �� ������� ��1
	4 OCIE1A - ���������� ���������� �� ���������� �������� A � ��1
	3 OCIE1B - ���������� ���������� �� ���������� �������� B � ��1
	2 TOIE1 - ���������� ���������� �� ������������ ��1
	1 OCIE0 - ���������� ���������� �� ���������� ��0
	0 TOIE0 - ���������� ���������� �� ������������ ��0

MCUCR (�� ������� ����� ��� INT0 � INYT):
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
	6 WGM00 - ��������� ����� ������ �������-�������� �0
	5 COM01 - ���������� ��������� ������ OC0
	4 COM00 - ���������� ��������� ������ OC0
	3 WGM01 - ��������� ����� ������ �������-�������� �0
	2 CS02 - ������ ��� ������� �0 ����������� ������������
	1 CS01 - ������ ��� ������� �0 ����������� ������������
	0 CS00 - ������ ��� ������� �0 ����������� ������������


CS02 (12) CS01 (11) CS00 (10)  Description
0 0 0			No clock source (Timer/Counter stopped).
0 0 1			clkI/O(No prescaling)
0 1 0			clkI/O/8 (From prescaler)
0 1 1			clkI/O/64 (From prescaler)
1 0 0			clkI/O/256 (From prescaler)
1 0 1			clkI/O/1024 (From prescaler)
1 1 0			External clock source on T0 pin. Clock on falling edge.
1 1 1			External clock source on T0 pin. Clock on rising edge.

OCR0 � ��� ����� 8-�� ��������� ������� �������� ��������


GICR: General Interrupt Control Register
	7 INT1 - ����� �������� ���������� INT1
	6 INT0 - ����� �������� ���������� INT0;
	5 INT2 -  ����� �������� ���������� INT2;
	1 IVSEL (Interrupt Vector Select);		 ---------
	0 IVCE (Interrupt Vector Change Enable). ---------

GIFR - ��� ��������


PINx - ������� ����
PORTx - ������ ����� � �����
DDR - ��������� (����/�����)

*/



RESET:
	; ��������� �������������� �����������
	SER TMP
	OUT DDRA, TMP
	OUT DDRB, TMP

	; ��������� ����� � �� ���� (PD0 - PD3)
	CLR TMP
	OUT DDRD, TMP

	; ������� �����
	OUT PORTA, TMP
	OUT PORTB, TMP
	OUT PORTC, TMP
	OUT PORTD, TMP

	; ��������� �����
	LDI TMP, HIGH(RAMEND) ; ������� ������� ������
	OUT SPH, TMP ; ��������� ������� ����� � ����� ���
	LDI TMP, LOW(RAMEND) ; ������� ������� ������
	OUT SPL, TMP ; ��������� ������� ����� � ����� ���

	; ������� ������������ SIFOR �� ������� = 0
	LDI TMP, 0b00000011
	OUT SFIOR, TMP		   ; ���������� �������� PSR2 (��� �/C 2), PSR10 (��� �/C 0, 1) � 
	
	; �������� �������
	CLR TMP
	MOV COUNTER, TMP

	; ��������� �������
	LDI TMP, 0b00001101
	OUT TCCR0, TMP

	; LDI TMP, 0b00001101
	; OUT TCCR1B, TMP      ;  01 - ���  101 �������� ������� ��/1024   
; �������� �������� ��� ��������� 
	LDI TMP, 0xFF
	OUT OCR0, TMP

	; LDI TMP, 0x3D
	; OUT OCR1AH, TMP
	; LDI TMP, 0x08
	; OUT OCR1AL, TMP

	
; ��������� ���������� ������� ��� ���������
	LDI TMP, 0b00000011
	OUT TIMSK, TMP

; ��������� ���������� ��� ������� ������ PD2 & PD3
	LDI TMP, 0x0F ; ���������� � �������� 0b00001111
	OUT MCUCR, TMP ; ��������� ������������
	LDI TMP, 0xC0 ; ���������� � �������� 0b11000000
	OUT GICR, TMP ; ��������� ����������
	CLR TMP ; ������� �������
	OUT GIFR, TMP ; ���������� � ��������, ������� ��������� �������� ������������, ����
	SEI ; ���������� ���������� ����������


main:
	CP MODE, COUNTER
	BREQ main
	MOV MODE, COUNTER
	
	MOV TMP, MODE
	CPI TMP, 125
	BRLO display_num
	CLR COUNTER
	CLR MODE
	CLR TMP

display_num:
	CPI TMP, 0
	BREQ out_1
	CPI TMP, 15
	BREQ out_1
	CPI TMP, 30
	BREQ out_2
	CPI TMP, 45
	BREQ out_3
	CPI TMP, 60
	BREQ out_4
	CPI TMP, 75
	BREQ out_5
	CPI TMP, 90
	BREQ out_6
	CPI TMP, 105
	BREQ out_7
	CPI TMP, 120
	BREQ out_8
	JMP main

blink:
	IN TMP, PORTB
	LDI R30, 0b00001111
	EOR TMP, R30
	OUT PORTB, TMP
	RJMP main

out_0:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, zero
	OUT PORTA, TMP
	RJMP main

out_1:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, one
	OUT PORTA, TMP
	CALL delay
	RJMP main

out_2:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, two
	OUT PORTA, TMP
	RJMP main

out_3:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, three
	OUT PORTA, TMP
	RJMP main

out_4:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, four
	OUT PORTA, TMP
	RJMP main

out_5:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, five
	OUT PORTA, TMP
	RJMP blink

out_6:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, six
	OUT PORTA, TMP
	RJMP main

out_7:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, seven
	OUT PORTA, TMP
	RJMP main

out_8:
	CLR TMP
	OUT PORTA, TMP
	LDI TMP, eight
	OUT PORTA, TMP
	RJMP main

	                   

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

TIMER0_OVF:
	IN R20, SREG
	PUSH R20
	INC COUNTER
	POP R20
	OUT SREG, R20
	RETI

TIMER0_COMP:
	RETI
	


delay: ; �������� 500 ��
	LDI R25, 10 ; 10 70 21
	LDI R26, 70
	LDI R27, 21
delay_sub:
	DEC R25
	BRNE delay_sub
	DEC R26
	BRNE delay_sub
	DEC R27
	BRNE delay_sub
	RET

