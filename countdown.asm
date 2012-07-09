$PAGELENGTH (65535)
;Program cita maximalne od -19:59.00 do 19:59.59 a v nule deset vterin piska
;Okolni hardware:
;            3x4543 dekoder
;            LCD +18:88
;            Piezo samovybuzovaci
;            4xTlacitko + 4xdioda

; Vstupy & vystupy

PIEZO   BIT  P3.3        ;vystup na piezo - neaktivni=0, aktivni=1 (sambuz)
TLAC    BIT  P3.5        ;spolecny vstup pro klavesnici - cteni v 1

LCD3    BIT  P1.6        ;vstup LE (uvolneni stradace) dekoderu 4543
LCD2    BIT  P1.5        ;  1=zapis
LCD1    BIT  P1.4

BCDA    BIT  P1.0        ;vstupy BCD pro 4543  -tlac. Hod
BCDB    BIT  P1.2                            ; -tlac. Min
BCDC    BIT  P1.3                            ; -tlac. Clr
BCDD    BIT  P1.1                            ; -tlac. S/s (Start/stop)

LCD     BIT  P3.7        ;obdelnik pro LCD a 4543 (20 - 100 Hz) 50Hz
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
DVOJT:  DS   1           ;pomocny citac
POM:    DS   1           ;promenna pro vse :-)
PISK:   DS   1           ;citac pro piezo
;----------------------------------------------------------------------------
BSEG AT 020H
LCD50:  DBIT 1           ;obdelnik pro LCD a 4543
JEDNA:  DBIT 1           ;pro jednicku
DT:     DBIT 1           ;pro dvojtecku (0=neni videt/1=je videt)
T:      DBIT 1           ;pro tecku (0=neni videt/1=je videt)
PLUS:   DBIT 1           ;pro + (0=neni videt/1=je videt)
MINUS:  DBIT 1           ;pro - (0=neni videt/1=je videt)
STISK:  DBIT 1           ;pro tlacitka - proti zakmitu
PISKA:  DBIT 1           ;pro piezo (0=nepiska/1=piska podle)
PISKPR: DBIT 1           ;pro prerusovane piskani
VIC20:  DBIT 1           ;1=zobrazuj hodiny,0=zobrazuj sekundy
POMBIT: DBIT 1           ;pomocny-vyuziti v KONTOLUJCAS
PRVNID: DBIT 1           ;pomocny-vyrovnava chybu plosnaku :)
OKPISK: DBIT 1           ;bit 0 = nebude opakovane piskat, 1 = will beep again
;----------------------------------------------------------------------------
CSEG AT 00000H           ;instrukcni pocatek
LJMP    START
ORG     0000BH           ;preruseni od casovace 0
LJMP    TIMER0INT
ORG     0001BH           ;preruseni od casovace 1
LJMP    TIMER1INT
ORG     00030H           ;pocatek kodu
;------------------------ PODPROGRAMY ---------------------------------------
;komentar
DB 13,10
DB "Program BUDIK!.A51 - Odpocitavaci hodiny pro mamku :-)",13,10
DB "ROZSAH: -19:59.00 -> 00:00.00 -> 19:59.59 -> ???",13,10
;----------------------------------------------------------------------------
MAXLCD:
MAXSEC:  DB 060h
MAXMIN:  DB 060h
MAXHOD:  DB 012h
TABEND:  DB 00h

KONTROLUJNULY:
 push    ACC
 mov     A,SEC
 add     A,MIN
 add     A,HOD
 jnz     NEPLATI
 setb    PLUS
 setb    PISKA
 setb    OKPISK
 setb    PISKPR
NEPLATI:
 pop     ACC     
RET

DECA_BCD:                       ;zmensi bcd cislo v ACC o 1, 000h -> 0F9h
 dec     A
 push    ACC
 anl     A,#00Fh
 cjne    A,#00Fh,ZDAL
 pop     ACC
 clr     C
 subb    A,#6
 ljmp    ZDAL2
ZDAL:
 pop     ACC
ZDAL2:
RET

ZMENSI:
 push    acc
 clr     A
 movc    A,@A+DPTR
 mov     POM,A
 mov     R2,A
 pop     acc

 cjne    R2,#0,POKRACUJDALZ
 ljmp    KONECREKURZEZ
POKRACUJDALZ:

 xch     A,@R0
 lcall   DECA_BCD

 cjne    A,#0F9h,ZMENSIOK

 mov     A,POM
 lcall   DECA_BCD
 inc     R0
 inc     DPTR
 lcall   ZMENSI                   ;rekurze <:-)>
 dec     R0

 ZMENSIOK:
 xch     A,@R0

 KONECREKURZEZ:
RET

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
jb      PLUS,ZVETSIC
lcall   ZMENSI
lcall   KONTROLUJNULY           ;kdyz -0:00:00, nastav PLUS
RET
ZVETSIC:
lcall   ZVETSI
RET

