
.include "sys/sms_arch.s"
  ;.include "base/ram.s"
;.include "base/macros.s"
  ;.include "res/defines.s"

.rombankmap
  bankstotal 64
  banksize $4000
  banks 64
.endro

.emptyfill $FF

.background "eleg.gg"

.unbackground $40000 $FFFFF

; free unused space
;.unbackground $7F00 $7FEF
; main menu content
.unbackground $412C $415C
; status screen content
.unbackground $4173 $41A9
; menu content
.unbackground $41EC $4219
; sound test
.unbackground $524E $5263
; start button
.unbackground $5265+6 $5265-1+24
; intro
.unbackground $528B+6 $528B-1+21
; attack menu content
.unbackground $7BDE $7BEE
.unbackground $5011 $5031
.unbackground $7C15 $7FEF

/*.define oldPrintBaseX $C077
.define oldPrintBaseY $C078
.define oldPrintAreaW $C079
.define oldPrintAreaH $C07A
.define oldPrintNametableBase $C07B
.define oldPrintSrcPtr $C07D
.define oldPrintOffsetX $C080
.define oldPrintOffsetY $C081
.define oldPrintSpeed $C07F
.define oldPrintNextCharTimer $C082

.define waitIndicatorFgTile $090F

.define waitVblank $1B6
.define loadSizedTilemap $06A4
.define playVoice $5245 */

.include "vwf_consts.inc"
.include "ram.inc"
.include "util.s"
.include "vwf.s"
.include "vwf_user.s"

;.macro orig_read16BitTable
;  rst $20
;.endm

; B = tile count
; DE = srcptr
; HL = dstcmd
.macro rawTilesToVdp_macro
  ; set vdp dst
  ld c,vdpCtrlPort
  out (c),l
  nop
  out (c),h
  nop
  ; write data to data port
  ex de,hl
  dec c
  ld a,b
  -:
    .rept bytesPerTile
      push ix
      pop ix
      outi
    .endr
    dec a
    jp nz,-
.endm

; BC = tile count
; DE = srcptr
; HL = dstcmd
.macro rawTilesToVdp_big_macro
  push bc
    ; set vdp dst
    ld c,vdpCtrlPort
    out (c),l
    nop
    out (c),h
    nop
  pop bc
  ; write data to data port
  ex de,hl
  -:
    push bc
      ld c,vdpDataPort
      .rept bytesPerTile
        push ix
        pop ix
        outi
      .endr
    pop bc
    
    dec bc
    ld a,b
    or c
    jp nz,-
.endm

;===============================================
; Update header after building
;===============================================
.smstag

;========================================
; use vwf and new strings where needed
;========================================

/*.bank $01 slot 1
.org $23D3
.section "set up vwf main game 1" overwrite
  doMakeBankedCall setUpVwf_main
.ends

.bank $01 slot 1
.section "set up vwf main game 2" superfree APPENDTO "vwf and friends"
  setUpVwf_main:
    ; make up work
    call $0432
    
    ld a,vwfTileSize_main
    ld b,vwfScrollZeroFlag_main
    ld c,vwfNametableHighMask_main
    ld hl,vwfTileBase_main
    jp setUpVwfTileAlloc
.ends */

;========================================
; script
;========================================

;.include "out/script/string_bucket_hashtablemain.inc"

.include "out/script/script_data.inc"
.include "out/script/script_table.inc"
.include "out/script/script_overwrite.inc"

.include "out/script/menus_data.inc"
.include "out/script/menus_overwrite.inc"

;========================================
; DEBUG
;========================================

  ;=====
  ; force fast movement
  ;=====

/*  .bank $00 slot 0
  .org $13C6
  .section "force fast movement 1" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $13E0
  .section "force fast movement 2" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $13FE
  .section "force fast movement 3" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $1418
  .section "force fast movement 4" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $1436
  .section "force fast movement 5" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $1450
  .section "force fast movement 6" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $146E
  .section "force fast movement 7" overwrite
    xor a
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $1488
  .section "force fast movement 8" overwrite
    xor a
    nop
    nop
  .ends */

  ;=====
  ; suppress encounters if button 1 held
  ;=====

/*  .bank $01 slot 1
  .org $1484
  .section "debug no encounters 1" overwrite
    jp debugNoEncounterCheck
  .ends

  .bank $01 slot 1
  .section "debug no encounters 2" free
    debugNoEncounterCheck:
      ; get buttons pressed
      ld a,($C350)
      ; check button 1 state
      and $10
      ; ret if button 1 pressed, preventing the encounter
      ret nz
      ; actually, fuck it:
      ; no random encounters UNLESS the button is pressed
;      ret z
      
      ; make up work
      ld a,($C03D)
      jp $5487
      
  .ends */
  
  

;========================================
; extra init
;========================================

.bank $00 slot 0
.org $0088
.section "extra init 1" overwrite
  call doExtraInit
.ends

.bank $01 slot 1
.section "extra init 2" free
  doExtraInit:
    ; make up work
    call $4819
    
    ; initialize vwf settings
    doBankedCall setUpVwf_main
    
    ; initialize expmem tile queue
    ld a,(cartRamCtrl)
    push af
      ld a,vwfTileQueueExpMemAccessByte
      ld (cartRamCtrl),a
      ; initial queue size = 0
;      xor a
;      ld (vwfTileQueueSize),a
      ; zero memory
      xor a
      ld ($8000),a
      ld hl,$8000
      ld de,$8001
      ld bc,$3FFF
      ldir
    pop af
    ld (cartRamCtrl),a
    
    ret
.ends

.slot 2
.section "set up vwf main game 2" superfree APPENDTO "vwf and friends"
  setUpVwf_main:
    ; use nametable printing
    ld a,$FF
    ld (vwfLocalTargetFlag),a
    
    ld a,vwfTileSize_main
    ld b,vwfScrollZeroFlag_main
    ld c,vwfNametableHighMask_main
    ld hl,vwfTileBase_main
    jp setUpVwfTileAlloc
.ends

;========================================
; new script ops
;========================================

.define mainTextScriptLoop $2C87

.bank $00 slot 0
.org $2C8E
.section "new textscript ops 1" overwrite
  jp handleNewTextScriptOps
.ends

.bank $01 slot 1
.section "new textscript ops 2" free
  handleNewTextScriptOps:
    ; make up work
    cp $FF
    jr nz,+
      jp $2CD9
    +:
    
    cp opTextJump
    jr nz,+
      ; destroy old srcaddr
      pop de
      
      call lookUpAndLoadScriptPointer
      
      jp mainTextScriptLoop
    +:
    
    cp opTextShortJump
    jr nz,+
      ; destroy old srcaddr
      pop de
      
      ; HL = jump target ID
      ld l,(hl)
      ld h,$00
      call lookUpAndLoadScriptPointer@endTableLookup
      
      jp mainTextScriptLoop
    +:
    
    cp opTextEndJump
    jr nz,+
      ; destroy old srcaddr
      pop de
      
      call fetchTextJumpTarget
      
