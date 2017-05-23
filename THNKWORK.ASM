                OPT F+      ;Fast-Load (siehe 68000er 11/89)
                OPT X+      ;Symboltabelle an (für den Debugger)
                IFEQ ^^SYMTAB
                DEFAULT 9
                OUTPUT 'TNHKWORK'
                ELSE
                DEFAULT 8
                ENDC

max_level       EQU 100     ;max.Anzahl der Level
;************************************************************************
;*                     Think & Work ST-Version                          *
;*       nach einer Idee von Johann Schilcher (Atari XL-Version)        *
;*          Die Level entsprechen den Leveln auf dem Atari XL           *
;* ©1989 by ∑-soft, written by Markus Fritze              13-15.01.1989 *
;*      ----------> Graphix by Harald Weinreich <-------------  1.2.'89 *
;************************************************************************
                BASE A6,varbase
                TEXT
                pea     start(PC)
                move.w  #$26,-(SP)
                trap    #14             ;Superexec(start)
                addq.l  #6,SP
                clr.w   -(SP)
                trap    #1              ;Pterm0()

start:          lea     varbase(PC),A6  ;Globale Offset-Variable
                bsr     init
                clr.w   akt_level(A6)   ;Nach dem Demo auf Level 1 schalten
                move.w  #-1,demo_level(A6) ;Start bei Level "-1" = Titeldemo
                bra     demo            ;Titeldemo laufen lassen
restart_clr:    clr.b   dir(A6)         ;Joystick-Richtungen löschen
restart:        move.w  save_level(A6),D0
                bmi.s   restart1
                move.w  D0,akt_level(A6) ;Level setzen
restart1:       clr.w   big_score(A6)   ;Gesamtscore löschen
                sf      demo_mode(A6)   ;Demo-Mode aus
                clr.w   timer2(A6)      ;Timer für den Demo-Mode löschen
                st      save_level(A6)  ;ungültig machen
                st      out_of_game(A6) ;Spiel nicht aktiv
                tst.w   level_anz(A6)   ;Level vorhanden?
                bne.s   menü_loop       ;ja, alles ok
                lea     all_level_data(A6),A0 ;Hier stehen die Level
                moveq   #15,D0
restart2:       tst.l   (A0)+           ;Level komplett leer?
                dbne    D0,restart2
                beq.s   menü_loop       ;ja! =>
                move.w  #1,level_anz(A6) ;Sonst ist min. ein Level vorhanden
menü_loop:      lea     text2(A6),A0
                bsr     print_text
                move.w  level_anz(A6),D1 ;Levelanzahl
                lea     restart(PC),A5  ;Rücksprungadr
                bsr     get_key         ;Tastatur auswerten, Joystick auch
                cmpi.w  #10*200,timer2(A6) ;Das Demo startet nach 10 Sekunden
                bcc     demo
                tst.b   dir(A6)         ;Feuertaste?
                bmi     play_game       ;dann das Spiel starten
                btst    #0,dir(A6)
                bne     inc_level
                btst    #1,dir(A6)
                bne     dec_level
                move.w  key(A6),D0
                subi.w  #$3B,D0
                bmi.s   menü_loop
                cmp.w   #9,D0           ;keine F-Taste ?
                bhi.s   menü_loop
                add.w   D0,D0
                move.w  menü_jumps(PC,D0.w),D0
                jmp     menü_jumps(PC,D0.w)

                BASE DC.W,menü_jumps
menü_jumps:     DC.W play_game,editor,dec_level,inc_level,joykey
                DC.W autorep,copyright,load_levels,save_levels,exit

;*******************************************************************************
;* Der Copyright-Hinweis                                                       *
;*******************************************************************************
copyright:      clr.w   timer2(A6)
                lea     copyright_txt(A6),A0
                bsr     print_text
copyright1:     bsr     get_key
                cmpi.w  #10*200,timer2(A6) ;Demo startet nach 10 Sekunden
                bcc     demo
                tst.w   key(A6)
                beq.s   copyright1
                jmp     (A5)

;*******************************************************************************
;* Der Leveleditor                                                             *
;*******************************************************************************
editor:         lea     all_level_data(A6),A4 ;Hier stehen die originalen Level
                move.w  akt_level(A6),D0
                lsl.w   #6,D0
                adda.w  D0,A4           ;Adresse des akt.editierten Levels
                movea.l A4,A1
                lea     level_buffer(A6),A0
                moveq   #15,D0
editor_save:    move.l  (A1)+,(A0)+     ;Level retten
                dbra    D0,editor_save
                sf      out_of_game(A6) ;Spiel aktiv (Blöcke setzen)
                moveq   #10,D6          ;aktuelle X-Koordinate
                moveq   #6,D7           ;aktuelle Y-Koordinate
                moveq   #2,D5           ;Wall selected
                clr.b   dir(A6)         ;Joystick-Daten löschen
editor_loop:    bsr     init_level      ;Levelarray aufbauen, Zeit löschen, etc.
                bsr     plot_level      ;Level zeichnen
                movea.l logbase(A6),A1
                move.w  D7,D0           ;Y*32*80
                mulu    #32*80,D0
                adda.w  D0,A1           ;zur logbase
                move.w  D6,D0
                lsl.w   #2,D0           ;X*4
                tst.b   rez(A6)         ;Farbe oder s/w
                bpl.s   editor_pnt1
                lea     farb_grafik+7*128(A6),A0
                add.w   D0,D0           ;X*8
                adda.w  D0,A1
                moveq   #15,D1
editor_pnt0:    move.l  (A0)+,D0        ;Cursor darstellen
                or.l    D0,(A1)+
                move.l  (A0)+,D0        ;Cursor darstellen
                or.l    D0,(A1)
                lea     156(A1),A1
                dbra    D1,editor_pnt0
                bra.s   editor_pnt2
editor_pnt1:    lea     mono_grafik+7*128(A6),A0
                adda.w  D0,A1           ;zur logbase
                moveq   #31,D1
editor_pointer: move.l  (A0)+,D0        ;Cursor darstellen
                eor.l   D0,(A1)
                lea     80(A1),A1
                dbra    D1,editor_pointer
editor_pnt2:    lea     text3(A6),A0
                bsr     print           ;untere Textzeile neu ausgeben
                bsr     switch_screen   ;Seite anzeigen
                bsr     get_key         ;Tastatur auswerten, Joystick auch
                btst    #0,dir(A6)      ;Joystickbewegung umsetzen
                beq.s   editor_jump1
                subq.w  #1,D7
                bpl.s   editor_jump1
                moveq   #0,D7
editor_jump1:   btst    #1,dir(A6)
                beq.s   editor_jump2
                cmp.w   #11,D7
                beq.s   editor_jump2
                addq.w  #1,D7
editor_jump2:   btst    #2,dir(A6)
                beq.s   editor_jump3
                subq.w  #1,D6
                bpl.s   editor_jump3
                moveq   #0,D6
editor_jump3:   btst    #3,dir(A6)
                beq.s   editor_jump4
                cmp.w   #19,D6
                beq.s   editor_jump4
                addq.w  #1,D6
editor_jump4:   tst.b   dir(A6)
                beq.s   editor_jump6
                bsr     verzögerung
editor_jump6:   btst    #7,dir(A6)      ;Feuertaste gedrückt
                bne     edt_draw
                clr.b   button_pressed(A6) ;Flag zurücksetzen
                lea     editor_keys-2(PC),A0
                move.w  key(A6),D0      ;aktuelle Taste holen
editor_jump5:   addq.l  #2,A0
                tst.w   (A0)
                bmi     editor_loop
                cmp.w   (A0)+,D0
                bne.s   editor_jump5
                adda.w  (A0),A0
                jmp     (A0)

                BASE DC.W,*
editor_keys:    DC.W $3B,edt_wall ;F1 - Mauer setzen
                DC.W $3C,edt_target ;F2 - Target setzen
                DC.W $3D,edt_block ;F3 - Block setzen
                DC.W $3E,edt_exit ;F4 - EXIT setzen
                DC.W $47,edt_clr_all ;Clr/Home - Level löschen
                DC.W $61,edt_undo ;UNDO - Level rekonstruieren
                DC.W $44,restart_clr ;F10 - Editor verlassen
                DC.W $39,edt_plot ;Space - Zeichen setzen
                DC.W $31,edt_new ;N - Neuen Level einrichten
                DC.W $53,edt_delete ;Delete - Level löschen
                DC.W -1

