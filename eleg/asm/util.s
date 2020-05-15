
;===============================================
; macros
;===============================================

.macro callExternal
  ld a,(mapperSlot2Ctrl)
  push af
  
    ld a,:\1
    ld (mapperSlot2Ctrl),a
    call \1
  
  pop af
  ld (mapperSlot2Ctrl),a
.endm

.macro callExternalHardcoded
  ld a,(mapperSlot2Ctrl)
  push af
  
    ld a,\1
    ld (mapperSlot2Ctrl),a
    call \2
  
  pop af
  ld (mapperSlot2Ctrl),a
.endm

; 14 bytes total
.macro doBankedCall
  ld (bankedCallA),a
  ld (bankedCallHL),hl
  ld a,:\1
  ld hl,\1
  call bankedCall
.endm

; 8 bytes total
.macro doBankedCallNoParams
  ld a,:\1
  ld hl,\1
  call bankedCall
.endm

; 14 bytes total
.macro doBankedJump
  ld (bankedCallA),a
  ld (bankedCallHL),hl
  ld a,:\1
  ld hl,\1
  jp bankedCall
.endm

; TODO: reimplement
;.macro read8BitTable
;  rst $20
;.endm

.macro read16BitTable_macro
;  rst $28
  push de
    ld e,a
    ld d,$00
    add hl,de
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
  pop de
.endm

.macro startLocalPrint ARGS baseAddr, nametableW, nametableH, x, y
  ld hl,baseAddr
  ld (vwfLocalTargetBaseAddr),hl
  
  ld hl,baseAddr+(nametableW*2*y)+(2*x)
  ld (vwfLocalTargetCurrLineAddr),hl
  
  ld a,nametableW
  ld (vwfLocalTargetW),a
  
  ld a,nametableH
  ld (vwfLocalTargetH),a
  
  ld a,$FF
  ld (vwfLocalTargetFlag),a
.endm

.macro startLocalPrintNonFixed ARGS nametableW, nametableH, x, y
  ld (vwfLocalTargetBaseAddr),hl
  
  ld de,(nametableW*2*y)+(2*x)
  add hl,de
  ld (vwfLocalTargetCurrLineAddr),hl
  
  ld a,nametableW
  ld (vwfLocalTargetW),a
  
  ld a,nametableH
  ld (vwfLocalTargetH),a
  
  ld a,$FF
  ld (vwfLocalTargetFlag),a
.endm

.macro moveLocalPrint ARGS baseAddr, nametableW, nametableH, x, y
  ld hl,baseAddr+(nametableW*2*y)+(2*x)
  ld (vwfLocalTargetCurrLineAddr),hl
.endm

.macro endLocalPrint
  xor a
  ld (vwfLocalTargetFlag),a
.endm

; set up a value for inline script printing
; HL = value
.macro setUpNumberPrint ARGS digits, showLeadingZeroes
;  ld hl,value
;  ld hl,(valueAddr)
  ld (inlinePrintNum),hl
  
  ld a,digits
  ld (inlinePrintDigitCount),a
  
  ld a,showLeadingZeroes
  ld (inlinePrintShowLeadingZeroes),a
.endm

.macro openTempBank
  ld a,(mapperSlot2Ctrl)
  push af
    ld a,\1
    ld (mapperSlot2Ctrl),a
.endm

.macro closeTempBank
  pop af
  ld (mapperSlot2Ctrl),a
.endm

; B = tile count
; DE = srcptr
; HL = dstcmd
/*.macro rawTilesToVdp_macro
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
      outi
    .endr
    dec a
    jp nz,-
.endm*/

; B = tile count
; DE = srcptr
; HL = dstcmd
.macro rawTilesToVdp_macro_safe
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

;===============================================
; code
;===============================================

.bank 1 slot 1
.section "bankedCall" free
  ; makes a call to a slot 2 bank
  ;
  ; A = banknum
  ; HL = call target
  bankedCall:
    ; save banknum
    ld (scratchLo),a
    
    ; save old ram control register
    ld a,(cartRamCtrl)
    push af
    ; save old banknum
    ld a,(mapperSlot2Ctrl)
    push af
      ; disable cart ram if active
      xor a
      ld (cartRamCtrl),a
      ; switch to new bank
      ld a,(scratchLo)
      ld (mapperSlot2Ctrl),a
      
      ; save target routine address
      ld (scratch),hl
      
      ; push our return address
      ld hl,@retAddr
      push hl
      
      ; jump to target routine
      
      ; push target to stack so we can ret into it
      ld hl,(scratch)
      push hl
      ; load parameters
      ld a,(bankedCallA)
      ld hl,(bankedCallHL)
      ; ret into target
      ret
      
      @retAddr:
      
      ; preserve value returned in A
      ld (scratchLo),a
      
      ; preserve carry flag
      jr c,+
        xor a
        jr ++
      +:
        ld a,$FF
      ++:
      ld (scratchHi),a
    ; restore old bank
    pop af
    ld (mapperSlot2Ctrl),a
    ; restore old ram control register
    pop af
    ld (cartRamCtrl),a
    
    ; return carry flag
    ld a,(scratchHi)
    or a
    scf
    jr nz,+
      ccf
    +:
    
    ; return value in A
    ld a,(scratchLo)
    ret
.ends

