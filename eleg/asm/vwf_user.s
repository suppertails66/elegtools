
.slot 2
.section "vwf user-implemented code" superfree APPENDTO "vwf and friends"
  ;================================
  ; if any VWF tiles are in use
  ; somewhere in the program,
  ; but are not currently used in
  ; the VDP nametable, flag them
  ; as allocated
  ;================================
  markHiddenVwfTilesAllocated_user:
/*    ; if any VWF tiles are hidden by an open window, flag them
    @windowHideCheck:
    ld a,(openWindowCount)
    or a
    jr z,+
      push de
      push bc
        ld b,a
        -:
          ld hl,(highestOpenWindowAddr)
          
          ; skip VDP addr
          inc l
          inc l
          
          ; height
          ld e,(hl)
          inc l
          ; width
          ld d,(hl)
          inc l
          
          push hl
          push bc
            call checkHiddenVwfTiles
          pop bc
          pop hl
          
          ; move to next-lowest window
          dec h
          djnz -
      
      pop bc
      pop de
    +: */
    
    push bc
    push de
    push hl
      ld hl,screenTilemapBufferVisible
      ld bc,screenTilemapBufferW*screenTilemapBufferVisibleH
      @loop:
        ld a,(hl)
        or a
        jr z, +
        cp textTileEnd
        jr nc, +
          ; tile is in text range
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
            ld a,$FF
            ld (hl),a
          pop hl
        +:
        
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,@loop
    pop hl
    pop de
    pop bc
    
    ret
  
  ;=====
  ; check if we printed into the tile containing the right border
  ; of the window. if so, we need to draw the border onto the
  ; tile.
  ; (done primarily to allow us to "cheat" so we can squeeze
  ; seven-character party member names into what was supposed to be
  ; a four-tile space)
  ;=====
  checkBorderTransfer_user:
/*    ; FIXME: oops non-nametable prints aren't setting up the width
    ld a,(vwfLocalTargetFlag)
    or a
    ret z
    
    ; FIXME: this only works for nametable transfers if the base x-offset
    ; is 1
    ld a,(printOffsetX)
    inc a
    inc a
;    ld hl,printAreaW
    ld hl,vwfLocalTargetW
    cp (hl)
    jr nz,+
      push bc
        ; border is 4px on right side of tile
        ld c,$F0
        ld b,:font_rshift_00
        ld de,vwfBuffer
        ld hl,font_rshift_00+(bytesPerTile*vwfWindowRBorderIndex)
        call orToTileBuffer
      pop bc
    +: */
    
    ret
  
  ;================================
  ; check for special printing
  ; sequences.
  ;
  ; A = character index
  ; HL = pointer to data immediately following character
  ;================================
;  checkPrintOpcodes_user:
  printVwfChar_user:
    ; check for linebreak
/*    cp vwfBrIndex
    jr nz,+
      call sendVwfBufferIfPending
      
      ; reset VWF
      call resetVwf
      
      @vdpLinebreak:
      ; reset X
      xor a
      ld (printOffsetX),a
      
      ; Y++
      ld a,(printOffsetY)
;          add a,$02
      inc a
      ld (printOffsetY),a
      
      ld a,(vwfLocalTargetFlag)
      or a
      jr z,++
        @localLinebreak:
        push hl
          ld hl,(vwfLocalTargetCurrLineAddr)
          
          ; add nametable tile width * 2 to current line address to
          ; get next line's address
          ld a,(vwfLocalTargetW)
          sla a
          ld e,a
          ld d,$00
          add hl,de
          
          ld (vwfLocalTargetCurrLineAddr),hl
        pop hl
        jr @done
      ++:
      
      ; if printing to VDP and we exceeded the height of the printing area,
      ; we have to shift the bottom rows up
      ld a,(printAreaH)
      ld e,a
      ld a,(printOffsetY)
      cp e
      jr c,@done
        call doLineBreakLineShift
        jr @done
    +:
    
    ; check for box clear
    cp vwfBoxClearIndex
    jr nz,+
      @boxClear:
      
      ; deallocate box area
      ld hl,(printBaseXY)
      ld bc,(printAreaWH)
      call deallocVwfTileArea
      
      ; clear box (fill with tile 0101)
      push hl
        ld bc,(printAreaWH)
        
        ld de,(oldPrintNametableBase)
        ld a,e
        add a,$01
        ld e,a
        
        ld hl,(printBaseXY)
        
        call clearNametableArea
        
        ; reset print offset
        ld hl,$0000
        ld (printOffsetXY),hl
      pop hl
      
      jr @done
    +:
    
    ; check for new inline number print op
    cp opInlineNumIndex
    jr nz,+
      @newNumOp:
      push hl
        call printScriptNum
      pop hl
      jr @done
    +: */

    ld c,a
    call printVwfChar

    @done:
    ret
    
  ; BC = w/h
  ; DE = clear value
  ; HL = x/y