edt_delete:     bsr.s   edt_clr_all     ;Level erstmal löschen
                move.w  level_anz(A6),D0
                beq.s   edt_delete2     ;keine Level mehr da!
                subq.w  #1,D0
                move.w  D0,level_anz(A6)
                lea     all_level_data+64*max_level(A6),A0 ;Daten aller Level
                movea.l A4,A2
                lea     64(A4),A1
edt_delete1:    move.l  (A1)+,(A2)+     ;Level überkopieren
                cmpa.l  A0,A1
                bcs.s   edt_delete1
edt_delete2:    bra.s   edt_new1        ;ab in die Hauptschleife

edt_new:        move.w  level_anz(A6),D0
                cmp.w   #max_level-1,D0 ;max.100 Level
                beq.s   edt_new1
                move.w  D0,akt_level(A6)
                addq.w  #1,level_anz(A6)
                lea     all_level_data(A6),A4 ;Hier stehen die originalen Level
                lsl.w   #6,D0
                adda.w  D0,A4           ;Adresse des akt.editierten Levels
edt_clr_all:    movea.l A4,A1
                moveq   #15,D0          ;Level löschen
edt_clr_all1:   clr.l   (A1)+
                dbra    D0,edt_clr_all1
edt_new1:       bra     editor_loop     ;ab in die Hauptschleife

edt_wall:       moveq   #2,D5           ;Wand
                bra.s   edt_new1
edt_target:     moveq   #1,D5           ;Zielfeld
                bra.s   edt_new1
edt_block:      moveq   #3,D5           ;Block
                bra.s   edt_new1
edt_exit:       moveq   #-1,D5          ;Ausgang (nur zu verschieben)
                bra.s   edt_new1

edt_undo:       movea.l A4,A1
                lea     level_buffer(A6),A0
                moveq   #15,D0
edt_undo1:      move.l  (A0)+,(A1)+     ;Level zurückholen
                dbra    D0,edt_undo1
                bra.s   edt_new1

edt_plot:       clr.b   button_pressed(A6)
edt_draw:       tas.b   button_pressed(A6)
                bne.s   edt_draw1       ;war schon gedrückt
                moveq   #-1,D4          ;Löschen?
                bsr.s   edt_get         ;akt.Zeichen holen
                cmp.b   D0,D5
                beq.s   edt_draw1       ;steht dort was? =>
                moveq   #0,D4           ;sonst setzen
edt_draw1:      move.w  D5,D3
                tst.b   D4              ;setzen oder löschen?
                beq.s   edt_draw2       ;setzen
                moveq   #0,D3           ;löschen
edt_draw2:      tst.w   D5              ;Exit? (Ist nur verschiebbar)
                bpl.s   edt_draw3       ;Nein =>
                move.w  D6,D0
                add.b   D0,D0
                move.b  D0,60(A4)
                move.w  D7,D0
                add.b   D0,D0
                or.b    #$80,D0
                move.b  D0,61(A4)
                bra     editor_loop

edt_draw3:      move.w  D7,D0           ;Position im Level errechnen
                lsl.w   #2,D0
                add.w   D7,D0
                move.w  D6,D1
                lsr.w   #2,D1
                add.w   D1,D0           ;D0=5*Y+Int(X/4)
                moveq   #3,D1
                and.w   D6,D1           ;D1=X and %11
                move.b  edt_put_tab2(PC,D1.w),D2 ;Byte holen
                and.b   D2,0(A4,D0.w)   ;entsprechendes Feld löschen
                move.b  edt_put_tab(PC,D1.w),D1
                lsl.b   D1,D3           ;Element in Position schieben
                or.b    D3,0(A4,D0.w)   ;und einsetzen
                bra     editor_loop

edt_put_tab:    DC.B 6,4,2,0 ;Verschiebetabelle
edt_put_tab2:   DC.B $3F,$CF,$F3,$FC ;Löschmaske

edt_get:        move.w  D7,D0           ;Position im Level errechnen
                lsl.w   #2,D0
                add.w   D7,D0
                move.w  D6,D1
                lsr.w   #2,D1
                add.w   D1,D0           ;D0=5*Y+Int(X/4)
                moveq   #3,D1
                and.w   D6,D1           ;D1=X and %11
                move.b  edt_put_tab(PC,D1.w),D1 ;Byte holen
                move.b  0(A4,D0.w),D0   ;eines der 4 Felder isolieren
                lsr.b   D1,D0           ;in die unteren 2 Bit schieben
                and.w   #3,D0
                rts

;*******************************************************************************
;* Die restlichen F-Tasten                                                     *
;*******************************************************************************
load_levels:    move.l  #'load',D0
                bsr     do_dialog       ;Wirklich laden?
                beq     restart_clr     ;NEIN! =>
do_load_levels: move.w  #$2F,-(SP)
                trap    #1              ;Fgetdta()
                addq.l  #2,SP
                movea.l D0,A4           ;DTA-Buffer-Adr merken
                move.w  #7,-(SP)
                pea     fname(A6)
                move.w  #$4E,-(SP)
                trap    #1              ;Fsfirst(path,satt)
                addq.l  #8,SP
                tst.l   D0
                bmi.s   load_levelerr   ;nicht gefunden
                move.l  26(A4),D7       ;Länge der Datei
                moveq   #$3F,D0
                and.w   D7,D0
                bne.s   load_levelerr   ;Dateilänge nicht durch 64 teilbar
                clr.w   -(SP)
                pea     fname(A6)
                move.w  #$3D,-(SP)
                trap    #1              ;Fopen(path,attr)
                addq.l  #8,SP
                move.w  D0,D6           ;fhandle merken
                bmi.s   load_levelerr   ;??? TOS-Fehler
                pea     all_level_data(A6) ;Adresse des Buffers
                move.l  D7,-(SP)        ;Dateilänge
                move.w  D6,-(SP)        ;fhandle
                move.w  #$3F,-(SP)
                trap    #1              ;Fread(hndl,byts,buff)
                lea     12(SP),SP
                move.l  D0,D5
                move.w  D6,-(SP)
                move.w  #$3E,-(SP)
                trap    #1              ;Fclose(hndl)
                addq.l  #4,SP
                cmp.l   D5,D7
                bne.s   load_levelerr   ;Datei nicht komplett gelesen
                lsr.l   #6,D7
                move.w  D7,level_anz(A6) ;Anzahl der geladenen Level setzen
                moveq   #0,D0
                jmp     (A5)
load_levelerr:  lea     all_level_data(A6),A4
                bsr     edt_clr_all     ;1.Level löschen
                clr.w   level_anz(A6)   ;keine Level da!
                moveq   #-1,D0
                jmp     (A5)

save_levels:    move.l  #'save',D0
                bsr     do_dialog       ;Wirklich speichern?
                beq     restart_clr     ;NEIN! =>
                moveq   #0,D7
                move.w  level_anz(A6),D7
                beq.s   save_levelerr   ;keine Levels zum Speichern
                lsl.l   #6,D7           ;mal 64 (Levelgröße) = Dateilänge
                pea     fname(A6)
                move.w  #$41,-(SP)
                trap    #1              ;Fdelete(path)
                addq.l  #6,SP
                clr.w   -(SP)
                pea     fname(A6)
                move.w  #$3C,-(SP)
                trap    #1              ;Fcreate(path,attr)
                addq.l  #8,SP
                move.w  D0,D6           ;fhandle merken
                bmi.s   save_levelerr   ;??? TOS-Fehler
                pea     all_level_data(A6) ;Adresse des Buffers
                move.l  D7,-(SP)        ;Dateilänge
                move.w  D6,-(SP)        ;fhandle
                move.w  #$40,-(SP)
                trap    #1              ;Fwrite(hndl,byts,buff)
                lea     12(SP),SP
                move.l  D0,D5
                move.w  D6,-(SP)
                move.w  #$3E,-(SP)
                trap    #1              ;Fclose(hndl)
                addq.l  #4,SP
                cmp.l   D5,D7
                bne.s   save_levelerr   ;Datei nicht komplett geschrieben
                moveq   #0,D0
                jmp     (A5)
save_levelerr:  moveq   #-1,D0
                jmp     (A5)

inc_level:      addq.w  #1,akt_level(A6)
                cmp.w   akt_level(A6),D1
                bhi.s   inc_level1
                clr.w   akt_level(A6)
inc_level1:     jmp     (A5)

dec_level:      subq.w  #1,akt_level(A6)
                bpl.s   dec_level1
                tst.w   D1
                beq.s   dec_level2
                subq.w  #1,D1
dec_level2:     move.w  D1,akt_level(A6)
dec_level1:     jmp     (A5)

