$PAGELENGTH (65535)
;Program cita od +0:00 -> +19:59 -> +0:00 a zapisuje na LCD displej
;Okolni hardware:
;            3x4543 dekoder
;            LCD +18:88

; Vstupy & vystupy

PIEZO   BIT  P3.3        ;vystup na piezo - neaktivni=1, aktivni=f (1kHz)

LCD3    BIT  P1.6        ;vstup LE (uvolneni stradace) dekoderu 4543
LCD2    BIT  P1.5        ;  1=zapis
LCD1    BIT  P1.4

BCDA    BIT  P1.0        ;vstupy BCD pro 4543
BCDB    BIT  P1.2
BCDC    BIT  P1.3
BCDD    BIT  P1.1

LCD     BIT  P3.7        ;obdelnik pro LCD a 4543 (20 - 100 Hz)
;tyto signaly se musi menit spolecne s LCD:
LCD4    BIT  P1.7        ;vstup na LCD - 4.rad "1"
LCDDT   BIT  P3.4        ;dvojtecka
LCDT    BIT  P3.2        ;tecka
LCDP    BIT  P3.0        ;spolecne s LCDM tvori +
LCDM    BIT  P3.1        ;minus pred cislem

;----------------------------------------------------------------------------
DSEG AT 008H             ;data
STACK:  DS   017H        ;zasobnik prez RB1-RB3 (008h - 019h)
                         ;bitova oblast (020h - 02Fh)
ORG     030H             ;nevyuzita RAM
CITAC:  DS   2           ;citace pro konstanty casu;
SEC:    DS   1
MIN:    DS   1
HOD:    DS   1
POM:    DS   1           ;promenna pro vse :-)
;----------------------------------------------------------------------------
BSEG AT 020H
LCD50:  DBIT 1           ;obdelnik pro LCD a 4543
JEDNA:  DBIT 1           ;pro jednicku
DT:     DBIT 1           ;pro dvojtecku (0=neni videt/1=je videt)
T:      DBIT 1           ;pro tecku (0=neni videt/1=je videt)
PLUS:   DBIT 1           ;pro + (0=neni videt/1=je videt)
MINUS:  DBIT 1           ;pro - (0=neni videt/1=je videt)

PISKA:  DBIT 1           ;pro piezo (0=nepiska/1=piska podle)

;----------------------------------------------------------------------------
CSEG AT 00000H           ;instrukcni pocatek
LJMP    START
ORG     0000BH           ;preruseni od casovace 0
LJMP    TIMER0INT
;ORG     0001BH           ;preruseni od casovace 1
;LJMP    TIMER1INT
ORG     00030H           ;pocatek kodu
;------------------------ PODPROGRAMY ---------------------------------------

GENERUJOBDELNIK:
 cpl     LCD50                  ;generuj zmenu (obdelnik f=50Hz)
 mov     C,LCD50
 mov     LCD,C
jc       LCDSET
 mov     C,JEDNA                ;vystup LCD nenastaven (0)
 mov     LCD4,C
 mov     C,DT
 mov     LCDDT,C
 mov     C,T
 mov     LCDT,C
 mov     C,PLUS
 mov     LCDP,C
 mov     C,MINUS
 mov     LCDM,C
 ljmp    LCDNOTSET
LCDSET:                         ;vystup LCD nastaven (1)
 mov     C,JEDNA
 cpl     C
 mov     LCD4,C
 mov     C,DT
 cpl     C
 mov     LCDDT,C
 mov     C,T
 cpl     C
 mov     LCDT,C
 mov     C,PLUS
 cpl     C
 mov     LCDP,C
 mov     C,MINUS
 cpl     C
 mov     LCDM,C
LCDNOTSET:                      ;pokracuj ...
RET
;----------------------------------------------------------------------------
MAXLCD:
MAXSEC:  DB 060h
MAXMIN:  DB 060h
MAXHOD:  DB 012h
TABEND:  DB 00h