;      jp mainTextScriptLoop
      jp $2CD4
    +:
    
    cp opTextWaitEndJump
    jr nz,+
      ; destroy old srcaddr
      pop de
        call fetchTextJumpTarget
      push hl
      
;      jp mainTextScriptLoop
      jp $2CD9
    +:
    
    ; return to original logic
    jp $2C92
  
  fetchTextJumpTarget:
    ; A = target bank
    ld a,(hl)
    inc hl
    push af
      ; HL = target pointer
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
    pop af
    
    ; load target bank
    ld (mapperSlot2Ctrl),a
    ret
  
  lookUpAndLoadScriptPointer:
    ; HL = jump target ID
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    
    @endTableLookup:
    
    ; multiply by 4
    add hl,hl
    add hl,hl
    
    ; add base table offset
    ld de,scriptStringJumpTable
    add hl,de
    
    ; load table bank
    ld a,:scriptStringJumpTable
    ld (mapperSlot2Ctrl),a
    
    ; get target pointer
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    
    ; load target bank
    ld a,(hl)
    ld (mapperSlot2Ctrl),a
    
    ; HL = new srcptr
    ex de,hl
    ret
    
.ends

; the original game WILL change slot 2 when doing a buffer print operation and
; will not restore it afterward.
; somehow this actually fucking works.
; not for us.

.bank $00 slot 0
.org $2DB7
.section "buffer print bank save 1" overwrite
  call doBufferPrintBankSave
.ends

.bank $01 slot 1
.section "buffer print bank save 2" free
  doBufferPrintBankSave:
    ld a,(mapperSlot2Ctrl)
    push af
      call mainTextScriptLoop
    pop af
    ld (mapperSlot2Ctrl),a
    ret
.ends

;========================================
; use jump opcodes for menu strings
;========================================

.bank $01 slot 1
.org $12CF
.section "menu extra init 1" overwrite
  jp doNewMenuInit
.ends

.bank $01 slot 1
.section "menu extra init 2" free
  doNewMenuInit:
    ; save current slot2 bank
    ld a,(mapperSlot2Ctrl)
    push af
    ; save cart ram control
    ld a,(cartRamCtrl)
    push af
    ; disable sram
    xor a
    ld (cartRamCtrl),a
    
    ; make up work
    ld c,(hl)
    inc hl
    ld b,(hl)
    jp $52D2
.ends

.bank $01 slot 1
.org $12D6
.section "menu string extra ops 1" overwrite
  jp doNewMenuOps
.ends

.bank $01 slot 1
.section "menu string extra ops 2" free
  doNewMenuOps:
    ; make up work
    cp $FF
;    ret z
    jr nz,+
      pop af
      ld (cartRamCtrl),a
      ; retrieve original slot2 bank
      pop af
      ld (mapperSlot2Ctrl),a
      ret
    +:
    
/*    cp opTextJump
    jr nz,+
      push de
        call lookUpAndLoadScriptPointer
      pop de
      jr @handled
    +:
    
    cp opTextShortJump
    jr nz,+
      ; HL = jump target ID
      ld l,(hl)
      ld h,$00
      push de
        call lookUpAndLoadScriptPointer@endTableLookup
      pop de
      jr @handled
    +: */
    
    cp opTextEndJump
    jr nz,+
      call fetchTextJumpTarget
      jr @handled
    +:
    
    ; no match
    jp $52D9
    
    @handled:
    jp $52D4
.ends

;========================================
; use jump opcodes for name strings
;========================================

.bank $00 slot 0
.org $3E1A
.section "names extra init 1" overwrite
  jp standardPlainStringPrint
.ends

.bank $01 slot 1
.section "names extra init 2" free
;  doNewNamesInit:
  standardPlainStringPrint:
    ; save current slot2 bank
    ld a,(mapperSlot2Ctrl)
    push af
    ; save cart ram control
    ld a,(cartRamCtrl)
    push af
    ; disable sram
    xor a
    ld (cartRamCtrl),a
    
    @loop:
      ld a,(hl)
      inc hl
      
      call plainStringEndCheck
      jr nc,+
        pop af
        ld (cartRamCtrl),a
        ; retrieve original slot2 bank
        pop af
        ld (mapperSlot2Ctrl),a
        ret
      +:
      
      call plainStringOpCheck
      ; if an op was handled, don't print
      jr c,@loop
      
      ; print literal
      call charToTilemapBuffer
      
      jr @loop
  
  cbcPlainStringPrint:
    ; save current slot2 bank
    ld a,(mapperSlot2Ctrl)
    push af
    ; save cart ram control
    ld a,(cartRamCtrl)
    push af
    ; disable sram
    xor a
    ld (cartRamCtrl),a
    
    @loop:
      ld a,(hl)
      inc hl
      
      call plainStringEndCheck
      jr nc,+
        pop af
        ld (cartRamCtrl),a
        ; retrieve original slot2 bank
        pop af
        ld (mapperSlot2Ctrl),a
        ret
      +:
      
      call plainStringOpCheck
      ; if an op was handled, don't print
      jr c,@loop
      
      ; print literal
      call printCbcChar
      
      jr @loop
   
  plainStringEndCheck:
    cp $FF
    jr z,@isDone
    cp $FE
    jr z,@isDone
    cp opTextEndJump
    jr z,@isDone
    
    scf
    ccf
    ret
    
    @isDone:
    scf
    ret
   
  plainStringOpCheck:
    cp opTextJump
    jr nz,+
      push de
        call lookUpAndLoadScriptPointer
      pop de
      jr @handled
    +:
    
    cp opTextShortJump
    jr nz,+
      ; HL = jump target ID
      ld l,(hl)
      ld h,$00
      push de
        call lookUpAndLoadScriptPointer@endTableLookup
      pop de
      jr @handled
    +:
    
    @notHandled:
    scf
    ccf
    ret
    
    @handled:
    scf
    ret
.ends