joykey:         lea     joy_text(A6),A0
                lea     joy1_txt(A6),A1 ;Joystick
                cmpi.b  #'K',(A0)
                beq.s   joykey1
                lea     joy2_txt(A6),A1 ;Keyboard
joykey1:        move.b  (A1)+,(A0)+
                bne.s   joykey1
                move.b  #' ',-(A0)
                jmp     (A5)

autorep:        bchg    #1,$0484.w
                bsr     set_autorep_txt
                jmp     (A5)

;*******************************************************************************
;* Ein kleines Demo für den Titel & Level 1                                    *
;*******************************************************************************
demo:           move.w  akt_level(A6),save_level(A6) ;akt.Level merken
                move.w  demo_level(A6),D0
                addq.w  #1,D0
                and.w   #1,D0
                move.w  D0,demo_level(A6)
                subq.w  #1,D0           ;Die Demo-Level zählen ab 0
                move.w  D0,akt_level(A6) ;Die normalen Level zählen ab -1
                st      demo_mode(A6)   ;Demo-Mode an
                st      demo_count2(A6) ;gespeicherte Schritte löschen
                clr.w   demo_count(A6)  ;Demo-Position auf den Anfang setzen
demo1:

;*******************************************************************************
;* Die Hauptroutine: Das Game                                                  *
;*******************************************************************************
play_game:      sf      out_of_game(A6) ;Spiel nun aktiv
                bsr     init_level      ;Levelarray aufbauen, Zeit löschen, etc.
                st      timer_stop(A6)  ;Uhr starten
play_game1:     bsr     plot_level      ;Level zeichnen
                bsr     update_line     ;untere Textzeile neu ausgeben
                bsr     switch_screen   ;Seite anzeigen
                bsr     get_key         ;Tastatur auswerten, Joystick auch
                move.w  key(A6),D0
                tst.b   demo_mode(A6)   ;Demo an?
                beq.s   play_game11     ;Dann geht's hinten weiter ...
                tst.w   D0              ;Taste gedrückt?
                bne     restart_clr     ;dann Ende
play_game11:    cmpi.w  #$44,D0         ;F10 - Abbruch
                beq     restart_clr
                cmpi.w  #$61,D0         ;UNDO - Level neu starten
                beq.s   play_game       ;Level-Neustart
                cmpi.w  #$39,D0         ;Pause
                bne.s   play_game5      ;Nein! =>
                clr.b   timer_stop(A6)  ;Uhr stoppen
                movea.l logbase(A6),A0  ;2. Seite ist am Anfang "logbase"
                move.w  #7999,D0
                moveq   #-1,D1
play_game2:     move.l  D1,(A0)+        ;logbase löschen
                dbra    D0,play_game2
                bsr     switch_screen   ;und schwarze Seite anzeigen
                clr.w   key(A6)
                clr.b   dir(A6)
play_game3:     bsr     get_key
                tst.w   key(A6)         ;weiter, wenn Taste gedrückt
                bne.s   play_game4
                tst.b   dir(A6)         ;oder Joystick bewegt
                beq.s   play_game3
play_game4:     st      timer_stop(A6)  ;Uhr wieder starten
play_game5:     bsr     movement        ;Spieler bewegen
                bsr.s   check_win       ;Alle Steine ok?
                beq.s   play_game1      ;Nein, noch nicht.

                tst.b   demo_mode(A6)
                bne     restart_clr     ;Ende des Demos

                move.w  akt_score(A6),D0 ;erreichtes Levelergebnis holen
                cmp.w   hiscore(A6),D0  ;> der Hiscore?
                bls.s   play_game6      ;NEIN! => kein neuer Hiscore ...
                move.w  D0,hiscore(A6)  ;wird allerdings gleich gelöscht
                lea     all_level_data(A6),A0 ;Hier steht der originale Level
                move.w  akt_level(A6),D1
                muls    #64,D1          ;Da auch "-1" möglich ist!!!
                move.w  D0,62(A0,D1.w)  ;Hiscore auch im Level setzen
play_game6:     add.w   D0,big_score(A6) ;und zum Gesamtscore addieren

                move.w  akt_level(A6),D0
                move.w  level_anz(A6),D1
                beq     restart_clr     ;Ende, wenn nur ein Level vorhanden
                addq.w  #1,D0           ;nächster Level
                move.w  D0,akt_level(A6)
                cmp.w   D1,D0           ;höchster Level erreicht
                bcs     play_game       ;Nächsten Level
                subq.w  #1,akt_level(A6)
                bra     restart_clr     ;und Ende

;*******************************************************************************
;* Sind alle Steine am richtigen Ort? (Z=1, wenn nicht)                        *
;*******************************************************************************
check_win:      movem.l D0-D1/A0,-(SP)
                lea     level_dat(A6),A0 ;Hier steht der Level
                move.w  #22*15-1,D0     ;Feldgröße
                moveq   #0,D1
check_win1:     cmpi.b  #8|6,(A0)       ;Spieler auf Exit?
                bne.s   check_win2
                moveq   #-1,D1          ;Flag dafür setzen
check_win2:     cmpi.b  #3,(A0)+
                dbeq    D0,check_win1   ;Nein, noch nicht
                beq.s   check_win3
                clr.b   timer_stop(A6)  ;Uhr anhalten
                tst.b   D1              ;Spieler auf dem Ausgang? Z=1, wenn nicht
check_win3:     movem.l (SP)+,D0-D1/A0
                rts

;*******************************************************************************
;* Score um einen Punkt erniedrigen                                            *
;*******************************************************************************
score_down:     tst.w   demo_mode(A6)   ;Demo-Mode an?
                bne.s   score_down0     ;dann Score löschen
                subq.w  #1,akt_score(A6) ;sonst ein Punkt abziehen
                bpl.s   score_down1     ;Ende, wenn noch positiv
score_down0:    clr.w   akt_score(A6)   ;sonst Score löschen
score_down1:    rts

;*******************************************************************************
;* Bewegung des Spieler und Verschieben der Objekte                            *
;*******************************************************************************
movement:       move.w  akt_koord_y(A6),D0
                move.w  akt_koord_x(A6),D1
                bsr     get_char

                moveq   #0,D6
                moveq   #0,D7
                btst    #3,dir(A6)      ;Cursor right?
                beq.s   movement1
                moveq   #1,D6
                bsr     move_check
                ble.s   movement4       ;Feld ist gültig
                moveq   #0,D6
                bra.s   movement4

movement1:      lsr.w   #8,D3
                btst    #2,dir(A6)      ;Cursor left?
                beq.s   movement2
                moveq   #-1,D6
                bsr.s   move_check
                ble.s   movement4       ;Feld ist gültig
                moveq   #0,D6
                bra.s   movement4

movement2:      swap    D3
                btst    #1,dir(A6)      ;Cursor down?
                beq.s   movement3
                moveq   #1,D7
                bsr.s   move_check
                ble.s   movement4       ;Feld ist gültig
                moveq   #0,D7
                bra.s   movement4

movement3:      lsr.w   #8,D3
                btst    #0,dir(A6)      ;Cursor up?
                beq.s   movement4
                moveq   #-1,D7
                bsr.s   move_check
                ble.s   movement4       ;Feld ist gültig
                moveq   #0,D7
movement4:      bsr     clear_object    ;Object an (D0;D1) entfernen
                add.w   D7,D0
                add.w   D6,D1
                move.w  D0,akt_koord_y(A6)
                move.w  D1,akt_koord_x(A6)
                moveq   #-1,D2          ;Spieler setzen
                bsr     set_object      ;Object an (D0;D1) setzen
                tst.w   D7
                bne.s   movement5
                tst.w   D6
                beq.s   move_end
movement5:      addq.w  #1,moves(A6)
                bsr     verzögerung
move_end:       btst    #1,$0484.w
                bne.s   move_end2
                btst    #7,dir(A6)      ;Feuertaste?
                bne.s   move_end2       ;dann Autorepeat
                clr.b   dir(A6)         ;Joystick-Daten löschen
move_end2:      rts

move_tab:       DC.B 1,0,0,-1,-1,0
move_check:     ext.w   D3
                move.b  move_tab(PC,D3.w),D5
                bpl.s   move_checke     ;Mauer oder nix => Fertig
                movem.l D0-A6,-(SP)     ;Block bewegen
                add.w   D7,D0           ;Position des Blockes errechnen
                add.w   D6,D1
                bsr     get_char        ;Umgebung des Blocks holen
                moveq   #0,D2
                cmp.b   #1,D6           ;nach rechts?
                beq.s   move_check1
                moveq   #8,D2
                cmp.b   #-1,D6
                beq.s   move_check1
                moveq   #16,D2
                cmp.b   #1,D7
                beq.s   move_check1
                moveq   #24,D2
                cmp.b   #-1,D7
                bne.s   move_checke1    ;Keine gültige Bewegung