/*.bank 1 slot 1
.section "getPointerBank" free
  ;========================================
  ; returns in A the bank a given pointer
  ; corresponds to (for the currently
  ; loaded slot configuration).
  ; may also return special codes:
  ; * ramBankIdentifier (FE) if pointer
  ;   is in RAM
  ;
  ; HL = pointer
  ;
  ; returns:
  ;   C = bank or return code
  ;========================================
  getPointerBank:
    ;=====
    ; determine which bank we're targeting
    ; based on srcptr in HL
    ;=====
    ld a,h
    
    ; C000-FFFF = RAM
    cp $C0
    jr nc,@targetRam
    
    ; 8000-BFFF = slot 2
    ; FIXME: if expansion RAM is in use, you're on your own!
    cp $80
    jr nc,@targetSlot2
    
    ; 4000-7FFF = slot 1
    cp $40
    jr nc,@targetSlot1
    
      @targetSlot0:
        ld a,(mapperSlot0Ctrl)
        jr @done
      
      @targetSlot1:
        ld a,(mapperSlot1Ctrl)
        jr @done
      
      @targetSlot2:
        ld a,(mapperSlot2Ctrl)
        jr @done
    
      @targetRam:
        ld a,ramBankIdentifier
    
    @done:
    ld c,a
    ret
.ends

.bank 1 slot 1
.section "bankedFetch" free
  ;========================================
  ; returns in A the byte at (B:HL)
  ;
  ; B = bank
  ; HL = slot 2 pointer
  ;
  ; returns:
  ;   A = read byte
  ;========================================
  bankedFetch:
    push bc
      ld a,(mapperSlot2Ctrl)
      push af
        ld a,b
        ld (mapperSlot2Ctrl),a
        ld a,(hl)
        ld b,a
      pop af
      ld (mapperSlot2Ctrl),a
      ld a,b
    pop bc
    ret
.ends */

/*.bank 1 slot 1
.section "doHashBucketLookup" free
  ;========================================
  ; looks up a hash bucket's pointer info
  ;
  ; B  = table bank
  ; HL = table ptr
  ;
  ; returns:
  ;   B  = bucket bank
  ;   HL = bucket pointer
  ;========================================
  doHashBucketLookup:
    ld a,(mapperSlot2Ctrl)
    push af
    
      ld a,b
      ld (mapperSlot2Ctrl),a
      
      ; bank
      ld a,(hl)
      ld b,a
      inc hl
      
      ; pointer
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      
    pop af
    ld (mapperSlot2Ctrl),a
    ret
.ends

.bank 1 slot 1
.section "getPointerInfoFromBucketArray" free
  ;========================================
  ; B =  bucket bank
  ; C =  orig bank
  ; HL = bucket pointer
  ; DE = orig srcptr
  ;
  ; return:
  ; C  = new bank
  ; HL = new ptr
  ;========================================
  getPointerInfoFromBucketArray:
    ld a,(mapperSlot2Ctrl)
    push af
    
      push ix
        
        ; IX = bucker pointer
        push hl
        pop ix
    
        ld a,b
        ld (mapperSlot2Ctrl),a
        
        @bucketCheckLoop:
          ; check if array end reached (string not found)
          ld a,(ix+0)
          cp noBankIdentifier
          jr z,@failure
          
            ; check if src banknum matches
            cp c
            jr nz,@notFound
            
            ; check if low byte of srcptr matches
            ld a,(ix+1)
            cp e
            jr nz,@notFound
            
            ; check if high byte of srcptr matches
            ld a,(ix+2)
            cp d
            jr nz,@notFound
            
            ;=====
            ; match found!
            ;=====
            
            @found:
            ; new bank
            ld c,(ix+3)
            ; new srcptr
            ld l,(ix+4)
            ld h,(ix+5)
            jr @done
          
          @notFound:
          push de
            ld de,$0006
            add ix,de
          pop de
          jr @bucketCheckLoop
        
        @failure:
        ; A should be $FF at this point
        ld c,a
      
      @done:
      pop ix
    
    pop af
    ld (mapperSlot2Ctrl),a
    ret
.ends

.slot 2
.section "lookUpHashedPointer" superfree
  ;===============================================
  ; hash map lookup for translated strings
  ;
  ; parameters:
  ;   B  = banknum of hashmap
  ;   C  = banknum of orig string
  ;   HL = raw pointer to orig string (in
  ;        appropriate slot)
  ; 
  ; hash maps are assumed to have a 0x4000-byte
  ; key->bucketptr table
  ; 
  ; returns:
  ;   C  = banknum of mapped string (FF if not
  ;        in map)
  ;   HL = slot1 pointer to mapped string
  ;===============================================
  lookUpHashedPointer:
    ; save raw srcptr
    push hl
    
      ; convert raw pointer to hash key (AND with $0FFF)
      ld a,h
      and $0F
      ld h,a
      
      ; multiply by 2 and add $8000 to get slot2 pointer
      sla l
      rl h
      sla l
      rl h
      ld de,$8000
      add hl,de
      
;      call doHashBucketLookup
      ; fetch bank
      call bankedFetch
      push af
        ; fetch pointer to DE
        ; pointer low
        inc hl
        call bankedFetch
        ld e,a
        ; pointer high
        inc hl
        call bankedFetch
        ld d,a
        
        ; HL = pointer
        ex de,hl
      pop af
      ld b,a
    
    ; restore raw srcptr
    pop de
    
    ; if high byte of result ptr is FF, pointer not mapped
    ld a,h
    cp $FF
    jr z, @failure
    
      call getPointerInfoFromBucketArray
      ; return banknum in A
;        ld a,c
      jr @done
    
    ; failure
    @failure:
    ld c,noBankIdentifier
    
    @done:
    ret
.ends */