/*.bank $00 slot 0
.org $3E1C
.section "names string extra ops 1" overwrite
  jp doNewNamesOps
.ends

.bank $01 slot 1
.section "names string extra ops 2" free
  doNewNamesOps:
    ; make up work
;    cp $FF
;;    ret z
;    jr nz,+
    cp $FF
    jr z,@end
    cp $FE
    jr z,@end
    cp opTextEndJump
    jr nz,+
    @end:
      ; retrieve original slot2 bank
      pop af
      ld (mapperSlot2Ctrl),a
      ret
    +:
    
    cp opTextJump
    jr nz,+
      push de
        call lookUpAndLoadScriptPointer
      pop de
      jr @handled
    +:
    
;    cp opTextEndJump
;    jr nz,+
;      call fetchTextJumpTarget
;      jr @handled
;    +:
    
    ; no match
    jp $3E22
    
    @handled:
    jp $3E1A
.ends */

;========================================
; use jump opcodes for equipment strings
;========================================

.bank $00 slot 0
.org $2E52
.section "new equipment name print 1" overwrite
  call standardPlainStringPrint
  jp $2E5E
.ends

;========================================
; use jump opcodes for character name strings
;========================================

.bank $00 slot 0
.org $2E02
.section "new character name print 1" overwrite
  push hl
    ex de,hl
    call cbcPlainStringPrint
    ex de,hl
  pop hl
  jp $2E0F
.ends

;========================================
; use new text printing
;========================================

.bank $00 slot 0
.org $2EF4
.section "use new text printing 1" overwrite
  jp useNewTextPrinting
.ends

.bank $01 slot 1
.section "use new text printing 2" free
  ; A = char index
  ; BC = y/x coords
  useNewTextPrinting:
    ; special reserved characters that are not used for VWF.
    ; instead, these are left intact in VRAM and sent directly to
    ; the tilemap
    ; blank window background tile
    cp $00
    jr z,@specialCharMatch
    ; right arrow
    cp $71
    jr z,@specialCharMatch
    ; down arrow
    cp $72
    jr z,@specialCharMatch
    ; up arrow
    cp $73
    jr z,@specialCharMatch
    ; empty slot dashes
;    cp $B6
;    jr z,@specialCharMatch
;    cp $B7
;    jr z,@specialCharMatch
    jr +
      @specialCharMatch:
      call yxCoordsToVisibleScreenBuf
      ld (hl),a
;      ld hl,printOffsetX
;      inc (hl)
      jp @done
    +:
    
    ; save target x/y coords for print routine to use
    push af
      ; x
      ld a,c
      ld (printOffsetX),a
      ; y
      ld a,b
      ld (printOffsetY),a
    pop af
    
    push de
      ld c,a
      doBankedCall printVwfChar
    pop de
    
    ; save updated coords
    ld a,(printOffsetX)
;    ld (origPrintX),a
    ld c,a
    ld a,(printOffsetY)
;    ld (origPrintY),a
    ld b,a
    
    @done:
    jp $2F07
    
.ends

;========================================
; no auto x-increment for standard strings
;========================================

/*.bank $00 slot 0
.org $2EEE
.section "no auto x-increment 1" overwrite
  nop
.ends*/

.bank $00 slot 0
.org $2ECD
.section "no auto x-increment 2" overwrite
  push hl
    push af
      call charToTilemapBuffer
      ld a,($C3A8)
      push bc
        or a
        call z,$1665
        call nz,$4B52
      pop bc
    pop af
    
  ;  jp getNewYXPos
    ; make up work
    or a
    jr z,+
      ; frame wait loop?
      push bc
        call $2F09
      pop bc
    +:
    
    ; destroy saved coordinates
  ;  pop bc
    ; replace with updated ones
  ;  ld bc,(origPrintXY)
  
  ; done
  pop hl
  ret
.ends

;========================================
; no auto x-increment for menu strings
;========================================

.bank $01 slot 1
.org $12E0
.section "no auto x-increment menus 1" overwrite
  nop
.ends

;========================================
; no auto x-increment for character names
; in menu lists
;========================================

.bank $00 slot 0
.org $3E25
.section "no auto x-increment character lists 1" overwrite
  nop
.ends

;========================================
; deallocate text tiles when tilemap buffer cleared
;========================================

.bank $00 slot 0
.org $2EBF
.section "tilemap clear text dealloc 1" overwrite
  jp tilemapClearTextDealloc
.ends

.bank $01 slot 1
.section "tilemap clear text dealloc 2" free
  tilemapClearTextDealloc:
    ; free everything
    doBankedCall freeAllVwfTiles
    
    ; reset vwf
    doBankedCall resetVwf
    
    ; make up work
    ld hl,$C930
    jp $2EC2
    
/*  tilemapClearTextDealloc:
;    doBankedCall 
    push bc
    push de
      ; y/x
      ld bc,$0000
      ; h/w
      ld de,$1218
      call deallocTilemapBufferArea
    pop de
    pop bc
    
    ; make up work
    ld hl,$C930
    ret */
  
  ; BC = y/x
  ; DE = h/w
  deallocTilemapBufferArea:
    doBankedJump deallocTilemapBufferArea_ext
.ends

.slot 2
.section "tilemap clear text dealloc 3" superfree
  ; BC = y/x
  ; DE = h/w
  deallocTilemapBufferArea_ext:
    push hl
      ; HL = target buffer position
      call yxCoordsToVisibleScreenBuf
      
      ; BC = h/w
      ld a,d
      ld b,a
      ld a,e
      ld c,a
      @hLoop:
        ld a,c
        push af
        push hl
        @wLoop:
          ld a,(hl)
          call deallocTileIfText
          inc hl
          dec c
          jr nz,@wLoop
        pop hl
        pop af
        
        dec b
        jr z,@done
        
        ; reset width counter
        ld c,a
        ; move to next line
        ld de,screenTilemapBufferW
        add hl,de
        jr @hLoop
      
      @done:
      
    pop hl
    ret
  
  ; A = index
  deallocTileIfText:
    or a
    jr z, +
    cp textTileEnd
    jr nc, +
    ; do not "deallocate" empty window background tiles,
    ; which is special-cased note to use regular printing anyway
    cp emptyBgTile
    jr z,+
    cp windowBgTile
    jr z,+
      
      ; tile is in text range
      
      call unqueueTile
      
      ld e,a
      ld d,$00
      push hl
        ; subtract base position from tile index
        ld hl,(vwfAllocationArrayBaseTile)
        ex de,hl
        or a
        sbc hl,de
        
        ; low byte = index into 0x100-aligned allocation array
        ex de,hl
        ld hl,vwfAllocationArray
        add hl,de
        xor a
        ld (hl),a
      pop hl
    +:
    ret
.ends

;========================================
; deallocate text tiles when window opened
;========================================

.bank $01 slot 1
.org $0021
.section "window open text dealloc 1" overwrite
  jp windowOpenTextDealloc
.ends