move_check1:    lsr.l   D2,D3
                subq.b  #1,D3           ;Hintergrund ist möglich
                beq.s   move_check2
                subq.b  #1,D3           ;Zielfeld ist möglich
                bne.s   move_checke1
move_check2:    bsr.s   clear_object
                add.w   D7,D0           ;Zielposition des Blockes errechnen
                add.w   D6,D1
                moveq   #0,D2
                bsr.s   set_object
                addq.w  #1,pushes(A6)   ;Verschiebungen+1
                bsr     score_down
                bsr     score_down
                bsr     score_down
                bsr     score_down      ;fünf Punkte weniger
                moveq   #0,D0           ;Bewegung ist möglich
                movem.l (SP)+,D0-A6
                rts
move_checke1:   moveq   #1,D0           ;Bewegung nicht möglich
                movem.l (SP)+,D0-A6
move_checke:    rts

;*******************************************************************************
;* Objekt an (D1;D0) löschen                                                   *
;*******************************************************************************
clear_object:   movem.l D0-D1,-(SP)
                mulu    #22,D0          ;Y*22
                add.w   D1,D0           ;+X
                lea     level_dat(A6),A0 ;Hier steht der Level
                lea     0(A0,D0.w),A0   ;Adresse des Feldes
                move.b  (A0),D1         ;Object holen
                cmp.b   #4,D1           ;Diamand an?
                bne.s   clear_object1   ;Weg, wenn nicht
                move.b  #2,(A0)         ;Zielfeld setzen
                bra.s   clear_objecte
clear_object1:  lsr.b   #3,D1
                moveq   #1,D0           ;freies Feld
                tst.b   D1
                beq.s   clear_object2   ;Nix los!
                moveq   #5,D0           ;Exit
                subq.b  #1,D1
                beq.s   clear_object2
                moveq   #2,D0           ;Zielfeld
clear_object2:  move.b  D0,(A0)         ;Hintergrund setzen
clear_objecte:  movem.l (SP)+,D0-D1
                rts

;*******************************************************************************
;* Mauer oder Spieler an (D1;D0) setzen (D2<0: Spieler)                        *
;*******************************************************************************
set_object:     movem.l D0-D1,-(SP)
                mulu    #22,D0          ;Y*22
                add.w   D1,D0           ;+X
                lea     level_dat(A6),A0 ;Hier steht der Level
                lea     0(A0,D0.w),A0   ;Adresse der Position
                move.b  (A0),D1         ;Object holen
                tst.b   D2              ;Block oder Spieler
                bmi.s   set_object1     ;der Spieler =>
                moveq   #3,D0           ;Diamant aus
                subq.b  #1,D1           ;Leeres Feld
                beq.s   set_object2
                moveq   #4,D0           ;Diamant an
                subq.b  #1,D1           ;Zielfeld
                bne.s   set_objecte
                bra.s   set_object2

set_object1:    moveq   #6,D0           ;Spieler auf freiem Feld
                subq.b  #1,D1
                beq.s   set_object2
                moveq   #6|16,D0        ;Spieler auf Zielfeld
                subq.b  #1,D1
                beq.s   set_object2
                moveq   #6|8,D0         ;Spieler auf Exit
                subq.b  #3,D1
                bne.s   set_objecte
set_object2:    move.b  D0,(A0)
set_objecte:    movem.l (SP)+,D0-D1
                rts

;*******************************************************************************
;* Level nach level_dat umkopieren und in ein erweitertes Format wandeln       *
;*******************************************************************************
init_level:     movem.l D0-A6,-(SP)
                clr.b   timer_stop(A6)  ;Uhr anhalten
                clr.w   moves(A6)       ;Bewegungen löschen
                clr.w   pushes(A6)      ;Verschiebungen löschen
                moveq   #'0',D0
                move.b  D0,time_std_txt(A6)
                move.b  D0,time_min_txt(A6) ;Uhrzeit löschen
                move.b  D0,time_min_txt+1(A6)
                move.b  D0,time_sek_txt(A6)
                move.b  D0,time_sek_txt+1(A6)
                lea     all_level_data(A6),A0 ;Hier steht der originale Level
                move.w  akt_level(A6),D0
                muls    #64,D0          ;Da auch "-1" möglich ist!!!
                adda.w  D0,A0
                lea     level_dat+23(A6),A1 ;und hier soll er hin
                lea     init_leveltab(PC),A2
                move.l  #$01020001,(A2)
                tst.b   out_of_game(A6)
                bne.s   init_level0
                move.l  #$01020003,(A2)
init_level0:    moveq   #11,D1          ;12 Zeilen kopieren
init_level1:    moveq   #4,D0           ;5 Byte pro Zeile
init_level2:    move.b  (A0)+,D2
                moveq   #3,D4           ;4 Felder pro Byte
init_level3:    rol.b   #2,D2
                moveq   #3,D3
                and.b   D2,D3
                move.b  0(A2,D3.w),(A1)+
                dbra    D4,init_level3
                dbra    D0,init_level2
                addq.l  #2,A1           ;rechten & linken Rand überspringen
                dbra    D1,init_level1
                moveq   #0,D0
                move.b  (A0)+,D0
                lsr.b   #1,D0           ;X-Koordinate des Starts holen
                addq.w  #1,D0
                move.w  D0,D1
                swap    D0
                move.b  (A0)+,D0
                and.b   #$7F,D0         ;oberstes Bit löschen
                lsr.b   #1,D0           ;Y-Koordinate des Starts holen
                addq.w  #1,D0
                move.l  D0,akt_koord_x(A6) ;aktuelle Spielerkoordinate
                mulu    #22,D0          ;Y*22
                add.w   D1,D0           ;+X
                move.w  (A0),hiscore(A6) ;Highscore setzen
                lea     level_dat(A6),A0 ;Hier steht der originale Level
                move.b  #6|8,0(A0,D0.w) ;Player auf Exit setzen
                clr.w   akt_score(A6)
                move.w  #22*15-1,D0
                moveq   #0,D1
init_level4:    cmpi.b  #2,(A0)+        ;Anzahl der Ziel-Felder ermitteln
                beq.s   init_level5
                cmpi.b  #4,-1(A0)       ;Block auf Zielfeld
                bne.s   init_level6
init_level5:    addi.w  #100,akt_score(A6) ;pro Feld 100 Punkte mehr
init_level6:    dbra    D0,init_level4
                movem.l (SP)+,D0-A6
                rts
init_leveltab:  DC.B 1,2,0,3

;*******************************************************************************
;* Level nach logbase zeichnen                                                 *
;*******************************************************************************
plot_level:     tst.b   rez(A6)         ;Farbmonitor?
                bmi     plotc_level     ;Level in Farbe zeichnen
                movem.l D0-A6,-(SP)
                lea     level_dat(A6),A0 ;Level-Daten
                movea.l logbase(A6),A1  ;Bildschirmadresse
                lea     mono_grafik(A6),A2 ;Grafik-Daten
                moveq   #1,D0           ;Zeile=1
plot_level1:    moveq   #1,D1           ;Spalte=1
plot_level2:    bsr     get_char        ;Zeichen an der Position ermitteln
                and.w   #7,D2           ;Zusatzsbits ausmaskieren
                beq.s   plot_level6     ;Die Wand bekommt eine Extra-Behandlung
                lsl.w   #7,D2
                lea     0(A2,D2.w),A3
                movea.l A1,A4
                moveq   #31,D4          ;32 Pixelzeilen kopieren
plot_level3:    move.l  (A3)+,(A4)      ;Zeichen kopieren
                lea     80(A4),A4
                dbra    D4,plot_level3
plot_level4:    addq.l  #4,A1           ;Nächste Bildschirmposition
                addq.w  #1,D1
                cmp.w   #21,D1          ;Zeile voll?
                bne.s   plot_level2     ;nein, noch nicht
                lea     31*80(A1),A1    ;Nächstes Bildschirmposition errechnen
                addq.w  #1,D0
                cmp.w   #13,D0          ;letzte Zeile bereits ausgegeben?
                bne.s   plot_level1     ;Nein! Oben geht's weiter ^^^
                lea     -80(A1),A1
                moveq   #19,D0
                moveq   #-1,D1