TIMER1INT:                      ;pro zmenu polarity na LCD
push   PSW                      ;uloz PSW
push   ACC
 cpl     LCD50                  ;generuj zmenu (obdelnik f=?)
 mov     C,LCD50
 mov     LCD,C
jc       LCDSET
 mov     C,JEDNA                ;vystup LCD nenastaven (0)
 mov     LCD4,C
 mov     C,DT
 mov     LCDDT,C
 mov     C,T
 mov     LCDT,C
 jb      PLUS,MINUSNEa
 clr     LCDP
 setb    LCDM
 ljmp    LCDNOTSET
MINUSNEa:
 clr     LCDP
 clr     LCDM
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
 jb      PLUS,MINUSNEb
 setb    LCDP
 clr     LCDM
 ljmp    LCDNOTSET
MINUSNEb:
 setb    LCDP
 setb    LCDM
 ljmp    LCDNOTSET
LCDNOTSET:                      ;pokracuj ...
pop     ACC
pop     PSW
RETI

TIMER0INT:                      ;probiha 10000x (f=1000000/100 = 10000 Hz)
 push   PSW                     ;uloz PSW
 push   ACC
 mov    A,R0
 push   ACC                     ;uloz R0

djnz    CITAC,KONEC             ;IF(--CITAC != 0) jmp POROVNEJ
mov     CITAC,#100              ;probiha 100x (f=1000000/100/100 = 100 Hz)

 DJNZ    DVOJT,DV               ;50Hz - ovladani dvojtecky a pieza
 mov     dvojt,#50

 mov     A,SEC                  ;je v sekundach 10 a vic??
 mov     C,ACC.4
 cpl     C
 anl     C,PISKA                ;kdyz ano, prestane piskat
 mov     PISKA,C

 jnb     PISKA,NEPISKAT
 cpl     PISKPR                 ;prerusovani piskani
 jnb     PISKPR,NEPISKAT
 setb    PIEZO                  ;Piska !!!
 ljmp    KONECPISK
NEPISKAT:
 clr     PIEZO
KONECPISK:

 jnb     VIC20,DV
 cpl     DT                     ;zviditelni/zneviditelni ":"
DV:

djnz    CITAC+1,KONEC
mov     CITAC+1,#100            ;probiha 1x (f=1000000/100/100/100 = 1 Hz)
mov     DVOJT,#50
jnb     VIC20,NEZOBRAZDT
setb    DT
NEZOBRAZDT:
lcall   ZVETSICITACE

 jnb     OKPISK,NEOPAKUJPISK    ;v pripade opakovani piskani a sec=0 zacne
 mov     A,SEC                  ;piskat
 jnz     NEOPAKUJPISK
 setb    PISKA
 setb    PISKPR
NEOPAKUJPISK:

KONEC:
pop     ACC
mov     R0,A
pop     ACC
pop     PSW
RETI
;----------------------------------------------------------------------------
CEKEJ:                   ;A je parametr cim vetsi, tim delsi
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
jb  PRVNID,NASTAVBCDERRCOMP
mov C,ACC.0              ;A
mov BCDA,C
mov C,ACC.1              ;B
mov BCDB,C
mov C,ACC.2              ;C
mov BCDC,C
mov C,ACC.3              ;D
mov BCDD,C
RET
NASTAVBCDERRCOMP:        ;kvuli chybe na plosnaku :)
mov C,ACC.0              ;A
mov P1.3,C
mov C,ACC.1              ;B
mov P1.1,C
mov C,ACC.2              ;C
mov P1.0,C
mov C,ACC.3              ;D
mov P1.2,C
RET

KONTROLUJCAS:            ;vejde se udaj na display ???
setb    POMBIT
mov     A,HOD
jnz     KONTRKONEC
mov     A,MIN
cjne    A,#020h,CJNEC    ;A<20 => C=1
setb    DT
ljmp    KONTRKONEC
CJNEC:
jnc     KONTRKONEC       ;kdyz A>20
clr     POMBIT
KONTRKONEC:
mov     C,POMBIT
mov     VIC20,C
ZAPISDO4543:
jnb     VIC20,ZAPISDO4543SEC
ljmp    ZAPISDO4543HOD
ZAPISDO4543SEC:          ;nastav cely displej, zobraz MIN.SEC
setb    T                ;zobraz tecku,
clr     DT               ;smaz dvojtecku

mov     A,SEC
lcall   NASTAVBCD
lcall   CEKEJMALO
setb    LCD1
lcall   CEKEJMALO
clr     LCD1

swap    A
lcall   NASTAVBCD
lcall   CEKEJMALO
setb    LCD2
lcall   CEKEJMALO
clr     LCD2

mov     A,MIN
setb    PRVNID
lcall   NASTAVBCD
clr     PRVNID
lcall   CEKEJMALO
setb    LCD3
lcall   CEKEJMALO
clr     LCD3

mov     C,ACC.4
mov     JEDNA,C