.bank $01 slot 1
.section "window open text dealloc 2" free
  ; BC = h/w
  ; DE = y/x
  windowOpenTextDealloc:
    push bc
    push de
      ; swap bc/de
      ld h,b
      ld l,c
      ld b,d
      ld c,e
      ld d,h
      ld e,l
      
      ; deallocate area
      call deallocTilemapBufferArea
    
      ; reset vwf
      doBankedCall resetVwf
    pop de
    pop bc
    
    ; make up work
    ld hl,$C949
    jp $4024
.ends

;========================================
; deallocate text tiles when text scrolls
;========================================

.bank $00 slot 0
.org $2F55
.section "window scroll text dealloc 1" overwrite
  jp windowScrollTextDealloc
.ends

.bank $01 slot 1
.section "window scroll text dealloc 2" free
  windowScrollTextDealloc:
    ; default target = full window
    ; y/x
    ld bc,$0101
    ; h/w
    ld de,$0212
    
    ; if half window, use alternate target
    ld a,(windowHalfSizeFlag)
    or a
    jr z,+
      ; y/x
      ld bc,$0901
      ; h/w
      ld de,$0212
    +:
    
    ; deallocate area
    call deallocTilemapBufferArea
    
    ; make up work
    ld hl,$C991
    jp $2F58
.ends

;========================================
; TODO: deallocate text tiles when screen
; transitions to world map (in all cases)
;========================================

;========================================
; double text speed
;========================================

.bank $00 slot 0
.org $2F09
.section "text speed 1" overwrite
  call useNewTextSpeed
.ends

.bank $01 slot 1
.section "text speed 2" free
  useNewTextSpeed:
    ; make up work
    ld a,(textSpeed)
    sra a
    ret
.ends

;========================================
; modify window sizes
;========================================

; e.g. armor type menu
.bank $01 slot 1
.org $029D
.section "menu sizes 1" overwrite
  ; w/h
  .db $08+1,$0C
.ends

;========================================
; fix dictionary calls
;========================================

.bank $00 slot 0
.org $2E91
.section "fix dictionary 1" overwrite
;  call fixDictCalls
  ; use normal print routine
;  call $2C83
  call $2C87
  jp $2E9C
.ends

/*.bank $01 slot 1
.section "fix dictionary 2" free
  fixDictCalls:
    
.ends*/

;========================================
; fix equipment equip/broken symbol print
;========================================

.bank $00 slot 0
.org $04B4
.section "equipment symbols 1" overwrite
  call useNewEquipmentSymbols
.ends

.bank $01 slot 1
.section "equipment symbols 2" free
  useNewEquipmentSymbols:
    ; preserve y/x position (the symbols need to go in the same column)
    push bc
      call charToTilemapBuffer
    pop bc
    ret
.ends

;========================================
; fix equipment equip symbol on e.g. give menu
;========================================

.bank $00 slot 0
.org $385A
.section "equipment symbols give 1" SIZE $19 overwrite
  @loop:
  push af
    ld a,(de)
    inc de
    or a
    jr z,+
      ; if item is equipped, print "E" symbol
      
      ; base y/x coords
      ld bc,$020A
      ; add y-offset
      dec a
      sla a
      add a,b
      ld b,a
      ; print "E"
      ld a,$84
      call charToTilemapBuffer
    +:
  pop af
  dec a
  jr nz,@loop
  
  ret
.ends

/*.bank $01 slot 1
.section "equipment symbols give 2" free
  useNewEquipmentSymbolsGiveMenu:
    ; preserve y/x position (the symbols need to go in the same column)
    push bc
      call charToTilemapBuffer
    pop bc
    ret
.ends*/

;========================================
; fix number printing
;========================================

.define maxDigitConversionCount 5

.bank $01 slot 1
.org $0A67
.section "number print 1" overwrite
;  jp useNewNumberPrint
  doBankedJump useNewNumberPrint
.ends