plot_level5:    move.l  D1,(A1)+        ;untere Linie ziehen
                dbra    D0,plot_level5
                movem.l (SP)+,D0-A6
                rts

;Wände erfahren eine Sonderbehandlung, da evtl.Rahmen gezeichnet werden müssen
plot_level6:    movea.l A2,A3
                movea.l A1,A4
                moveq   #30,D4          ;31 Pixelzeilen kopieren
plot_level7:    move.l  (A3)+,D5
                cmp.w   #30,D4          ;1.Zeile?
                bne.s   plot_level71    ;Weiter, wenn nicht
                move.l  #$FF000000,D2
                and.l   D3,D2           ;Oben eine Mauer?
                beq.s   plot_level71    ;Ende, wenn ja
                moveq   #-1,D5          ;sonst oben eine Linie ziehen
                bra.s   plot_level91
plot_level71:   tst.b   D3              ;Ist rechts eine Wand?
                beq.s   plot_level8     ;Nein! =>
                or.b    #1,D5           ;Dann Wand rechts abschließen
plot_level8:    ror.w   #8,D3
                tst.b   D3              ;Ist links auch eine Wand?
                beq.s   plot_level9     ;Nein! =>
                bset    #31,D5          ;Dann Wand links abschließen
plot_level9:    rol.w   #8,D3           ;Wert wieder rekonstruieren
plot_level91:   move.l  D5,(A4)         ;Pixelzeile schreiben
                lea     80(A4),A4       ;Nächste Pixelzeile
                dbra    D4,plot_level7

;Nun kommt die Abhandlung der 31. & letzten Pixelzeile einer Wand:
                move.l  (A3)+,D5        ;letzte Pixelzeile holen
                swap    D3
                tst.b   D3              ;Ist unten auch eine Wand?
                beq.s   plot_level11    ;Ja! =>
                moveq   #-1,D5          ;sonst eine Linie ziehen

;Ab hier werden evtl. zwei einzelne Punkte gesetzt, welche einen sonst
;erkennbaren Schönheitsfehler korrigieren.
;z.B:   Wand1 Wand2
;       Leer  Wand3
;Es wird bei Wand2 ein Pixel in der linken unteren Ecke gesetzt (Eckstück)
;2. Möglichkeit: Wand1 Wand2
;                Wand3 Leer
;Hier wird bei Wand1 ein Pixel in der rechten unteren Ecke gesetzt
plot_level11:   addq.w  #1,D0           ;Zeile+1 (dewegen unten zwei Wandzeilen!)
                bsr     get_char        ;umgebende Zeichen der nächsten Zeile holen
                subq.w  #1,D0           ;Zeile wieder zurück
                tst.b   D3              ;rechts auch eine Wand?
                beq.s   plot_level12    ;dann nichts tun =>
                or.b    #1,D5           ;rechts einen Punkt setzen
plot_level12:   ror.w   #8,D3
                tst.b   D3              ;links auch eine Wand?
                beq.s   plot_level13    ;dann nichts tun =>
                bset    #31,D5          ;links einen Punkt setzen
plot_level13:   move.l  D5,(A4)         ;letzte Pixelzeile schreiben
                bra     plot_level4     ;Nächstes Zeichen ausgeben

;*******************************************************************************
;* Level in Farbe nach logbase zeichnen                                        *
;*******************************************************************************
plotc_level:    tst.b   demo_mode(A6)   ;Im Demo keine Verzögerung
                bne.s   plotc_level0
                bsr.s   plotc_level0    ;3 mal zeichnen => etwa die monochrom
                bsr     plotc_level0    ;Geschwindigkeit
plotc_level0:   movem.l D0-A6,-(SP)
                lea     level_dat(A6),A0 ;Level-Daten
                movea.l logbase(A6),A1  ;Bildschirmadresse
                lea     farb_grafik(A6),A2 ;Grafik-Daten
                moveq   #1,D0           ;Zeile=1
plotc_level1:   moveq   #1,D1           ;Spalte=1
plotc_level2:   bsr.s   get_char        ;Zeichen an der Position ermitteln
                and.w   #7,D2           ;Zusatzsbits ausmaskieren
                lsl.w   #7,D2
                lea     0(A2,D2.w),A3   ;Adresse der Grafiken
                movea.l A1,A4
                moveq   #15,D4          ;16 Pixelzeilen kopieren
plotc_level3:   move.l  (A3)+,(A4)+     ;Zeichen kopieren
                move.l  (A3)+,(A4)
                lea     156(A4),A4
                dbra    D4,plotc_level3
                addq.l  #8,A1           ;Nächste Bildschirmposition
                addq.w  #1,D1
                cmp.w   #21,D1          ;Zeile voll?
                bne.s   plotc_level2    ;nein, noch nicht
                lea     15*160(A1),A1   ;Nächstes Bildschirmposition errechnen
                addq.w  #1,D0
                cmp.w   #13,D0          ;letzte Zeile bereits ausgegeben?
                bne.s   plotc_level1    ;Nein! Oben geht's weiter ^^^
                lea     -160(A1),A1
                moveq   #39,D0
                moveq   #-1,D1
plotc_level5:   move.w  D1,(A1)+        ;untere Linie ziehen
                clr.w   (A1)+
                dbra    D0,plotc_level5
                movem.l (SP)+,D0-A6
                rts

;*******************************************************************************
;* Zeichen um bzw. an einer bestimmten Position ermitteln                      *
;* => D0.W:Zeile (1-12)                                                        *
;*    D1.W:Spalte (1-20)                                                       *
;* <= D2.W:aktuelles Zeichen (5, siehe Tabelle unten)                          *
;*    D3.L:Byte 3 - oberes Zeichen (2)                                         *
;*         Byte 2 - unteres Zeichen (8)                                        *
;*         Byte 1 - linkes Zeichen (4)                                         *
;*         Byte 0 - rechtes Zeichen (6)                                        *
;*    1 2 3                                                                    *
;*    4 5 6                                                                    *
;*    7 8 9                                                                    *
;*******************************************************************************
get_char:       lea     level_dat(A6),A0 ;Level-Daten
                move.w  D0,D2
                mulu    #22,D2          ;Zeile*22
                add.w   D1,D2           ;+Spalte
                lea     0(A0,D2.w),A0   ;Adresse des aktuellen Zeichens
                movep.w -22(A0),D3      ;oberes Zeichen holen
                move.b  22(A0),D3       ;unteres Zeichen holen
                swap    D3
                movep.w -1(A0),D3       ;linkes & rechtes Zeichen holen
                move.b  (A0),D2         ;aktuelles Zeichen holen
                ext.w   D2
                rts

;*******************************************************************************
;* Verzögerung bei Bewegung des Joysticks (Spiel sich besser)                  *
;*******************************************************************************
verzögerung:    move.w  #20000,D0
verzögerung1:   dbra    D0,verzögerung1
                rts

;*******************************************************************************
;* Taste holen (D0=0, wenn keine gedrückt, sonst D0.W=Scancode der Taste)      *
;*******************************************************************************
get_key:        movem.l D0-D2/A0-A2,-(SP)
                move.w  #$0B,-(SP)
                trap    #1              ;Cconis()
                addq.l  #2,SP
                tst.l   D0              ;Taste gedrückt?
                beq.s   get_key1        ;Nein, dann weiter
                move.w  #7,-(SP)
                trap    #1              ;Crawin()
                addq.l  #2,SP
                swap    D0              ;Scancode nach unten
get_key1:       move.w  D0,key(A6)      ;Tastencode merken
                tst.b   demo_mode(A6)   ;Demo-Mode aktiv?
                bne.s   get_demo        ;Richtungen für's Demo holen
                cmpi.b  #'J',joy_text(A6)
                beq.s   get_key3        ;Joystick-Steuerung
                clr.b   dir(A6)         ;Richtungen löschen
                lea     key_tab-1(PC),A0
get_key2:       tst.b   (A0)+
                bmi.s   get_key3
                cmp.b   (A0)+,D0
                bne.s   get_key2
                move.b  (A0),dir(A6)
get_key3:       movem.l (SP)+,D0-D2/A0-A2
                rts
                DC.B 0
key_tab:        DC.B $4D,8,$4B,4,$50,2,$48,1,-1,-1 ;Joystick-Richtungen
                EVEN