ZVETSI:

  push    acc
   clr     A
   movc    A,@A+DPTR
   mov     POM,A
   mov     R2,A
  pop     acc

 cjne    R2,#0,POKRACUJDAL
 ljmp    KONECREKURZE
POKRACUJDAL:

 xch     A,@R0
 add     A,#1
 da      A

 cjne    A,POM,ZVETSIOK
 clr     A

 inc     R0
 inc     DPTR
 lcall   ZVETSI                   ;rekurze <:-)>
 dec     R0

 ZVETSIOK:
 xch     A,@R0

 KONECREKURZE:
RET

ZVETSICITACE:                   ;Pricte citace casu
                                ;V R0,R1 je parametr
                                ;R0 - adresa citace
                                ;R1 - nejnizsi byt citace
mov     DPL,#LOW(MAXLCD)        ;Ukazatel na tabulku maximalnich hodnot citacu
mov     DPH,#HIGH(MAXLCD)
mov     A,#SEC
mov     R0,A
mov     R1,A
lcall   ZVETSI

RET

TIMER0INT:                      ;probiha 10000x (f=1000000/100 = 10000 Hz)
 push   PSW                     ;uloz PSW
 push   ACC
 mov    A,R0
 push   ACC                     ;uloz R0

djnz    CITAC,KONEC             ;IF(--CITAC != 0) jmp POROVNEJ
mov     CITAC,#100              ;probiha 100x (f=1000000/100/100 = 100 Hz)

lcall   GENERUJOBDELNIK

djnz    CITAC+1,KONEC
mov     CITAC+1,#100            ;probiha 1x (f=1000000/100/100/100 = 1 Hz)

lcall   ZVETSICITACE

KONEC:
pop     ACC
mov     R0,A
pop     ACC
pop     PSW
RETI
;----------------------------------------------------------------------------
CEKEJ:                   ;A je parametr
 xch A,R0
 push acc
 xch A,R0

 xch A,R1
 push ACC

 mov R0,#0
CEKEJLOOP:
 djnz R0,CEKEJLOOP
 djnz R1,CEKEJLOOP

 pop ACC
 xch A,R1
 pop acc
 mov R0,A
RET

CEKEJMALO:
push    ACC
mov     A,#5
lcall   CEKEJ
pop     ACC
RET
;----------------------------------------------------------------------------
NASTAVBCD:               ;parametr v A
mov C,ACC.0              ;A
mov BCDA,C
mov C,ACC.1              ;B
mov BCDB,C
mov C,ACC.2              ;C
mov BCDC,C
mov C,ACC.3              ;D
mov BCDD,C
RET

ZAPISDO4543:             ;nastav cely displej
mov     A,SEC
lcall   NASTAVBCD
setb    LCD1
lcall   CEKEJMALO
clr     LCD1
swap    A
lcall   NASTAVBCD
setb    LCD2
lcall   CEKEJMALO
clr     LCD2
mov     A,MIN
lcall   NASTAVBCD
setb    LCD3
lcall   CEKEJMALO
clr     LCD3
mov     C,ACC.4
mov     JEDNA,C
RET
;----------------------------------------------------------------------------
START:                   ;hlavni program
clr     LCD1
clr     LCD2
clr     LCD3
setb    LCD
setb    LCD50            ;obdelnik (dalsi zmena az v TIMER0)
clr     PISKA            ;piezo
setb    DT               ;dvojtecka
clr     T                ;tecka
setb    PLUS             ;plus
setb    MINUS            ;minus

mov     A,#100
mov     CITAC,A          ;citac po startu 25700d = 06464h
mov     CITAC+1,A
clr     A
mov     SEC,A
mov     MIN,A
mov     HOD,A

mov     A,#(100h-100)
mov     TH0,A
mov     TH1,A
mov     TMOD,#00000010b   ;gate,c/t,m1,m0 - casovac s obvod. prednastavenim
mov     TCON,#00010000b
mov     IE,#11100010b     ;povol preruseni od citace 0
mov     IP,#11100010b     ;priorita

LOOP:
lcall   ZAPISDO4543
ljmp    LOOP
END