.slot 2
.section "number print 2" superfree
  numberOffsetTable:
    ; 5 digits = 23 pixel shift
    .db -25/8,8-(25#8)
    ; 4 digits = 28 pixel shift
    .db -20/8,8-(20#8)
    ; 3 digits = 33 pixel shift
    .db -15/8,8-(15#8)
    ; 2 digits = 38 pixel shift
    .db -10/8,8-(10#8)
    ; 1 digit = 43 pixel shift
    .db -5/8,8-(5#8)
    ; "zero" digits = special
    .db -5/8,8-(5#8)
    ; 6 digits = 18 pixel shift
;    .db -30/8,8-(30#8)

  ; BC = y/x coords
  ; DE = pointer to 6b number conversion buffer (C393)
  ; HL = pointer to nametable buffer target for what was originally
  ;      the position of the rightmost digit in the number
  useNewNumberPrint:
    push bc
      ; bcd conversion
      call $4AF7
      
      ; count number of leading zeroes
      ld b,maxDigitConversionCount
;      push de
      ld de,numConversionBuffer
        ld c,$00
        -:
          ld a,(de)
          or a
          jr nz,+
            inc c
            inc de
            djnz -
      +:
      ld a,c
;      pop de
    pop bc
    
    push de
      ; apply an offset to the target position based on leading zero count
      push af
        push hl
        push bc
          ld hl,numberOffsetTable
          sla a
          ld c,a
          ld b,$00
          or a
          adc hl,bc
          
          ex de,hl
        pop bc
        pop hl
        
        ; apply tile offset
        ld a,(de)
        add a,c
        ld c,a
        
        ; apply fine offset
        inc de
        ld a,(de)
        or a
        jr z,+
          add a,spaceOpsStart
          call charToTilemapBuffer
        +:
      pop af
    pop de
    
    ; if number of leading zeroes is max (5), print "0"
    cp maxDigitConversionCount
    jr nz,+
      ld a,textNumbersStart+0
      call charToTilemapBuffer
      ret
    +:
    
    ; add leading digit count to pointer
/*    ld de,numConversionBuffer
    ld l,a
    ld h,$00
    add hl,de
    ex de,hl*/
    
    ; get pointer to start of non-leading digits
    ; compute count of non-leading digits (5 - leading zero count)
    ld h,a
    ld a,maxDigitConversionCount
    sub h
    ld h,a
    
    ; print digits
    -:
      ld a,(de)
      add a,$76
      push hl
        call charToTilemapBuffer
      pop hl
      
      inc de
      dec h
      jr nz,-
    
    ret
.ends

;========================================
; additional scripts
;========================================

.slot 2
.section "new scripts 1" superfree
  newScriptTable:
    .incbin "out/script/new.bin"
  
  ; A = new script's index
  ; BC = y/x
  runNewTextScript_ext:
    ld hl,newScriptTable
    read16BitTable_macro
    
    push de
      ld de,newScriptTable
      add hl,de
    pop de
    
    call runTextScript
    ret
  
  runNewTextScriptWithISave_ext:
    push ix
    push iy
      call runNewTextScript_ext
    pop iy
    pop ix
    ret
.ends

.bank $01 slot 1
.section "new scripts 2" free
  runNewTextScript:
    doBankedJump runNewTextScript_ext
    
  runNewTextScriptWithISave:
    doBankedJump runNewTextScriptWithISave_ext
  
.ends

;========================================
; move main menu cursor to account for
; updated text position
; (new options are shorter and are
; placed further right so they're
; centered)
;========================================

.bank $01 slot 1
.org $0096
.section "move main menu cursor 1" overwrite
  .db $05+1
.ends

;========================================
; fix dynamic messages that don't work in english
;========================================

  ;======
  ; standard attack message
  ;======

  .bank $01 slot 1
  .org $2C16
  .section "fix attack message 1" overwrite
    ld a,$00
    call runNewTextScriptWithISave
  .ends

  .bank $01 slot 1
  .org $2C1E
  .section "fix attack message 2" overwrite
    ld a,$01
    call runNewTextScriptWithISave
  .ends

/*  .bank $01 slot 1
  .org $2C27
  .section "fix attack message 3" overwrite
    ld a,$02
    call runNewTextScriptWithISave
  .ends*/
  
  
  .bank $01 slot 1
  .org $2C24
  .section "fix attack message 3" overwrite
    call doNewDamageAmountMessage
    jp $6C2C
  .ends
  
  .bank $01 slot 1
  .org $2C24
  .section "fix attack message 4" free
    doNewDamageAmountMessage:
      push de
        call $60D6
      pop de
      push hl
        ld hl,$0001
        or a
        sbc hl,de
      pop hl
      
      ld a,$02
      jr nz,+
        ; if damage amount is exactly 1, use special "point" message
        inc a
      +:
      
      jp runNewTextScriptWithISave
  .ends

  ;======
  ; battle temporary stat increases
  ;======

/*  .bank $01 slot 1
  .org $31B4
  .section "fix battle temp stat increase message 1" overwrite
    ld a,$06
    call runNewTextScriptWithISave
  .ends */

  .bank $01 slot 1
  .org $31BE
  .section "fix battle effect messages 2" overwrite
    call printNewBattleEffectMessages
  .ends

  .bank $01 slot 1
  .section "fix battle effect messages 3" free
    printNewBattleEffectMessages:
/*      ; $77-$7C = temp stat increase messages
      cp $77
      jr c,+
      cp $7D
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$70 & $FF)
        jr @remapped
      +:
      
      ; $A1-$A3 = temp stat change messages
      cp $A1
      jr c,+
      cp $A4
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$94 & $FF)
        jr @remapped
      +: */
      
;      push hl
;      push de
        doBankedCall printNewStatMessagesCommon_ext
;      pop de
;      pop hl
      jr c,@remapped
      
      @notRemapped:
      jp $5ECE
      
      @remapped:
      jp runNewTextScriptWithISave
  .ends

  ;======
  ; out-of-battle permanent stat increases
  ;======

  .bank $00 slot 0
  .org $12D3
  .section "fix out-of-battle stat up messages 1" overwrite
    jp printNewOutOfBattleStatMessages
  .ends

  .bank $01 slot 1
  .section "fix out-of-battle stat up messages 2" free
    printNewOutOfBattleStatMessages:
      push af
        call $60D6
      pop af
      
      ; $77-$7C = temp stat increase messages
/*      cp $77
      jr c,+
      cp $7D
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$70 & $FF)
        jr @remapped
      +:
      
      ; $A1-$A3 = temp stat change messages
      cp $A1
      jr c,+
      cp $A4
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$94 & $FF)
        jr @remapped
      +: */
      
;      push hl
;      push de
        doBankedCall printNewStatMessagesCommon_ext
;      pop de
;      pop hl
      jr c,@remapped
      
      @notRemapped:
      jp $2FE5
      
      @remapped:
      jp runNewTextScriptWithISave
  .ends

  .bank $01 slot 1
  .section "fix out-of-battle stat up messages 3" free
    printNewStatMessagesCommon_ext:
;      push af
;        call $60D6
;      pop af
      
      ; $77-$7C = temp stat increase messages
      cp $77
      jr c,+
      cp $7D
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$70 & $FF)
        jr @remapped
      +:
      
      ; $A1-$A3 = temp stat change messages
      cp $A1
      jr c,+
      cp $A4
      jr nc,+
        ; add difference between old message's script ID
        ; and new one's ID to get new target
        add a,(-$94 & $FF)
        jr @remapped
      +:
      
      @notRemapped:
      scf
      ccf
      ret
      
      @remapped:
      scf
      ret
  .ends

  ;======
  ; s-item use from menu?
  ;======

  .bank $00 slot 0
  .org $0ED7
  .section "s-item use 1" overwrite
    jp nc,doNewSItemUseMessage
  .ends

  ; using an s-item with a target: handled specially below
;  .bank $00 slot 0
;  .org $0EFD
;  .section "s-item use 2" overwrite
;    call doNewSItemUseMessage
;  .ends

  .bank $01 slot 1
  .section "s-item use 3" free
    doNewSItemUseMessage:
      ; make up work
      ld a,($C349)
      call $302F
      
      ld a,$10
      jp runNewTextScriptWithISave
  .ends

  ;======
  ; using e.g. healing magic from menu
  ;======

  .bank $00 slot 0
  .org $0F02
  .section "party item/spell use menu 1" overwrite
    ; ID of new verb message for item use.
    ; spell use message should have the next ID.
    ld c,$11
  .ends

  .bank $00 slot 0
  .org $0F3C
  .section "party item/spell use menu 2" SIZE $10 overwrite
    push af
      ; subject
      ld a,($C348)
      call $3001
      
      ; generate target item/spell name in buffer
      ld a,($C349)
      call $302F
      
      jp doNewMenuItemSpellUse
      ; do new message
  .ends

  .bank $01 slot 1
  .section "party item/spell use menu 3" free
    doNewMenuItemSpellUse:
      ; A = target script index num
      pop af
      call runNewTextScriptWithISave
      
      ; indirect object clause
      ld a,($C34B)
      jp $3008
  .ends

  ;======
  ; something...
  ;======

  .bank $00 slot 0
  .org $0EF7
  .section "something use menu 1" overwrite
    call doNewSomethingUseMessage
    ; indirect object
    ld a,($C34B)
    call $3008
  .ends

  .bank $01 slot 1
  .section "something use menu 2" free
    doNewSomethingUseMessage:
      ; load buffer
      ld a,($C349)
      call $302F
      ; print "Used [x] on"
      ld a,$13
      jp runNewTextScriptWithISave
  .ends

  ;======
  ; intra-party item transfer
  ;======

  .bank $00 slot 0
  .org $0A19
  .section "party item transfer 1" overwrite
    ; load buffer with item name
    ld a,($C349)
    call $302F
    ; print target message
    ld a,$0C
    call $2FE5
    
    jp newPartyItemTransferMessage
  .ends

  .bank $01 slot 1
  .section "party item transfer 2" free
    newPartyItemTransferMessage:
      ; indirect object
      ld a,($C34B)
      call $3008
      ; finish normal logic
      jp $80F
  .ends

  ;======
  ; add commas to lists of enemies at battle start
  ;======

  .bank $01 slot 1
  .org $1EAD
  .section "enemy lists 1" overwrite
    call doNewEnemyListMessage
  .ends

  .bank $01 slot 1
  .section "enemy lists 2" free
    doNewEnemyListMessage:
      cp $03
      jr c,+
        ld a,(hl)
        ld ($C3B0),a
        
        ; if not first or second enemy
        ld a,$14
        push hl
          call runNewTextScriptWithISave
        pop hl
        ret
      +:
      
      jp $5EB6
  .ends

;========================================
; new intro
;========================================

  ;========================================
  ; data
  ;========================================

/*  .slot 2
  .section "intro scroll data 1" superfree
    introScrollGrp:
      .incbin "out/script/introscroll_grp.bin" FSIZE introScrollGrpSize
    .define introScrollGrpNumTiles introScrollGrpSize/bytesPerTile
    
    loadIntroScrollGrp:
      ld b,introScrollGrpNumTiles
      ld de,introScrollGrp
      ld hl,$4000|$0000
      di
        rawTilesToVdp_macro_safe
      ei
      ret
  .ends

  .slot 2
  .section "intro scroll data 2" superfree
    introScrollTilemaps:
      .incbin "out/script/introscroll_tilemaps.bin"
  .ends

  .slot 2
  .section "end scroll data 1" superfree
    endScrollGrp:
      .incbin "out/script/endscroll_grp.bin" FSIZE endScrollGrpSize
    .define endScrollGrpNumTiles endScrollGrpSize/bytesPerTile
    
    loadEndScrollGrp:
      ld b,endScrollGrpNumTiles
      ld de,endScrollGrp
      ld hl,$4000|$0000
      rawTilesToVdp_macro_safe
      ret
  .ends

  .slot 2
  .section "end scroll data 2" superfree
    endScrollTilemaps:
      .incbin "out/script/endscroll_tilemaps.bin"
  .ends*/
  
  .include "out/script/introscroll_data.inc"
  .include "out/script/introscroll_table.inc"
  .include "out/script/endscroll_data.inc"
  .include "out/script/endscroll_table.inc"

  ;========================================
  ; code
  ;========================================
  
  .define tilesPerTextScrollLine 20
  .define textScrollLeftOffset 0
  .define textScrollTargetRow 18
  .define textScrollBaseDstTile $01
  .define textScrollVisibleLines 10
  ; if dst tile is greater than this after sending tile data,
  ; reset to base tile
  .define textScrollLimitDstTile textScrollBaseDstTile+(textScrollVisibleLines*tilesPerTextScrollLine)

  .bank $01 slot 1
  .org $0FFD
  .section "intro scroll code 1" overwrite
    call newIntroScrollInit
    nop
    nop
    nop
  .ends

  .bank $01 slot 1
  .section "intro scroll code 2" free
    newIntroScrollInit:
;      doBankedCall loadIntroScrollGrp
      
      ; table pointer
      ld hl,introScrollContentTable
      ld (textScrollTablePointer),hl
      
      ; load bank for table data
      ld a,:introScrollContentTable
      ld (mapperSlot2Ctrl),a
      
      @common:
      
      ; base dst tile
      ld a,textScrollBaseDstTile
      ld (textScrollDstTile),a
      
      ret
    
    newEndScrollInit:
      ; table pointer
      ld hl,endScrollContentTable
      ld (textScrollTablePointer),hl
      
      ; load bank for table data
      ld a,:endScrollContentTable
      ld (mapperSlot2Ctrl),a
      
      jr newIntroScrollInit@common
  .ends

  .bank $01 slot 1
  .section "intro scroll code 3" free
    ; B = tile count
    ; DE = srcptr
    ; HL = dstcmd
/*    loadTilesUnsafe:
;      rawTilesToVdp_macro
      ; set vdp dst
      ld c,vdpCtrlPort
      out (c),l
      nop
      out (c),h
      nop
      ; write data to data port
      ex de,hl
      dec c
      ld a,b
      -:
        ld b,bytesPerTile
        --:
          outi
          djnz --
        dec a
        jp nz,-
      ret*/
    
    prepNextTextScrollLine:
      doBankedCall prepNextTextScrollLine_ext2
      
      ;=====
      ; load tile data
      ;=====
      
      ld a,(mapperSlot2Ctrl)
      push af
      
        ; src bank for next data
        ld a,(hl)
        inc hl
        ; src pointer for next data
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
      
        push hl
          ld (mapperSlot2Ctrl),a
          
          ; convert dst tile to vdp command
          ld a,(textScrollDstTile)
          ld l,a
          ld h,$02
          ; multiply by 32
          add hl,hl
          add hl,hl
          add hl,hl
          add hl,hl
          add hl,hl
          ; OR high byte with 04 to get write command
          ; (now precomputed)
;          ld a,h
;          or $40
;          ld h,a
          
          ; load tile data
          ld b,tilesPerTextScrollLine
          call loadTilesSafe
      
          doBankedCall prepNextTextScrollLine_ext
        pop hl
      pop af
      ld (mapperSlot2Ctrl),a
      
      ret
  .ends

  .slot 2
  .section "intro scroll code 3a" superfree
    prepNextTextScrollLine_ext:
      ;=====
      ; generate tilemap data
      ;=====
      
      ld a,(textScrollDstTile)
      ld hl,screenTilemapBufferVisible+(screenTilemapBufferW*textScrollTargetRow)+textScrollLeftOffset
      ld b,tilesPerTextScrollLine
      -:
        ld (hl),a
        inc a
        inc hl
        djnz -
  
      ;=====
      ; wrap dst tile as needed
      ;=====
      
;      ld a,(textScrollDstTile)
      cp textScrollLimitDstTile+1
      jr c,+
        ld a,textScrollBaseDstTile
      +:
      ld (textScrollDstTile),a
      
      ret
    
    prepNextTextScrollLine_ext2:
      push hl
        ; do standard cleanup
        ; shift old content up
        ld hl,$C960
        ld de,$C930
        ld bc,$01B0
        ldir 
        ; clear out bottom lines
        xor a
        ld b,$30
        -:
          ld (de),a
          inc de
          djnz -
      pop hl
      
      ret
  .ends
    
  .bank $01 slot 1
  .section "intro scroll code 4" free
    ; B = tile count
    ; DE = srcptr
    ; HL = dstcmd
    loadTilesSafe:
      di
  ;      rawTilesToVdp_macro_safe
        ; set vdp dst
        ld c,vdpCtrlPort
        out (c),l
        nop
        out (c),h
        nop
        ; write data to data port
        ex de,hl
        dec c
        ld a,b
        -:
          ld e,bytesPerTile
          --:
            push ix
            pop ix
            outi
            dec e
            jr nz,--
          dec a
          jr nz,-
      ei
      ret
  .ends

  .bank $01 slot 1
  .org $1003
  .section "intro scroll code 5" overwrite
    call prepNextTextScrollLine
  .ends

  .bank $01 slot 1
  .org $0F61
  .section "end scroll code 1" overwrite
    call newEndScrollInit
    nop
    nop
    nop
  .ends

  .bank $01 slot 1
  .org $0F67
  .section "end scroll code 2" overwrite
    call prepNextTextScrollLine
  .ends

;========================================
; fix startup sequence
;========================================

  ;========================================
  ; credits 1
  ;========================================

/*  .bank $01 slot 1
  .org $115D
  .section "intro vwf setup 1" overwrite
    call setUpIntroVwf1
  .ends

  .bank $01 slot 1
  .section "intro vwf setup 2" free
    setUpIntroVwf1:
      push hl
        call localVwfReset
      pop hl
      
      ; start allocating from a tile that won't conflict with the extra
      ; graphics for the JAM logo
      ld a,$20
      ld (vwfAllocationArrayPos),a
      ; make up work
      jp $52CF
  .ends

  .bank $01 slot 1
  .section "intro vwf setup 3" free
    localVwfReset:
      doBankedJump fullyResetVwf_user
  .ends */
  
  .bank $01 slot 1
  .org $0EED
  .section "title vwf setup 1" overwrite
    call setUpTitleVwf1
  .ends

  .bank $01 slot 1
  .section "title vwf setup 2" free
    setUpTitleVwf1:
      push hl
        call localVwfReset
      pop hl
      
      ; start allocating from a tile that won't conflict with the extra
      ; graphics for the title screen
      ld a,$80
      ld (vwfAllocationArrayPos),a
      
      ; make up work
      jp $52CF
  .ends

  .bank $01 slot 1
  .section "title vwf setup 3" free
    localVwfReset:
      doBankedJump fullyResetVwf_user
  .ends

;========================================
; render text to queue-based tile buffer
; in expansion memory and only transfer
; when tilemap refreshed.
; this mostly suppresses rendering
; artifacts caused by drawing new text
; to tiles that have not yet been
; removed from the visible screen.
;========================================

  ;=====
  ; check queue state when sending tilemaps to screen
  ;=====

  .bank $00 slot 0
  .org $1665
  .section "tilemap send tile queue check 1" overwrite
    call checkTilemapQueue1
  .ends

  .bank $01 slot 1
  .section "tilemap send tile queue check 2" free
    checkTilemapQueue1:
      call sendTileQueueIfPending
      
      ; make up work
      ld a,($C3A8)
      ret
  .ends

  .bank $01 slot 1
  .org $0B52
  .section "tilemap send tile queue check 3" overwrite
    call checkTilemapQueue2
  .ends

  .bank $01 slot 1
  .section "tilemap send tile queue check 4" free
    checkTilemapQueue2:
      call sendTileQueueIfPending
      
      ; make up work
      ld hl,$CA08
      ret
  .ends
    
  .bank $01 slot 1
  .section "tilemap send tile queue check 5" free
    sendTileQueueIfPending:
      ld a,(cartRamCtrl)
      push af
      ld a,vwfTileQueueExpMemAccessByte
      ld (cartRamCtrl),a
        ld a,(vwfTileQueueSize)
        or a
        jr z,@done
          ; copy tile allocation buffer state.
          ; we can then check against this to preferentially allocate
          ; tiles that are not already being used for display
          ; when we compose the next buffer.
          push af
            ld bc,maxVwfTiles
            ld de,vwfVisibleAllocationArray
            ld hl,vwfAllocationArray
            ldir
          pop af
          
          ; get index number
          ld b,a
          ld de,vwfTileQueueData
          -:
            ld a,(de)
            push de
              ld l,a
              ld h,>vwfTileUsedData
              
              ; if marked as unqueued (i.e. because the tile was drawn,
              ; but then overwritten and deallocated), skip sending it
              ld a,(hl)
              or a
              jr z,@loopEnd
              
              ; mark this index as unqueued
              ld (hl),$00
              
              ; fetch tile index again
              ld a,(de)
              ld l,a
              ld h,$00
              ; multiply by 32 bytes = bytesPerTile
              add hl,hl
              add hl,hl
              add hl,hl
              add hl,hl
              add hl,hl
;              add hl,hl
              
              ; add base address
              ld de,vwfTileQueueEntries
              add hl,de
              
              ; check "queued" status byte
;              ld a,(hl)
;              inc hl
;              or a
              ; skip if zero (i.e. this tile was queued but then
              ; canceled)
;              jr z,@loopEnd
                push bc
                  ; de = srcpos
                  ld e,l
                  ld d,h
                  ; bc = base offset of tile data
                  ld bc,(-vwfTileQueueEntries)&$FFFF
                  add hl,bc
                  ; turn HL into vdp dstcmd
                  ld a,h
                  or $40
                  ld h,a
                  
                  ld b,1
                  call loadTilesSafe
                pop bc
            @loopEnd:
            pop de
            inc de
            djnz -
        ; reset queue size
        xor a
        ld (vwfTileQueueSize),a
        @done:
      pop af
      ld (cartRamCtrl),a
      ret
  .ends
    
  .bank $01 slot 1
  .section "tilemap send tile queue check 6" free
    ; A = tile index
    queueTile:
      ld (scratchLo),a
      
      ld a,(cartRamCtrl)
      push af
      ld a,vwfTileQueueExpMemAccessByte
      ld (cartRamCtrl),a
        ; check if already queued
        ld a,(scratchLo)
        ld h,>vwfTileUsedData
        ld l,a
        ld a,(hl)
        or a
        ld a,(scratchLo)
        jr nz,+
          ; if not yet in queue
          
          ; mark as queued
          ld (hl),$FF
          
          ld hl,vwfTileQueueSize
          
          ; queue is 0x100-aligned, so we can skip doing an addition
          ld a,(hl)
          ld d,>vwfTileQueueData
          ld e,a
          ; increment queue size
          inc (hl)
          
          ; add target tile marker to queue
          ld a,(scratchLo)
          ld (de),a
        +:
        
        ; hl = pointer to target tile data
        ld l,a
        ld h,$00
        ; multiply by 32
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ; add base position
        ld bc,vwfTileQueueEntries
        add hl,bc
        ex de,hl
        
        ; add tile data to queue
        ld bc,bytesPerTile
        ld hl,vwfBuffer
        ldir
        
        @done:
      pop af
      ld (cartRamCtrl),a
      ret
  .ends
    
  .bank $01 slot 1
  .section "tilemap send tile queue check 7" free
    ; A = index
    unqueueTile:
      push af
      push hl
        ld (scratchLo),a
        
        ld a,(cartRamCtrl)
        push af
        ld a,vwfTileQueueExpMemAccessByte
        ld (cartRamCtrl),a
          ld a,(scratchLo)
          
          ld l,a
          ld h,>vwfTileUsedData
          
          xor a
          ld (hl),a
          
          @done:
        pop af
        ld (cartRamCtrl),a
      pop hl
      pop af
      ret
  .ends
    
  .bank $01 slot 1
  .section "tilemap send tile queue check 8" free
    ; DE = target check index
    fetchVisibleAllocationArrayEntry:
      ld a,(cartRamCtrl)
      push af
      ld a,vwfTileQueueExpMemAccessByte
      ld (cartRamCtrl),a
        ld hl,vwfVisibleAllocationArray
        add hl,de
        ld a,(hl)
        ld (scratchLo),a
      pop af
      ld (cartRamCtrl),a
      
      ld a,(scratchLo)
      ret
  .ends

;========================================
; move character status string
; (good, dying, etc.)
; to the left so more text will fit
;========================================

; out of battle

.bank $00 slot 0
.org $056E
.section "move character status string 1" overwrite
  ; y/x pos
;  ld bc,$0E0F
  ld bc,$0E0E
.ends

; in battle

.bank $01 slot 1
.org $2496
.section "move character status string 2" overwrite
  ; y/x pos
;  ld bc,$100F
  ld bc,$100E
.ends

;========================================
; add "run" feature -- hold button 1
; to move faster than normal.
; i'm doing this mostly so our testers
; won't hate me quite as much for
; subjecting them to this game.
;========================================
  
.bank $00 slot 0
.org $13E5
.section "fast movement setting left" overwrite
  call checkWalkSpeedSetting
.ends

.bank $00 slot 0
.org $141D
.section "fast movement setting up" overwrite
  call checkWalkSpeedSetting
.ends

.bank $00 slot 0
.org $1455
.section "fast movement setting right" overwrite
  call checkWalkSpeedSetting
.ends

.bank $00 slot 0
.org $148D
.section "fast movement setting down" overwrite
  call checkWalkSpeedSetting
.ends

.bank $01 slot 1
.section "fast movement setting check" free
  checkWalkSpeedSetting:
/*      ld (scratchLo),a
      ld a,(walkSpeedSetting)
      or a
      ret nz
    ld a,(scratchLo)
    
    jp $002C */
    
    ld (scratchLo),a
      ; get buttons pressed
      ld a,($C350)
      ; check button 1 state
      and $10
      ; ret if button 1 pressed,
      ; skipping the normal frame wait period
      ret nz
    ld a,(scratchLo)
    
    jp $002C
.ends

;========================================
; add user-toggleable ability to fully
; disable random encounters.
; also done for the sake of my relationship
; with the testers.
;========================================
  
  ;=====
  ; check flag when attempting
  ; to trigger an encounter
  ;=====

  .bank $01 slot 1
  .org $1484
  .section "debug no encounters 1" overwrite
    jp debugNoEncounterCheck
  .ends

  .bank $01 slot 1
  .section "debug no encounters 2" free
    debugNoEncounterCheck:
      ld a,(forceEncountersOffFlag)
      or a
      ; ret here prevents encounters
      ret nz
      
      ; make up work
      ld a,($C03D)
      jp $5487
      
  .ends
  
  ;=====
  ; definitions for new system menu with
  ; option for enabling/disabling encounters
  ;=====

  .bank $01 slot 1
  .org $00BB
  .section "debug no encounters 3" overwrite
    encountersOnSystemMenuSetupStruct:
      ; x?
      .db $03
      ; y?
      .db $00
      ; ?
      .db $14
      ; pointer to X/Y+text data for menu
      .dw $41E6
      ; cursor base x/y
      .db $05-1,$06
      ; number of selectable options
      .db $04+1
  .ends

  .bank $01 slot 1
  .section "debug no encounters 4" free
    encountersOffSystemMenuSetupStruct:
      ; x?
      .db $03
      ; y?
      .db $00
      ; ?
      .db $14
      ; pointer to X/Y+text data for menu
      .dw $4221
      ; cursor base x/y
      .db $05-1,$06
      ; ?
      .db $04+1
  .ends
  
  ;=====
  ; new system menu logic
  ;=====

  .bank $00 slot 0
  .org $0A3D
  .section "use no encounter menu 1" overwrite
    call startNewSystemMenu
  .ends

  .bank $01 slot 1
  .section "use no encounter menu 2" free
    startNewSystemMenu:
      ld a,(forceEncountersOffFlag)
      or a
      jr z,+
        ; use alt structure
        ld ix,encountersOffSystemMenuSetupStruct
      +:
      jp $52E8
      
  .ends

  .bank $00 slot 0
  .org $0A4D
  .section "use no encounter menu 3" overwrite
    jp checkNewSystemMenuOption
  .ends

  .bank $01 slot 1
  .section "use no encounter menu 4" free
    checkNewSystemMenuOption:
      dec a
      jp z,$0B2C
      
      ld a,(forceEncountersOffFlag)
      xor $FF
      ld (forceEncountersOffFlag),a
      ; loop menu
      jp $0A32
  .ends

;========================================
; allow holding button 1 to speed up
; text in addition to button 2
;========================================

.bank $00 slot 0
.org $2F15
.section "text speedup with button 1 1" overwrite
  ;and $20
  and $30
.ends