get_demo:       tst.b   demo_count2(A6)
                bpl.s   get_demo1
                move.w  demo_level(A6),D0
                add.w   D0,D0           ;und mal 2
                lea     demo_level_tab(PC),A0
                adda.w  0(A0,D0.w),A0   ;Adresse der Demo-Daten des Levels
                move.w  demo_count(A6),D0
                move.b  0(A0,D0.w),D0
                beq.s   get_demo2       ;Ende des Demos (nix mehr tun)
                addq.w  #1,demo_count(A6)
                move.b  D0,D1
                lsr.b   #4,D1           ;Anzahl isolieren
                move.b  D1,demo_count2(A6)
                and.b   #$0F,D0
                move.b  D0,demo_dir(A6) ;Richtung merken
get_demo1:      subq.b  #1,demo_count2(A6)
                move.b  demo_dir(A6),D0
get_demo2:      move.b  D0,dir(A6)
                movem.l (SP)+,D0-D2/A0-A2
                rts
                BASE DC.W,demo_level_tab
demo_level_tab: DC.W demo_titel,demo_level1
demo_titel:     DC.B $41,$68,$02,$08,$01,$08,$01,$F4,$14,$02,$04,$31
                DC.B $22,$C8,$11,$04,$02,$08,$02,$B4,$02,$04,$21
                DC.B $12,$58,$11,$04,$02,$08,$02,$44,$02,$04,$11
                DC.B $12,$18,$12,$08,$11,$08,$01,$24,$02,$04,$01
                DC.B $02,$98,$42
demo_level1:    DC.B $44,$42,$14,$12,$08,$12,$04,$31,$08,$01,$14,$01,$04,$42
                DC.B $31,$18,$22,$28,$02,$18,$01,$34,$02,$04,$21,$08,$01,$14
                DC.B $01,$04,$32
                DC.B $21,$18,$22,$38,$11,$28,$12,$54,$02,$04,$21,$08,$01,$14
                DC.B $01,$04,$22
                DC.B $11,$18,$22,$38,$11,$08,$02,$01,$18,$12,$54,$02,$04,$21
                DC.B $08,$01,$14,$01,$04,$12
                DC.B $11,$34,$01,$34,$11,$08,$02,$04,$02,$08,$38,$01,$08,$12
                DC.B $04,$02,$18,$01,$08,$42
                DC.B $31,$44,$02,$14,$01,$58,$01,$08,$32
                DC.B $21,$64,$32,$18,$21,$04,$01,$48,$01,$08,$22
                DC.B $11,$44,$32,$28,$11,$04,$02,$08,$02,$24,$02,$14,$01,$08
                DC.B $02,$08,$31,$04,$01,$48,$01,$08,$22
                DC.B $01,$48,$31,$48
                EVEN

;*******************************************************************************
;* Autorepeat-Ausgabe setzen                                                   *
;*******************************************************************************
set_autorep_txt:lea     autorep_text(A6),A0
                btst    #1,$0484.w
                bne.s   set_autorep1
                move.b  #'f',(A0)+      ;'off'
                move.b  #'f',(A0)
                rts
set_autorep1:   move.b  #'n',(A0)+      ;'on '
                move.b  #' ',(A0)+
                rts

;*******************************************************************************
;* switch_screen: Physbase & Logbase vertauschen                               *
;*******************************************************************************
switch_screen:  movem.l D0-D2/A0-A2,-(SP)
                move.l  physbase(A6),D0
                move.l  logbase(A6),D1
                move.l  D1,physbase(A6)
                move.l  D0,logbase(A6)
                move.w  #-1,-(SP)
                move.l  D1,-(SP)
                move.l  D0,-(SP)
                move.w  #5,-(SP)
                trap    #14
                lea     12(SP),SP
                movem.l (SP)+,D0-D2/A0-A2
                rts

;*******************************************************************************
;* Untere Zeile neu ausgeben                                                   *
;*******************************************************************************
update_line:    movem.l D0-A6,-(SP)
                moveq   #0,D0
                move.w  akt_level(A6),D0
                addq.w  #1,D0
                divu    #10,D0
                or.l    #$300030,D0
                move.b  D0,level_txt(A6) ;Levelnummer einsetzen
                move.b  D0,level_text(A6)
                swap    D0
                move.b  D0,level_txt+1(A6)
                move.b  D0,level_text+1(A6)
                moveq   #0,D0
                move.w  moves(A6),D0
                moveq   #3,D4
                lea     moves_txt(A6),A0
                bsr     dez_out

                move.w  pushes(A6),D0
                moveq   #3,D4
                lea     pushes_txt(A6),A0
                bsr     dez_out

                move.w  akt_score(A6),D0
                add.w   big_score(A6),D0
                moveq   #3,D4
                lea     score_txt(A6),A0
                bsr     dez_out

                move.w  hiscore(A6),D0
                lea     hiscore_txt(A6),A0
                bsr     dez_out

                lea     text(A6),A0     ;und ausgeben
                bsr.s   print
                movem.l (SP)+,D0-A6
                rts

;*******************************************************************************
;* Frage in D0 stellen, auf "Y" oder "Z" bzw. "N" warten                       *
;*******************************************************************************
do_dialog:      moveq   #3,D1
                lea     dialog_string(A6),A0
do_dialog0:     rol.l   #8,D0           ;die vier Zeichen übertragen
                move.b  D0,(A0)+
                dbra    D1,do_dialog0
                lea     dialog_txt(A6),A0
                bsr.s   print_text      ;String ausgeben
do_dialog1:     bsr     get_key         ;Tastatur auswerten
                move.w  key(A6),D0      ;Taste holen
                cmp.w   #$31,D0
                beq.s   do_dialog2
                cmp.w   #$15,D0         ;Z
                beq.s   do_dialog2
                cmp.w   #$2C,D0         ;Y
                bne.s   do_dialog1
do_dialog2:     sub.w   #$31,D0         ;0= NEIN, <>0= JA
                rts

;*******************************************************************************
;* Text ab A0 ausgeben, aber ganze Seite auch noch neu ausgeben                *
;*******************************************************************************
print_text:     bsr     init_level      ;Level intern entpacken
                bsr     plot_level      ;Level zeichnen
                bsr     update_line     ;untere Textzeile neu ausgeben
                bsr.s   print           ;Text ausgeben
                bra     switch_screen   ;Bildschirmseiten umschalten

;*******************************************************************************
;* Text ab A0 ausgeben                                                         *
;*******************************************************************************
print:          movem.l D0-D4/A0-A3,-(SP)
                tst.b   rez(A6)         ;Farbmonitor?
                bmi.s   print_color0    ;ja! =>
print0:         moveq   #0,D1
                move.b  (A0)+,D1        ;Spalte holen
                moveq   #0,D0
                move.b  (A0)+,D0        ;Zeile holen
                mulu    #16*80,D0       ;Spaltenoffset errechnen
                add.w   D1,D0           ;Spalte dazu
                movea.l logbase(A6),A1
                adda.w  D0,A1           ;Adresse auf dem Schirm
                movea.l font_adr(A6),A2 ;Adresse des 16x16-Fonts
print1:         moveq   #0,D0
                move.b  (A0)+,D0        ;Zeichen holen
                beq.s   print3          ;Ende des Strings
                cmp.b   #$FF,D0         ;Noch ein String
                beq.s   print0          ;nächste Koordinate holen
                moveq   #0,D2           ;nur einmal ausgeben
                cmp.b   #1,D0           ;Zeichen mehrfach ausgeben?
                bne.s   print4
                move.b  (A0)+,D2        ;Anzahl holen
                moveq   #' ',D0         ;Space ausgeben
print4:         lea     0(A2,D0.w),A3   ;Adresse des Zeichens
                moveq   #15,D1          ;16 Pixelzeilen ausgeben
print2:         move.b  (A3),D4
                not.b   D4              ;Zeichen invertieren
                move.b  D4,(A1)
                lea     256(A3),A3
                lea     80(A1),A1
                dbra    D1,print2
                lea     -16*80+1(A1),A1 ;Pointer auf das nächste Zeichen
                dbra    D2,print4       ;Zeichen mehrfach ausgeben?
                bra.s   print1
print3:         movem.l (SP)+,D0-D4/A0-A3
                rts
print_color0:   moveq   #0,D1
                move.b  (A0)+,D1        ;Spalte holen
                moveq   #1,D2
                and.w   D1,D2
                and.w   #-2,D1
                add.w   D1,D1
                add.w   D2,D1
                moveq   #0,D0
                move.b  (A0)+,D0        ;Zeile holen
                mulu    #8*160,D0       ;Spaltenoffset errechnen
                add.w   D1,D0           ;Spalte dazu
                movea.l logbase(A6),A1
                adda.w  D0,A1           ;Adresse auf dem Schirm
                movea.l font_adr+4(A6),A2 ;Adresse des 16x16-Fonts