mov     A,#0ffh
lcall   NASTAVBCD
RET

ZAPISDO4543HOD:          ;nastav cely displej, zobraz HOD:MIN
clr     T                ;smaz tecku

mov     A,MIN
lcall   NASTAVBCD
lcall   CEKEJMALO
setb    LCD1
lcall   CEKEJMALO
clr     LCD1

swap    A
lcall   NASTAVBCD
lcall   CEKEJMALO
setb    LCD2
lcall   CEKEJMALO
clr     LCD2

mov     A,HOD
setb    PRVNID
lcall   NASTAVBCD
lcall   CEKEJMALO
clr     PRVNID
setb    LCD3
lcall   CEKEJMALO
clr     LCD3

mov     C,ACC.4
mov     JEDNA,C

mov     A,#0ffh
lcall   NASTAVBCD
RET

CTITLACITKA:             ;zjisti stisk tlacitka a vykona prikaz
                         ;prvni tlacitko - HOD
setb    TLAC             ;priprav na cteni
clr     BCDA             ;T1
setb	BCDB
setb	BCDC
setb	BCDD
clr     STISK            ;proti zakmitu
mov     C,TLAC           ;cti stav
jc      KONECTL1         ;neni-li stisk, skoc dal
        ;telo T1 - HOD
 setb   STISK
 clr    PISKA
 clr    OKPISK
 jb     TR0,KONECTL1     ;pokud cita, konec
 jnb    PLUS,PL1
 lcall  CLRFUNC
 clr    PLUS
 PL1:
 xch    A,HOD
 add    A,#1
 da     A
 mov    HOD,A
 setb   DT
 cjne   A,#020h,KONECTL1
 mov    HOD,#0
 lcall  KONTROLUJNULY
KONECTL1:
setb	BCDA
clr     BCDB             ;T2 - MIN
mov     C,TLAC           ;cti stav
jc      KONECTL2         ;neni-li stisk, skoc dal
        ;telo T2 - MIN
 setb   STISK
 clr    PISKA
 clr    OKPISK
 jb     TR0,KONECTL2
 jnb    PLUS,PL2
 lcall  CLRFUNC
 clr    PLUS
 PL2:
 xch    A,MIN
 addc   A,#1
 da     A
 mov    MIN,A
 cjne   A,#060h,KONECTL2
 mov    MIN,#0
KONECTL2:

setb	BCDB
clr     BCDC             ;T3 - CLR
mov     C,TLAC           ;cti stav
jc      KONECTL3         ;neni-li stisk, skoc dal
        ;telo T3 - CLR (nastavi 0:00), zastavi citac
 setb   STISK
 clr    TR0
 lcall  CLRFUNC
KONECTL3:
setb	BCDC
clr     BCDD             ;T4
mov     C,TLAC           ;cti stav
jc      KONECTL4         ;neni-li stisk, skoc dal
        ;telo T4 - S/S Start/stop - neguje citani
 setb   STISK
 clr    PISKA
 clr    OKPISK
 cpl    TR0
 setb   DT
KONECTL4:
 LCALL  KONTROLUJCAS
 clr    BCDA
 clr    BCDB
 clr    BCDC
 clr    BCDD
 jnb    STISK,KONECTLACITEK
 mov    A,R2
 push   ACC
 mov    R2,#10
 KLOOP:
 mov    A,#080h
 lcall  CEKEJ
 setb   TLAC
 mov    C,TLAC           ;cti stav
 jc     KONECTLA         ;neni-li stisk, skoc dal
 djnz   R2,KLOOP
KONECTLA:
 pop    ACC
 mov    R2,A

KONECTLACITEK: 
RET

CLRFUNC:        ;vymaze citace
mov     TMOD,#00000010b   ;gate,c/t,m1,m0 - casovac s obvod. prednastavenim
mov     TCON,#01000000b   ;zablokovani citace 0 a povoleni 1
mov     IE,#11101010b     ;povol preruseni od citace 0 a 1
mov     IP,#11100010b     ;priorita
mov     A,#(100h-100)
mov     TH0,A
mov     TL0,#0

clr     OKPISK
clr     PISKA            ;piezo
clr     PIEZO
clr     LCD1
clr     LCD2
clr     LCD3
setb    LCD
setb    LCD50            ;obdelnik (dalsi zmena az v TIMER0)
setb    DT               ;dvojtecka
clr     T                ;tecka
setb    PLUS             ;plus
setb    MINUS            ;minus

mov     A,#100
mov     CITAC,A          ;citac po startu 25700d = 06464h
mov     CITAC+1,A
mov     DVOJT,#50
clr     A
mov     SEC,A            ;pocet sekund po startu - VSE V BCD
mov     MIN,A            ;pocet minut
mov     HOD,A            ;hodin
RET
;----------------------------------------------------------------------------
START:                   ;hlavni program
lcall   CLRFUNC
LOOP:
lcall   CTITLACITKA
ljmp    LOOP
END