/*  clearNametableArea:
    dec b
    dec c
    
    @clearYLoop:
      
      push bc
      
      @clearXLoop:
        push hl
        push bc
          add hl,bc
          call writeLocalTileToNametable
        pop bc
        pop hl
        
        dec b
        jp p,@clearXLoop
      
      pop bc
      dec c
      jp p,@clearYLoop
    ret
  
  ; move box lines 1..n up a line, deleting line 0
  doLineBreakLineShift:
    push hl
      ; deallocate top line
      ld hl,(printBaseXY)
      ld bc,(printAreaWH)
      ld c,1
      call deallocVwfTileArea
      
      ; target lines 1..n
      ld hl,(printBaseXY)
      inc l
      ld bc,(printAreaWH)
      dec c
      
      @yLoop:
        
        push hl
        push bc
        @xLoop:
          push bc
            ; read tile from original pos
            push hl
              call readLocalTileFromNametable
            pop hl
            
            ; write to (y - 1)
            push hl
              dec l
              call writeLocalTileToNametable
            pop hl
          pop bc
          ; move to next x-pos
          inc h
          djnz @xLoop
        
        pop bc
        pop hl
        ; move to next y-pos
        inc l
        dec c
        jr nz,@yLoop
      
      ; move y-offset up a line
      
      ld a,(printOffsetY)
      dec a
      ld (printOffsetY),a
      
      ; clear bottom line
      
      ld bc,(printAreaWH)
      
      ld de,(oldPrintNametableBase)
      ld a,e
      add a,$01
      ld e,a
      
      ; target bottom line
      ld hl,(printBaseXY)
      ld a,l
      add a,c
      dec a
      ld l,a
      
      ld c,1
      
      call clearNametableArea
    
    pop hl
    ret */
  
  ; B = string bank
  ; HL = string pointer
  printVwfString_user:
/*    ; load string bank (slot 1)
;    ld a,(mapperSlot1Ctrl)
;    push af
;      ld a,b
;      ld (mapperSlot1Ctrl),a

      @printLoop:
        call bankedFetch
;        ld a,(hl)
        inc hl
        
        ; check for terminator
        cp terminatorIndex
        jr z,@printingDone
          
        push bc
  ;        call checkPrintOpcodes_user
          push hl
            call printVwfChar_user
          pop hl
          
          ; C = target char index
;          ld c,a
;          push hl
;            call printVwfChar
;          pop hl
;        inc hl
        pop bc
        jr @printLoop
      
      @printingDone:
      
      ; do possible final transfer
      call sendVwfBufferIfPending
      
;    pop af
;    ld (mapperSlot1Ctrl),a */
    ret

  ;; FIXME
  .define mainScreenScrollXLo $C01E
  .define mainScreenScrollYLo $C01F

  getScrollX_user:
    ld a,(mainScreenScrollXLo)
    ret
  
  getScrollY_user:
    ld a,(mainScreenScrollYLo)
    ret
  
  ; DE = nametable data
  ; HL = (nominal) nametable coordinates
  handleNametablePrint_user:
    push de
      
      ; swap x/y
      ld a,h
      ld c,a
      ld a,l
      ld b,a
      
      call yxCoordsToVisibleScreenBuf
      
      ; deallocate the tile we are about to write to
      ; (in case we are overwriting previously printed content)
      ld a,(hl)
      call deallocateLocalTile
    pop de
    
    ld (hl),e
    
    ret
  
  ; A = tile ID
  deallocateLocalTile:
    or a
    jr z, +
    cp textTileEnd
    jr nc, +
    ; tile is in text range
/*      ld c,a
      ld b,$00
      ld hl,(vwfAllocationArrayBaseTile)
      or a
      sbc hl,bc */
      
      call unqueueTile
      
      ; HACK: we know the base tile is always 1...
      dec a
      ; HACK: allocation array is $100-aligned
      ld d,>vwfAllocationArray
      ld e,a
      xor a
      ld (de),a
    +:
    
    ret
  
  fullyResetVwf_user:
    call freeAllVwfTiles
    jp resetVwf
  
  
.ends