print_color1:   moveq   #0,D0
                move.b  (A0)+,D0        ;Zeichen holen
                beq.s   print3          ;Ende des Strings
                cmp.b   #$FF,D0         ;Noch ein String
                beq.s   print_color0    ;nächste Koordinate holen
                moveq   #0,D2           ;nur einmal ausgeben
                cmp.b   #1,D0           ;Zeichen mehrfach ausgeben?
                bne.s   print_color4
                move.b  (A0)+,D2        ;Anzahl holen
                moveq   #' ',D0         ;Space ausgeben
print_color4:   lea     0(A2,D0.w),A3   ;Adresse des Zeichens
                moveq   #7,D1           ;8 Pixelzeilen ausgeben
print_color2:   move.b  (A3),D4
                not.b   D4              ;Zeichen invertieren
                move.b  D4,(A1)
                clr.b   2(A1)
                lea     256(A3),A3
                lea     160(A1),A1
                dbra    D1,print_color2
                lea     -8*160+1(A1),A1 ;Pointer auf das nächste Zeichen
                move.w  A1,D4
                btst    #0,D4
                bne.s   print_color5
                addq.l  #2,A1
print_color5:   dbra    D2,print_color4
                bra.s   print_color1

;************************************************************************
;* Dezimal-Zahl in D0 nach A0 ausgeben                                  *
;* Anzahl der Stellen in D4                                             *
;************************************************************************
dez_out:        movem.l D0-D5/A3,-(SP)
                lea     dez_out_tab(PC),A3
                move.w  D4,D5
                lsl.w   #2,D5
                lea     4(A3,D5.w),A3
                moveq   #'0',D5
dez_out1:       move.l  -(A3),D3
                moveq   #$D0,D2
dez_out2:       sub.l   D3,D0
                dbcs    D2,dez_out2
                neg.b   D2
                move.b  D2,D1
                cmp.b   #'0',D1
                beq.s   dez_out4
                moveq   #'0',D5
dez_out3:       move.b  D1,(A0)+        ;Zahl in den Buffer
                add.l   D3,D0
                dbra    D4,dez_out1
                movem.l (SP)+,D0-D5/A3
                rts
dez_out4:       move.w  D5,D1
                tst.w   D4
                bne.s   dez_out3
                moveq   #'0',D1
                bra.s   dez_out3

dez_out_tab:    DC.L 1,10,100,1000,10000,100000
                DC.L 1000000,10000000,100000000,1000000000

;*******************************************************************************
;* Allgemeines Init                                                            *
;*******************************************************************************
init:           move.w  #2,-(SP)        ;Bildschirmadressen merken
                trap    #14
                addq.l  #2,SP
                move.l  D0,old_physbase(A6)
                move.w  #3,-(SP)
                trap    #14
                addq.l  #2,SP
                move.l  D0,old_logbase(A6)

                movem.l $FFFF8240.w,D0-D7
                movem.l D0-D7,old_pal(A6) ;Farben retten
                moveq   #3,D0
                and.b   $FFFF8260.w,D0
                move.b  D0,rez(A6)      ;die akt.Auflösung
                subq.b  #2,rez(A6)
                move.w  D0,old_rez(A6)  ;und die Auflösung merken
                btst    #1,D0
                bne.s   init4
                pea     farb_pal(A6)
                move.w  #6,-(SP)
                trap    #14             ;Farbpalette setzen
                addq.l  #6,SP
                moveq   #-1,D0
                move.w  #1,-(SP)
                move.l  D0,-(SP)
                move.l  D0,-(SP)
                move.w  #5,-(SP)
                trap    #14             ;geringe Auflösung an
                lea     12(SP),SP
init4:          lea     screens+255(A6),A0
                move.l  A0,D0
                clr.b   D0              ;Bildschirmadresse durch 256 teilbar
                movea.l D0,A0           ;machen
                move.l  A0,physbase(A6) ;1.Seite ist am Anfang "physbase"
                lea     32000(A0),A0
                move.l  A0,logbase(A6)  ;2. Seite ist am Anfang "logbase"

                pea     own_timer(PC)
                move.l  #$050045,-(SP)
                trap    #13             ;eigener 200Hz-Timer
                addq.l  #8,SP
                lea     org_timer(PC),A0
                move.l  D0,2(A0)        ;originalen 200Hz-Timer auch noch nutzen

                move.w  #$22,-(SP)
                trap    #14
                addq.l  #2,SP
                movea.l D0,A0
                lea     24(A0),A0
                move.l  A0,old_joyadr(A6)
                move.l  (A0),old_joyvec(A6)
                lea     own_joyvec(PC),A1
                move.l  A1,(A0)         ;eigene Joystickroutine

                pea     init_joy(PC)
                move.l  #$190001,-(SP)
                trap    #14             ;Joystick an, Maus aus
                addq.l  #8,SP

                linea   #10 [ Hidem ]
                linea   #0 [ Init ]
                movea.l 4(A1),A0        ;Adresse des 8x8-Fonts
                move.l  76(A0),font_adr+4(A6)
                movea.l 8(A1),A0        ;Adresse des 16x16-Fonts
                move.l  76(A0),font_adr(A6)

init1:          bsr     get_key         ;Keyboard-Buffer löschen
                tst.w   key(A6)
                bne.s   init1

                lea     titel_level(A6),A0
                lea     all_level_data-64(A6),A1
                moveq   #15,D0
init3:          move.l  (A0)+,(A1)+     ;Titel-Level kopieren
                dbra    D0,init3

                move.b  $0484.w,old_conterm(A6)
                andi.b  #$F6,$0484.w    ;Tastaturklick aus / Kbshift-Bits aus
                bsr     set_autorep_txt ;Autorepeat-Text setzen

                lea     init2(PC),A5
                bra     do_load_levels  ;Level laden

init2:          rts

;*******************************************************************************
;* Allgemeines Exit                                                            *
;*******************************************************************************
exit:           move.l  #'quit',D0
                bsr     do_dialog
                beq     restart_clr     ;Nicht beenden

                movea.l old_joyadr(A6),A0
                move.l  old_joyvec(A6),(A0) ;Joystick-Vektor zurück

                move.b  old_conterm(A6),$0484.w

                movem.l old_pal(A6),D0-D7 ;Farben zurück
                movem.l D0-D7,$FFFF8240.w
                move.w  old_rez(A6),-(SP) ;Bildschirmadressen zurücksetzen
                move.l  old_physbase(A6),-(SP)
                move.l  old_logbase(A6),-(SP)
                move.w  #5,-(SP)
                trap    #14
                lea     12(SP),SP

                move.l  org_timer+2(PC),-(SP)
                move.l  #$050045,-(SP)
                trap    #13             ;alter 200Hz-Timer
                addq.l  #8,SP

                pea     exit_joy(PC)
                move.l  #$190000,-(SP)
                trap    #14             ;Maus wieder an
                addq.l  #8,SP
                rts

;*******************************************************************************
;* Eigene Joystick-IRQ-Routine                                                 *
;*******************************************************************************
own_joyvec:     move.l  A6,-(SP)
                lea     varbase(PC),A6
                tst.b   demo_mode(A6)   ;Demo aktiv?
                bne.s   own_joyvec1     ;dann nix tun
                cmpi.b  #'J',joy_text(A6)
                bne.s   own_joyvec1     ;Joystick-Steuerung
                move.b  2(A0),dir(A6)
own_joyvec1:    movea.l (SP)+,A6
                rts

;*******************************************************************************
;* Eigene 200Hz-IRQ-Timer-Routine                                              *
;*******************************************************************************
own_timer:      movem.l A0/A6,-(SP)
                lea     varbase(PC),A6
                addq.w  #1,timer2(A6)
                subq.w  #1,timer(A6)    ;200Hz-Zähler
                bpl.s   own_timer_e
                move.w  #199,timer(A6)

                tst.b   timer_stop(A6)
                beq.s   own_timer_e

                bsr     score_down      ;pro Sekunde einen Punkt weniger

                lea     time_sek_txt+1(A6),A0
                addq.b  #1,(A0)
                cmpi.b  #$3A,(A0)
                bne.s   own_timer_e     ;Sekunden hochzählen
                move.b  #'0',(A0)
                subq.l  #1,A0
                addq.b  #1,(A0)
                cmpi.b  #'6',(A0)
                bne.s   own_timer_e
                move.b  #'0',(A0)

                lea     time_min_txt+1(A6),A0
                addq.b  #1,(A0)
                cmpi.b  #$3A,(A0)
                bne.s   own_timer_e     ;Minuten hochzählen
                move.b  #'0',(A0)
                subq.l  #1,A0
                addq.b  #1,(A0)
                cmpi.b  #'6',(A0)
                bne.s   own_timer_e
                move.b  #'0',(A0)

                addq.b  #1,time_std_txt(A6) ;Stunden erhöhen

own_timer_e:    movem.l (SP)+,A0/A6
org_timer:      jmp     $12345678

;*******************************************************************************
;* Hier beginnt nun der DATA-Bereich                                           *
;*******************************************************************************
                DATA
                BASE DC.W,*
                DC.L 'MRF!'
                DC.L 0      ;Offset zum Anfang
                DC.W mono_grafik
                DC.W 8      ;8 mal
                DC.W 32     ;Zeilenanzahl
                DC.W 4      ;je 4 Byte
                DC.W 80     ;Zeilenoffset

                DC.L 32034  ;Offset zum Anfang
                DC.W farb_grafik
                DC.W 8      ;8 mal
                DC.W 16     ;Zeilenanzahl
                DC.W 8      ;je 8 Byte
                DC.W 160    ;Zeilenoffset

                DC.L 32002  ;Offset zum Anfang
                DC.W farb_pal
                DC.W 16     ;1 mal
                DC.W 1      ;eine Zeile
                DC.W 2      ;je ein Wort
                DC.W 0      ;keine 2.Zeile

                DC.W -1

mono_grafik:    DC.W 8*32*4 ;Platz für die Daten
                DS.W 8*32*4-2
farb_grafik:    DC.W 8*16*8
                DS.W 8*16*8-2
farb_pal:       DC.W 16*1*2
                DS.W 16*1*2-2

titel_level:    DC.B $A8,$82,$22,$08,$82,$60,$82,$22,$88,$88,$60,$AA,$22,$28,$A0,$60
                DC.B $82,$22,$08,$88,$60,$B2,$22,$C8,$82,$00,$00,$00,$00,$00,$00,$00
                DC.B $00,$00,$0C,$83,$8A,$A2,$A8,$82,$80,$88,$22,$08,$88,$88,$88,$22
                DC.B $A8,$A0,$A2,$88,$22,$20,$88,$80,$8A,$A2,$08,$82,$14,$96,$00,$00

text:           DC.B 0,24   ;Bildschirmposition
                DC.B 1,2,'Level:'
level_txt:      DC.B '00'
                DC.B '  Moves:'
moves_txt:      DC.B '0000'
                DC.B '  Pushes:'
pushes_txt:     DC.B '0000'
                DC.B '  Time:'
time_std_txt:   DC.B '0'
                DC.B ':'
time_min_txt:   DC.B '00'
                DC.B ':'
time_sek_txt:   DC.B '00'
                DC.B '  Score:'
score_txt:      DC.B '0000'
                DC.B '  Hiscore:'
hiscore_txt:    DC.B '0000'
                DC.B 1,3,0

text2:          DC.B 30,5,1,21,-1
                DC.B 30,6,1,3,'THINK and WORK',1,3,-1
                DC.B 30,7,1,2,'©1989  by ∑-soft',1,2,-1
                DC.B 30,8,1,21,-1
                DC.B 30,9,' F1  - Start level '
level_text:     DC.B '00 ',-1
                DC.B 30,10,' F2  - Edit level',1,4,-1
                DC.B 30,11,' F3  - Level - 1',1,5,-1
                DC.B 30,12,' F4  - Level + 1',1,5,-1
                DC.B 30,13,' F5  - '
joy_text:       DC.B 'Joystick       ',-1
                DC.B 30,14,' F6  - Autorepeat o'
autorep_text:   DC.B 'ff ',-1
                DC.B 30,15,' F7  - Copyrights',1,4,-1
                DC.B 30,16,' F8  - Load levels',1,3,-1
                DC.B 30,17,' F9  - Save levels',1,3,-1
                DC.B 30,18,' F10 - Quit',1,10,-1
                DC.B 30,19,1,21,0

joy1_txt:       DC.B 'Joystick',0
joy2_txt:       DC.B 'Keyboard',0
dialog_txt:     DC.B 28,11,1,23,-1
                DC.B 28,12,' Sure you want to '
dialog_string:  DC.B 'xxxx? ',-1
                DC.B 28,13,1,23,0

copyright_txt:  DC.B 30,6,1,21,-1
                DC.B 30,7,1,3,'THINK and WORK',1,3,-1
                DC.B 30,8,1,2,'©1989  by ∑-soft',1,2,-1
                DC.B 30,9,1,21,-1
                DC.B 30,10,' ATARI ST Version by  ',-1
                DC.B 30,11,1,2,'Markus Fritze',1,5,-1
                DC.B 30,12,' Written with the',1,4,-1
                DC.B 30,13,1,2,'OMIKRON.Assembler  ',-1
                DC.B 30,14,1,21,-1
                DC.B 30,15,' ATARI XL-Version',1,4,-1
                DC.B 30,16,' and Levels by',1,7,-1
                DC.B 30,17,1,2,'Johann Schilcher',1,2,-1
                DC.B 30,18,1,21,0

text3:          DC.B 0,24
                DC.B ' F1-Wall F2-Target F3-Block F4-Exit'
                DC.B 1,2,'Clr/Home-Clr level',1,2,'UNDO-Undo',1,2,'F10:Quit ',0

fname:          DC.B 'LEVEL.DAT',0
init_joy:       DC.B $12,$14
exit_joy:       DC.B $08

;*******************************************************************************
;* Hier beginnt nun der BSS-Bereich                                            *
;*******************************************************************************
varbase:        BSS         ;Die Globale Offset-Variable steht stets in A6
rez:            DS.B 1      ;0=Monochrom, <>0=Farbe
                EVEN
physbase:       DS.L 1      ;angezeigte Bildschirmseite
logbase:        DS.L 1      ;aktuell zu bearbeitende Bildschirmseite
font_adr:       DS.L 2      ;Adressen der Fonts
akt_level:      DS.W 1      ;aktueller Level (0-24)
save_level:     DS.W 1      ;gemerkter Level (da das Demo den Level ändert)
akt_koord_x:    DS.W 1      ;X-Koordinate des Spielers
akt_koord_y:    DS.W 1      ;Y           -"-
level_anz:      DS.W 1      ;Levelanzahl (hier 25)
demo_count:     DS.W 1      ;Position des Demos
demo_level:     DS.W 1      ;akt.Level des Demos
demo_count2:    DS.B 1      ;Anzahl der Schritte in die gespeicherte Richtung
demo_dir:       DS.B 1      ;gespeicherte Richtung
demo_mode:      DS.B 1      ;<>0 => Demo-Mode aktiv
out_of_game:    DS.B 1      ;=0 => Spiel läuft gerade (Blockanzeige ...)
dir:            DS.B 1      ;Joystick-Daten (Bits 0-3)
timer_stop:     DS.B 1      ;=0 => Zeit steht
timer:          DS.W 1      ;200Hz Zähler mit Werten von 0-199
timer2:         DS.W 1      ;200Hz Zähler
key:            DS.W 1      ;akt.Tastencode
moves:          DS.W 1      ;Anzahl der Bewegungen des Spielers
pushes:         DS.W 1      ;Anzahl der Verschiebungen durch den Spieler
akt_score:      DS.W 1      ;Die erreichten Punkte
big_score:      DS.W 1      ;gesamter Score
hiscore:        DS.W 1      ;Hiscore des akt.Levels
old_joyvec:     DS.L 1      ;alter Joystick-Vektor
old_joyadr:     DS.L 1      ;alte Joystick-Vektor-Adresse
old_physbase:   DS.L 1      ;Bildschirmadresse beim Start
old_logbase:    DS.L 1
old_rez:        DS.W 1      ;Bildschirmauflösung beim Start
old_pal:        DS.W 16     ;alte Farbpalette
old_conterm:    DS.B 1      ;gemerkte conterm-Variable
button_pressed: DS.B 1      ;<>0, wenn Feuertaste im Editor gedrückt
level_buffer:   DS.L 16     ;für UNDO im Editor (64 Byte Levelbuffer)
level_dat:      DS.B 22*15  ;Platz für den aktuellen Level
                DS.B 64     ;Level "-1" = Titel
all_level_data: DS.B 64*max_level ;Platz für max.100 Level
                DS.L 256    ;eigener Stack
own_stack:      DS.L 0
screens:        DS.B 32000*2+255 ;die 2 Bildschirmseiten
                END
