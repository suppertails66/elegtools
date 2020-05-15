
; TODO:
;   * read VWF strings through slot 1 banking (must disable interrupts
;     if no disable flag not set)
;   * fix nametable border composition and stuff

.slot 2
.section "vwf and friends" superfree
  ;===================================
  ; divides DE by BC
  ;
  ; BC = divisor
  ; DE = dividend
  ;
  ; returns:
  ; DE = quotient
  ; HL = remainder
  ;===================================
  divide16Bit:
    
    ld hl,$0000
    ld a,$10
    @divLoop:
      ; shift high bit of dividend into low bit of remainder
      sla e
      rl d
      rl l
      rl h
      
      ; subtract divisor
      or a
      sbc hl,bc
      jr c,+
        ; subtraction succeeded: 1 bit in result
        inc e
        
        ; result becomes new remainder
        ld h,b
        ld l,c
      +:
      
      dec a
      jr nz,@divLoop
    
    ret
  
  ;===================================
  ; converts a 16-bit value to
  ; binary-coded decimal (1 byte per
  ; digit)
  ;
  ; DE = value
  ;
  ; returns:
  ;     numberConvBuffer = BCD representation of number
  ;===================================
  bcdConv16Bit:
    ld bc,maxPrintingDigits
    -:
      push bc
        ; divide by 10
        ld bc,10
        call divide16Bit
        
        ; remainder = digit
        ld a,l
      pop bc
      
      dec c
      
      ; save to conversion buffer
      ld hl,numberConvBuffer
      add hl,bc
      ld (hl),a
      
      ld a,c
      or a
      jr nz,-
    ret
    
  ;===================================
  ; sends raw tile data to VDP
  ;
  ; B = number of tiles
  ; DE = src data pointer
  ; HL = VDP dstcmd
  ;===================================
  sendRawTilesToVdp:
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
    ret
  
  ;===================================
  ; reads a 16-bit table
  ;
  ; A = index
  ; HL = table pointer
  ;
  ; returns:
  ;   HL = data
  ;===================================
  read16BitTable:
    read16BitTable_macro
    ret
  
  ;========================================
  ; A  = index
  ; HL = table pointer
  ;
  ; returns absolute pointer in HL
  ;========================================
  readOffsetTable:
    push de
      push hl
        call read16BitTable
      pop de
      add hl,de
    pop de
    
    ret
  
.ends

.slot 2
.section "vwf and friends 2" superfree APPENDTO "vwf and friends"
  ;========================================
  ; returns a free VWF tile index in HL
  ;========================================
  allocVwfTile:
    jp allocVwfTile_main
  
  allocVwfTile_main:
;    push hl
    push de
    push bc
    
;      ld h,>vwfAllocationArray
;      ld a,(vwfAllocationArrayPos)
;      ld l,a
      ld a,(vwfAllocationArrayPos)
      ld l,a
      ld h,$00
      ld bc,vwfAllocationArray
      ; save starting search point to E
      ld e,a
      ld d,$00  ; flag: set after garbage collection
      @searchLoop:
        
        ; preincrement (saves a little time)
        inc l
        
        ; HACK: don't assign tile $6D (used for blank backgrounds)
;        ld a,(vwfAllocationArrayBaseTileLo)
;        cp <vwfTileBase_main
;        jr nz,+
          ld a,l
          cp $6D-(<vwfTileBase_main)
          jr nz,+
            inc l
            jr ++
          +:
          ; HACK: don't assign tiles $71-73 (cursors)
          cp $71-(<vwfTileBase_main)
          jr c,+
            cp $74-(<vwfTileBase_main)
            jr nc,+
              ld l,$74-(<vwfTileBase_main)
              jr ++
          +:
          ; HACK: don't assign tiles $B6-B7 (empty slot dashes)
;          cp $B6-(<vwfTileBase_main)
;          jr c,+
;            cp $B8-(<vwfTileBase_main)
;            jr nc,+
;              ld l,$B8-(<vwfTileBase_main)
;              jr ++
;          +:
        ++:
        
        
        ; wrap around at end of array
        ld a,(vwfAllocationArraySize)
        cp l
;        jr nz,++       ; for safety reasons, do the full check for now
        jr z,+
        jr nc,++
          +:
          ld l,$00
;          ld a,l
        ++:
        
        ; check if second loop done (D nonzero)
        ld a,d
        or a
        jr z,+
          ; check if current index == startindex
          ld a,e
          cp l
          jr nz,+
            @fullLoad:
            
            ; uh-oh: we ran garbage collection, but there are still no tiles
            ; available. there's nothing we can do to actually fix the problem
            ; at this point, so we just declare all tiles free and cause some
            ; visual corruption so the new stuff can print.
;            call freeAllVwfTiles
            
            ; actually, just overwrite the next tile in the sequence and
            ; re-run this whole procedure next time we print something.
            ; will cause considerable slowdown but less noticeable corruption
            jr @done
            
            ; TODO: possible last resort: search for blank/duplicate tiles
            ; or blank VWF tiles outside of current window
        +:
        
        ; if allocation array is totally full (we've looped to our starting
        ; point), run garbage collection and hope for the best
        ; (note: actually can run when array is one short of full. same deal.)
        ld a,e
        cp l    ; compare current pos to initial
        jr nz,+
          call collectVwfGarbage
          
          ; flag D so that, if no tiles are available even after
          ; garbage collection, we can detect a second loop
          inc d
        +:
        
        @checkCurrentTile:
        push hl
          ; add array base address to current check index
          add hl,bc
          ; if byte nonzero, slot is in use
          ld a,(hl)
          or a
          jr z,+
            pop hl
            jr @searchLoop
        +:
        
        ; HACK:
        ; do an additional check:
        ; if on the first loop, do not allocate tiles
        ; that are currently being used for display
        
        ; allocate unconditionally if D nonzero (= on second loop)
        ld a,d
        or a
        jr z,+
          pop de
          jr @done
        +:
        
        ; otherwise, check the visible-screen allocation array
        ld (scratchB),de
        pop de
        push hl
          call fetchVisibleAllocationArrayEntry
        pop hl
        
        ; done if zero (= not allocated)
        or a
        jr z,@done
        
        ; return to search loop
        ex de,hl
        ld de,(scratchB)
        jr @searchLoop
      
      @done:
      ; DE = target check index
      ; HL = allocation array target position pointer
      
      ; mark tile as allocated (nonzero)
;      inc (hl)
      ld a,$FF
      ld (hl),a
      
      ; save search pos
      ld a,e
      ld (vwfAllocationArrayPos),a
      
      ; add offset to actual tile index
;      ld e,a
;      ld d,0
      ld hl,(vwfAllocationArrayBaseTile)
      add hl,de
    
    pop bc
    pop de
;    pop hl
    ret
  
  ;========================================
  ; marks all VWF tiles as free
  ;========================================
  freeAllVwfTiles:
    push hl
    push bc
      
      ld b,maxVwfTiles
      ld hl,vwfAllocationArray
      -:
        ld (hl),$00
        inc hl
        djnz -
    
    pop bc
    pop hl
    ret
  
  ;========================================
  ; initialize VWF tile allocation.
  ; resets and configures with new parameters
  ; 
  ; A  = number of tiles
  ; B  = assume nametable zero flag
  ; C  = high byte for nametable prints
  ; HL = base tile index
  ;========================================
  setUpVwfTileAlloc:
    ld (vwfAllocationArraySize),a
    ld (vwfAllocationArrayBaseTile),hl
    xor a
    ld (vwfAllocationArrayPos),a
    
    ld a,b
    ld (assumeScrollZeroFlag),a
    
    ; should this be a parameter?
    ld a,c
    ld (vwfNametableHighMask),a
    
    call freeAllVwfTiles
    call resetVwf
    ret
  
  ;========================================
  ; marks a VWF tile as free
  ;
  ; DE  = tile index
  ;========================================
  freeVwfTile:
    push hl
    
      ; subtract base position from tile index
      ld hl,(vwfAllocationArrayBaseTile)
      ex de,hl
      or a
      sbc hl,de
      
      ; low byte = index into 0x100-aligned allocation array
;      ld h,>vwfAllocationArray
      ; low byte = index into allocation array
      ex de,hl
      ld hl,vwfAllocationArray
      add hl,de
      
      ; if full deallocation flag zero, zero reference counter
      ld a,(vwfFullDeallocFlag)
      or a
      jr nz,+
        ld (hl),$00
        jr @done
      +:
      
      ; if nonzero, decrement reference counter
      @decReferenceCounter:
        dec (hl)
    
    @done:
    pop hl
    ret
  
  ;========================================
  ; reads the nametable in the specified coordinates and deallocates all
  ; VWF tiles contained within
  ;
  ; HL = screen-local tile x/y
  ; BC = box w/h
  ;========================================
  deallocVwfTileArea:
    push hl
    push bc
      
      @yLoop:
        
        ; save W
        push hl
        push bc
          
          @xLoop:
            ; read tile using readTileFromNametable
            push bc
              push hl
                call readLocalTileFromNametable
              pop hl
              
              ; high bytes must match (i.e. in same table half)
              
              ; AND high byte to just bit 0 (bit 9 of pattern num)
              ld a,d
              and $01
              ld d,a
              ; compare to nametable target high byte
              ld a,(vwfAllocationArrayBaseTileHi)
              cp d
              jr nz,+
              
              ; ignore tiles < start index
              @checkLow:
              ld a,(vwfAllocationArrayBaseTileLo)
              cp e
              jr z,@checkHigh
              jr nc,+
                
                ; ignore tiles > end index
                @checkHigh:
                ld c,a  ; C = low byte of base VWF tile index
                ld a,(vwfAllocationArraySize)
                add a,c
                cp e
                jr z,+
                jr c,+
                
                  ; free the tile
                  @free:
                  call freeVwfTile
                  
              +:
            pop bc
            
            ; move to next X
            inc h
            dec b
            jr nz,@xLoop
            
          @xLoopDone:
        
        ; restore W
        pop bc
        pop hl
        
        ; move to next Y
        inc l
        dec c
        jr nz,@yLoop
    
    @done:
    pop bc
    pop hl
    ret
  
  ;========================================
  ; reads the nametable at the specified
  ; nametable-absolute address and frees
  ; all VWF tiles in the specified box
  ;
  ; HL = address
  ; BC = box w/h
  ;========================================
  deallocVwfTileAreaByAddr:
    push hl
    push bc
      
      call nametableAddrToLocalCoords
      call deallocVwfTileArea
      
    pop bc
    pop hl

    ret
  
  ;========================================
  ; HL = nametable address
  ;========================================
  nametableAddrToAbsoluteCoords:
    push de
      ; nametable addr -= $3800
      ld de,$3800
      or a
      sbc hl,de
      
      ; y-pos = amount / $40
      push hl
        .rept 6
          srl h
          rr l
        .endr
        ld e,l
      pop hl
      
      ; x-pos = (amount % $40) / 2
      ld a,l
      and $3F
      srl a
      
      ; X
      ld h,a
      ; Y
      ld l,e
    pop de
    ret
  
  nametableAddrToLocalCoords:
    call nametableAddrToAbsoluteCoords
    push de
      call absoluteToLocalCoords
    pop de
    ret
  
  ;========================================
  ; fully reset the VWF allocation buffer.
  ; clears existing buffer contents, then reads all visible tiles from VDP and
  ; marks those actually in use as allocated.
  ; obviously has considerable overhead, so this routine's use should be
  ; minimized as much as possible.
  ;========================================
  collectVwfGarbage:
    ; clear buffer
    call freeAllVwfTiles
    
    push hl
    push de
    push bc
      
/*      ;=====
      ; evaluate visible screen area and mark all used VWF tiles as
      ; allocated
      ;=====
      
;      ld h,screenVisibleX
;      ld l,screenVisibleY
      ld h,0
      ld l,0
      ld b,screenVisibleW
      ld c,screenVisibleH
      
      ; vwfFullDeallocFlag nonzero = decrement reference counter
      ld a,$01
      ld (vwfFullDeallocFlag),a
        ; allocate area
        call deallocVwfTileArea
      xor a
      ld (vwfFullDeallocFlag),a */
    
      ;=====
      ; if VWF tiles have been temporarily hidden behind another tilemap,
      ; mark them as allocated
      ;=====
      
      call markHiddenVwfTilesAllocated
    
    @done:
    pop bc
    pop de
    pop hl
    
    ret
  
  markHiddenVwfTilesAllocated:
    
    ; if composing local tilemap, flag any VWF tiles used there
/*    ld a,(vwfLocalTargetFlag)
    or a
    jr z,+
      ld a,(vwfLocalTargetW)    ; window w
      ld d,a
      ld a,(vwfLocalTargetH)    ; window h
      ld e,a
      ld hl,(vwfLocalTargetBaseAddr)     ; tile data start
    
      call checkHiddenVwfTiles
      
;      call checkLocalNametableHiddenTiles_user
    +: */
    
    jp markHiddenVwfTilesAllocated_user
      
    @done:
    ret
  
  ;========================================
  ; HL = data pointer
  ; DE = w/h
  ;========================================
  checkHiddenVwfTiles:
      
      @yLoop:
        
        ; save W
        push de
          
          @xLoop:
            push de
              ; get nametable entry
              ld a,(hl)
              ld e,a
              inc hl
              ld a,(hl)
;              ld d,a
              inc hl
            
              ; high bytes must match (i.e. in same table half)
              
              ; AND high byte to just bit 0 (bit 9 of pattern num)
;              ld a,d
              and $01
              ld d,a
              ; compare to nametable target high byte
              ld a,(vwfAllocationArrayBaseTileHi)
              cp d
              jr nz,+
              
              ; ignore tiles < start index
              @checkLow:
              ld a,(vwfAllocationArrayBaseTileLo)
              cp e
              jr z,@checkHigh
              jr nc,+
                
                ; ignore tiles > end index
                @checkHigh:
                ld c,a  ; C = low byte of base VWF tile index
                ld a,(vwfAllocationArraySize)
                add a,c
                cp e
                jr z,+
                jr c,+
                
                  ; mark the tile as allocated
  ;                    call freeVwfTile
                  @hiddenTileFound:
                  push hl
                    ; subtract base position from tile index
                    ld hl,(vwfAllocationArrayBaseTile)
                    ex de,hl
                    or a
                    sbc hl,de
                    
                    ; low byte = index into 0x100-aligned allocation array
;                    ld h,>vwfAllocationArray
                    ex de,hl
                    ld hl,vwfAllocationArray
                    add hl,de
                    ld a,$FF
                    ld (hl),a
                  pop hl
            
            +:
            pop de
;            inc hl
            dec d
            jr nz,@xLoop
            
          @xLoopDone:
        
        ; restore W
        pop de
        
        ; move to next Y
        dec e
        jr nz,@yLoop
    ret
  
  ;========================================
  ; convert local coordinates to absolute
  ;
  ; HL = screen-local X/Y
  ;========================================
  localToAbsoluteCoords:
    ; if force-zero flag is set, assume nametable scroll is zero on
    ; both axes
    ld a,(assumeScrollZeroFlag)
    or a
    jr nz,@assumeNametableZero
    
      ; convert screen-local coords to absolute nametable coords
      
      ;=====
      ; x
      ;=====
      
      ; get raw scrolling x-coord
;      ld a,(mainScreenScrollXLo)
      call getScrollX_user
      ; divide by 8
      srl a
      srl a
      srl a
      ; add target X
      add a,h
      ; add visible-screen tile offset
      add a,screenVisibleX
      
      ; wrap to valid range (0-1F)
      and $1F
      
      ld h,a
      
      ;=====
      ; y
      ;=====
      
      ; get raw scrolling y-coord
;      ld a,(mainScreenScrollYLo)
      call getScrollY_user
      ; divide by 8
      srl a
      srl a
      srl a
      ; add target Y
      add a,l
      ; add visible-screen tile offset
      add a,screenVisibleY
      
      ; wrap to 0-1F
;      and $1F
      ; remap 1C+ to 00-03
      cp $1C
      jr c,+
        sub $1C
      +:
      
      ld l,a
      
      jr @done
    
    @assumeNametableZero:
    ; x
    ld a,h
    add a,screenVisibleX
    ld h,a
    ; y
    ld a,l
    add a,screenVisibleY
    ld l,a
    
    @done:
    
    ret
  
  absoluteToLocalCoords:
    ; if force-zero flag is set, assume nametable scroll is zero on
    ; both axes
    ld a,(assumeScrollZeroFlag)
    or a
    jr nz,@assumeNametableZero
    
      ; convert absolute nametable coords to screen-local
      
      push bc

        ;=====
        ; x
        ;=====
        
        ; get raw scrolling x-coord
;        ld a,(mainScreenScrollXLo)
        call getScrollX_user
        ; divide by 8
        srl a
        srl a
        srl a
        ; add visible-screen tile offset
        add a,screenVisibleX
        and $1F
        ; subtract from target X
        ld c,a
        ld a,h
        sub c
        ld h,a
        
        ;=====
        ; y
        ;=====
        
        ; get raw scrolling x-coord
;        ld a,(mainScreenScrollYLo)
        call getScrollY_user
        ; divide by 8
        srl a
        srl a
        srl a
        ; add visible-screen tile offset
        add a,screenVisibleY
        ; wrap to 0-1F
        ; remap 1C+ to 00-03
        cp $1C
        jr c,+
          sub $1C
        +:
        ; subtract from target Y
        ld c,a
        ld a,l
        sub c
        ld l,a
      
      pop bc
      
      jr @done
    
    @assumeNametableZero:
    ; x
    ld a,h
    sub screenVisibleX
    ld h,a
    ; y
    ld a,l
    sub screenVisibleY
    ld l,a
    
    @done:
    
    ret
  
  ;========================================
  ; reads a screen-local tile from the
  ; nametable
  ;
  ; HL = screen-local X/Y
  ;
  ; returns result in DE
  ;========================================
  readLocalTileFromNametable:
    call localToAbsoluteCoords
;    jp readAbsoluteTileFromNametable
  ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ; !!!!!!! DROP THROUGH -- DO NOT PLACE NEW CODE HERE !!!!!!!!
  ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ;========================================
  ; reads a tile from the nametable
  ;
  ; HL = absolute nametable X/Y
  ;
  ; returns result in DE
  ;========================================
  readAbsoluteTileFromNametable:
    ; DE = X * 2
    ld a,h
    sla a
    ld e,a
    ; add $3800 to get read command + target address
    ld d,$38
    
    ; HL = Y * $40
/*    ld h,$00
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl */
    ld a,l
    ld hl,$0000
    srl a
    rr l
    srl a
    rr l
    ld h,a
    
    ; add x-offset to base Y
    add hl,de
    
    ;=====
    ; do the read
    ;=====
    
    ; if no interrupt disable flag set, don't disable interrupts
    ld a,(noInterruptDisableFlag)
    or a
    jr nz,+
      di
        ; set address
        ld a,l
        out ($BF),a
        ld a,h
        out ($BF),a
        
        ; waste cycles
        push iy
        pop iy
        ; read low byte
        in a,($BE)
        ld e,a
        
        ; waste cycles
        push iy
        pop iy
        ; read high byte
        in a,($BE)
        ld d,a
      ei
      ret
    +:
    
    ; set address
    ld a,l
    out ($BF),a
    ld a,h
    out ($BF),a
        
    ; waste cycles
    push iy
    pop iy
    ; read low byte
    in a,($BE)
    ld e,a
    
    ; waste cycles
    push iy
    pop iy
    ; read high byte
    in a,($BE)
    ld d,a
    
    ret
  
  ;========================================
  ; writes a tilemap to the nametable
  ;
  ; BC = tilemap W/H
  ; DE = src data
  ; HL = screen-local X/Y
  ;========================================
  writeLocalTilemapToNametable:
    push hl
    push bc
      
      @yLoop:
        
        ; save W
        push hl
        push bc
          
          @xLoop:
            ; write next tile
            push bc
            push hl
              ld a,(de)
              ld c,a
              inc de
              
              ld a,(de)
              inc de
              
              push de
                ld d,a
                ld a,c
                ld e,a
                call writeLocalTileToNametable
              pop de
            pop hl
            pop bc
            
            ; move to next X
            inc h
            dec b
            jr nz,@xLoop
            
          @xLoopDone:
        
        ; restore W
        pop bc
        pop hl
        
        ; move to next Y
        inc l
        dec c
        jr nz,@yLoop
    
    @done:
    pop bc
    pop hl
    ret
  
  ;========================================
  ; writes a screen-local tile to the
  ; nametable
  ;
  ; DE = tile
  ; HL = screen-local X/Y
  ;========================================
  writeLocalTileToNametable:
    call localToAbsoluteCoords
;    jp readAbsoluteTileFromNametable
  ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ; !!!!!!! DROP THROUGH -- DO NOT PLACE NEW CODE HERE !!!!!!!!
  ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ;========================================
  ; writes a tile from the nametable
  ;
  ; DE = tile
  ; HL = absolute nametable X/Y
  ;========================================
  writeAbsoluteTileToNametable:
    ; BC = X * 2
    ld a,h
    sla a
    ld c,a
    ; add $7800 to get write command + target address
    ld b,$78
    
    ; HL = Y * $40
/*    ld h,$00
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl */
    ld a,l
    ld hl,$0000
    srl a
    rr l
    srl a
    rr l
    ld h,a
    
    
    ; add x-offset to base Y
    add hl,bc
    
    ;=====
    ; do the write
    ;=====
    
    ; if no interrupt disable flag set, don't disable interrupts
    ld a,(noInterruptDisableFlag)
    or a
    jr nz,+
    
      di
        ; set address
        ld a,l
        out ($BF),a
        ld a,h
        out ($BF),a
        
        ld a,e
        ; waste cycles
        push iy
        pop iy
        ; write low byte
        out ($BE),a
        
        ld a,d
        ; waste cycles
        push iy
        pop iy
        ; write high byte
        out ($BE),a
      ei
      ret
    +:
    
    ; set address
    ld a,l
    out ($BF),a
    ld a,h
    out ($BF),a
    
    ld a,e
    ; waste cycles
    push iy
    pop iy
    ; write low byte
    out ($BE),a
    
    ld a,d
    ; waste cycles
    push iy
    pop iy
    ; write high byte
    out ($BE),a
    
    ret
  
  ;========================================
  ; reset the VWF buffer
  ;========================================
  resetVwf:
    push hl
      xor a
      
      ; reset pixel x-pos
      ld (vwfPixelOffset),a
      ld (vwfBufferAllocatedTile+0),a
      ld (vwfBufferAllocatedTile+1),a
      ld (vwfBufferPending),a
      
      ; force text reinit on next print call
      ld hl,lastPrintBaseY
      ld (hl),$FF
      
      ; clear tile composition buffer
      ld hl,vwfBuffer
      ld b,bytesPerTile
      -:
        ld (hl),a
        inc hl
        djnz -
    pop hl
    ret
  
/*  doVwf:
    ld a,(mapperSlot1Ctrl)
    push af
      
      ; C = target char index
      ld a,:printVwfChar
      ld (mapperSlot1Ctrl),a
      call printVwfChar
      
    pop af
    ld (mapperSlot1Ctrl),a
    ret */
  
  sendVwfBuffer:
    push hl
    push bc
      
      ;=====
      ; allocate tile for buffer if unallocated
      ;=====
      ld hl,vwfBufferAllocatedTileHi
      ld a,(vwfBufferAllocatedTileLo)
      or (hl)
      ld c,a    ; C will be zero if tile is newly allocated,
                ; so we know to send it to the nametable later
;      or a
      jr nz,+
        call allocVwfTile
        ld (vwfBufferAllocatedTile),hl
      +:
      
      ; HL = dst tile index
/*      ld hl,(vwfBufferAllocatedTile)
      ; multiply by 32 and add $4000 to get VDP target command
      add hl,hl
      add hl,hl
      add hl,hl
      add hl,hl
      add hl,hl
      ld de,$4000
      add hl,de
      ; DE = src data pointer
      ld de,vwfBuffer
      ; B = tile count
      ld b,$01
      push bc
        ld a,(noInterruptDisableFlag)
        or a
        jr nz,+
          di
            call sendRawTilesToVdp
          ei
          jr ++
        +:
          call sendRawTilesToVdp
        ++:
      pop bc */
      ; HACK: do not send immediately.
      ; instead, place in game-specific queue.
      ; tile data will be transferred when tilemap is sent.
      ld a,(vwfBufferAllocatedTile)
      push bc
        call queueTile
      pop bc
      
      ;=====
      ; if tile newly allocated, send to nametable
      ;=====
      ld a,c    ; check if initial tile num was zero
      or a
      jr nz,+
      
        ;=====
        ; send to nametable
        ;=====
        
        ; x/y pos
        ld hl,(printOffsetXY)
        
        ; tile index
        ld de,(vwfBufferAllocatedTile)
        
        ; apply OR mask to high byte of nametable data
        ld a,(vwfNametableHighMask)
        or d
        ld d,a
        call writeVwfCharToNametable
      +:
      
      ; reset buffer pending flag
      xor a
      ld (vwfBufferPending),a
    
    pop bc
    pop hl
    ret
  
  ; DE = nametable data
  ; HL = target local coords
  writeVwfCharToNametable:
    ;=====
    ; if not targeting local nametable, send directly to VDP
    ;=====
    ld a,(vwfLocalTargetFlag)
    or a
    jp z,writeLocalTileToNametable
    
    ;=====
    ; write to local nametable
    ;=====
    
    @localNametable:
    
    ; get current line address
/*    ld hl,(vwfLocalTargetCurrLineAddr)
    
    ; add x-offset * 2
    ld a,(printOffsetX)
    sla a
    add a,l
    ld l,a
    ld a,$00
    adc a,h
    ld h,a
    
    ; write
    ld (hl),e
    inc hl
    ld (hl),d */
    
    call handleNametablePrint_user
    
    ret
    
  
  sendVwfBufferIfPending:
    ld a,(vwfBufferPending)
    or a
    jr z,+
;      callExternal sendVwfBuffer
      call sendVwfBuffer
    +:
    ret
.ends

.bank 1 slot 1
.section "vwf data copy routines 1" free
  ;========================================
  ; B = src data bank
  ; C = AND mask for each existing byte in buffer
  ; DE = dst pointer
  ; HL = src data pointer
  ;========================================
  orToTileBuffer:
    ld a,(mapperSlot2Ctrl)
    push af
      
      ld a,b
      ld (mapperSlot2Ctrl),a
      ld b,bytesPerTile
      -:
        ld a,(de)
        and c
        or (hl)
        ld (de),a
        
        inc hl
        inc de
        djnz -
      
    pop af
    ld (mapperSlot2Ctrl),a
    ret
.ends
  
.bank 1 slot 1
.section "vwf data copy routines 2" free
  ;========================================
  ; B = src data bank
  ; DE = dst pointer
  ; HL = src data pointer
  ;========================================
  copyToTileBuffer:
    ld a,(mapperSlot2Ctrl)
    push af
      
      ld a,b
      ld (mapperSlot2Ctrl),a
      ld bc,bytesPerTile
      ldir
      
    pop af
    ld (mapperSlot2Ctrl),a
    ret
.ends

.ifexists "../out/font/font.inc"
  .include "out/font/font.inc"

  .slot 2
  .section "vwf and friends 3" superfree APPENDTO "vwf and friends"
    fontSizeTable:
      .incbin "out/font/sizetable.bin" FSIZE fontCharLimit
      .define numFontChars fontCharLimit-1

    fontRightShiftBankTbl:
      .db :font_rshift_00
      .db :font_rshift_01
      .db :font_rshift_02
      .db :font_rshift_03
      .db :font_rshift_04
      .db :font_rshift_05
      .db :font_rshift_06
      .db :font_rshift_07
    fontRightShiftPtrTbl:
      .dw font_rshift_00
      .dw font_rshift_01
      .dw font_rshift_02
      .dw font_rshift_03
      .dw font_rshift_04
      .dw font_rshift_05
      .dw font_rshift_06
      .dw font_rshift_07
    fontLeftShiftBankTbl:
      .db :font_lshift_00
      .db :font_lshift_01
      .db :font_lshift_02
      .db :font_lshift_03
      .db :font_lshift_04
      .db :font_lshift_05
      .db :font_lshift_06
      .db :font_lshift_07
    fontLeftShiftPtrTbl:
      .dw font_lshift_00
      .dw font_lshift_01
      .dw font_lshift_02
      .dw font_lshift_03
      .dw font_lshift_04
      .dw font_lshift_05
      .dw font_lshift_06
      .dw font_lshift_07
    
    charANDMasks:
      .db $00,$80,$C0,$E0,$F0,$F8,$FC,$FE,$FF
    
    
    
    ; C = target char
    printVwfChar:
      ; handle tile break
      ld a,c
      cp opTileBr
      jr nz,+
        call sendVwfBufferIfPending
        call resetVwf
        ld hl,printOffsetX
        inc (hl)
        jp @done
      +:
    
    ;=====
    ; reset buffer if window has moved or print x/y offset has changed,
    ; which we interpret to mean a new string (sequence) has been
    ; started.
    ;=====
    
    ; if local print x or y has changed from last print,
    ; reset buffer
    ld a,(printOffsetX)
    ld hl,lastPrintOffsetX
    cp (hl)
    jr z,+
      -:
      call resetVwf
      jr @resetChecksDone
    +:
      ld a,(printOffsetY)
      ld hl,lastPrintOffsetY
      cp (hl)
      jr nz,-
    ++:
    
    ; if window base x or y has changed from last print,
    ; reset buffer
/*    ld a,(printBaseX)
    ld hl,lastPrintBaseX
    cp (hl)
    jr z,+
      -:
      call resetVwf
      jr @resetChecksDone
    +:
      ld a,(printBaseY)
      ld hl,lastPrintBaseY
      cp (hl)
      jr nz,-
    ++: */
    
    @resetChecksDone:
      
      ; vwf composition works like this:
      ; 1. OR left part of new character into composition buffer using
      ;    appropriate entry from right-shifted character tables.
      ;    (if vwfPixelOffset is zero, we can copy instead of ORing)
      ; 2. send composition buffer to VDP (allocating tile if not already done)
      ; 3. if composition buffer was filled, clear it.
      ; 4. if entire character has already been copied, we're done.
      ; 5. copy right part of new character directly to composition buffer using
      ;    appropriate entry from left-shifted character tables.
      ; 6. send composition buffer to VDP (allocating tile)
      
      ;=====
      ; look up size of target char
      ;=====
      
  ;    ld h,>fontSizeTable
  ;    ld a,c
  ;    ld l,a
      ld hl,fontSizeTable
      ld a,c
      ld e,a
      ld d,$00
      add hl,de
      
      ; get width
      ld a,(hl)
      ; if width is zero, we have nothing to do
      or a
      jp z,@done
      
      ld (vwfTransferCharSize),a
      
      ;=====
      ; transfer 1: XOR left part of target char with buffer
      ;=====
      
      @transfer1:
      
      ; if char is space, no transfer needed
      ; (or it wouldn't be, except what if nothing else has been printed
      ; to the buffer yet? then the part we skipped won't get the background
      ; color)
  ;    ld a,c
  ;    cp vwfSpaceCharIndex
  ;    jr z,@transfer1Done
      
        push bc
          
          ;=====
          ; look up character data
          ;=====
          
          ; B = bank
          ld a,(vwfPixelOffset)
          ld e,a
          ld d,$00
          ld hl,fontRightShiftBankTbl
          add hl,de
          ld b,(hl)
          
          ; HL = pointer to char table base
          ld hl,fontRightShiftPtrTbl
          ; pixel offset *= 2
          sla e
  ;      rl d     ; pointless, will never shift anything in
          add hl,de
          ld e,(hl)
          inc hl
          ld d,(hl)
          ; add offset to actual char
          ld l,c
          ld h,$00
          ; * 32 for tile offset
          add hl,hl
          add hl,hl
          add hl,hl
          add hl,hl
          add hl,hl
  ;        .rept 5
  ;          sla e
  ;          rl d
  ;        .endr
          add hl,de
          
          ; can copy to buffer instead of ORing if pixel offset is zero
          ld a,(vwfPixelOffset)
          or a
          jr nz,+
            ld de,vwfBuffer
            call copyToTileBuffer
            jr @dataTransferred
          +:
          
          ; look up AND mask to remove low bits
          push hl
            ld hl,charANDMasks
            ld a,(vwfPixelOffset)
            ld e,a
            ld d,$00
            add hl,de
            ld c,(hl)
          pop hl
          
          ;=====
          ; OR to buffer
          ;=====
          
          ld de,vwfBuffer
          call orToTileBuffer
          
          @dataTransferred:
          
        pop bc
        
        ; check if border needs to be added to tile
        call checkBorderTransfer
      
        ;=====
        ; send modified buffer
        ;=====
  ;       call sendVwfBuffer
      
      @transfer1CompositionDone:
      
      ; determine right transfer shift amount
      ld a,(vwfPixelOffset)
      ld b,a
      sub $08
      neg
      ld (vwfTransferRight_leftShift),a
      
      ; advance vwfPixelOffset by transfer size
  ;    ld a,b
  ;    ld b,a
      ld a,(vwfTransferCharSize)
      add a,b
      
      cp $08
      jr nc,+
        ; if position in VWF buffer < 8, no second transfer needed
        
        ; send modified buffer if print speed nonzero (printing character-
        ; by-character); if text printing is instant, this just wastes time.
        ; also send if only printing a single character.
        push af
;          ld a,$FF
;          ld (vwfBufferPending),a
          call sendVwfBuffer
          
  /*       ; if printing independent character rather than entire string,
          ; do buffer send
          ld a,(stringIsPrinting)
          or a
          jr z,++
          ; if print speed is zero (instant), don't do buffer send
          ld a,(printSpeed)
          or a
          jr z,+++
            ++:
            call sendVwfBuffer
          +++: */
        pop af
        
        ld (vwfPixelOffset),a
        jr @done
      +:
      jr nz,+
        ; if we filled the VWF buffer exactly to capacity, then we need to
        ; send it, but don't need a right transfer or new tile allocation.
        ; instead, we reset the buffer in case more text is added.
        
        ; send modified buffer
        call sendVwfBuffer
        
        ; reset buffer
  ;      xor a
  ;      ld (vwfPixelOffset),a
        call resetVwf
        ; move to next x-pos
  ;      ld a,(printOffsetX)
  ;      inc a
  ;      ld (printOffsetX),a
        ld hl,printOffsetX
        inc (hl)
        jr @done
      +:
      
      ;=====
      ; buffer filled, and second transfer needed
      ;=====
      
      ; save updated pixel offset
      push af
        ; send modified buffer
        call sendVwfBuffer
        
        ; we'll add content for the second transfer, so set the
        ; buffer pending flag
        ld a,$FF
        ld (vwfBufferPending),a
      ; restore updated pixel offset
      pop af
      
      ; modulo by 8 to get new offset in next buffer (after second transfer)
      and $07
      ld (vwfPixelOffset),a
      ; new allocation needed
      xor a
      ld (vwfBufferAllocatedTile+0),a
      ld (vwfBufferAllocatedTile+1),a
      ; move to next x-pos
      ld hl,printOffsetX
      inc (hl)
      
      ;=====
      ; transfer 2: copy right part of character to buffer
      ;=====
      
      @transfer2:
      
      ; transfer size of zero = skip
  ;    ld a,(vwfTransferRightSize)
  ;    jr z,@transfer2Done
      
      ; if char is space, no transfer needed
      ; (or it wouldn't be, except... something, I've already forgotten
      ; what this breaks. but it definitely breaks something)
  ;    ld a,c
  ;    cp vwfSpaceCharIndex
  ;    jr z,@transfer2Done
      
        ;=====
        ; look up character data
        ;=====
        
        ; B = bank
        ld a,(vwfTransferRight_leftShift)
        ld e,a
        ld d,$00
        ld hl,fontLeftShiftBankTbl
        add hl,de
        ld b,(hl)
        
        ; HL = pointer to char table base
        ld hl,fontLeftShiftPtrTbl
        ; pixel offset *= 2
        sla e
  ;      rl d     ; pointless, will never shift anything in
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ; add offset to actual char
        ld l,c
        ld h,$00
        ; * 32 for tile offset
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
  ;      .rept 5
  ;        sla e
  ;        rl d
  ;      .endr
        add hl,de
        
        ;=====
        ; copy to buffer
        ;=====
        
        ld de,vwfBuffer
  ;      ld a,b
        call copyToTileBuffer
        
        ; check if border needs to be added to tile
        call checkBorderTransfer
      
        ;=====
        ; send modified buffer
        ;=====
  ;      call sendVwfBuffer

        ; transfer only needed here for single-character print;
        ; string prints will handle terminating tile themselves
  /*      ld a,(stringIsPrinting)
        or a
        jr nz,+
          call sendVwfBuffer
        +:*/
        call sendVwfBuffer
      
      @transfer2Done:
      
      ;=====
      ; finish up
      ;=====
      
      @done:
      
        ;=====
        ; update last-printed data
        ;=====
        
        ld a,(printOffsetX)
        ld (lastPrintOffsetX),a
        ld a,(printOffsetY)
        ld (lastPrintOffsetY),a
        
;        ld a,(printBaseX)
;        ld (lastPrintBaseX),a
;        ld a,(printBaseY)
;        ld (lastPrintBaseY),a
      
      ret
    
    checkBorderTransfer:
      jp checkBorderTransfer_user
  
  ;========================================
  ; BC = print area w/h
  ; DE = base x/y position
  ;========================================
  initVwfString:
      ; set up print position
;      ld a,d
;      ld (printBaseX),a
;      ld a,e
;      ld (printBaseY),a

;      ld (printAreaWH),bc
      ld (printOffsetXY),de
      ld (lastPrintOffsetXY),de
;      xor a
;      ld (printOffsetX),a
;      ld (printOffsetY),a
;      ld (lastPrintOffsetX),a
;      ld (lastPrintOffsetY),a
      
      ; reset VWF
      jp resetVwf
;      ret
  
  ;========================================
  ; A = string banknum
  ; BC = print area w/h
  ; DE = base x/y position
  ; HL = string pointer (slot 1)
  ;========================================
  startVwfString:
    push af
      call initVwfString
    pop af
    ld b,a
  ; !!! drop through
  ;========================================
  ; B = string banknum
  ; HL = string pointer (slot 1)
  ;========================================
  printVwfString:
    jp printVwfString_user
    
  printScriptNum:
    ; get target number
    ld hl,(inlinePrintNum)
    ld a,(inlinePrintDigitCount)
    ld b,a
    ld a,(inlinePrintShowLeadingZeroes)
    ld c,a
    
    call prepNumberString
    
    ; print result
    ld hl,numberPrintBuffer
    jp printVwfString
    
/*  scriptNames:
    .incbin "out/script/dialogue_names.bin"
  
  printScriptName:
    ; index of name
    ld a,($C522)
    ; table of names
    ld hl,scriptNames
    
    call readOffsetTable
    jp printVwfString */
  
  numberPrintString:
    .db opInlineNumIndex
    .db terminatorIndex
  
  
    ;========================================
    ; convert a number to string encoding
    ; and place in numberPrintBuffer
    ;
    ; HL = number
    ; B = number of digits
    ;     0 = don't care, no space padding
    ; C = nonzero if leading zeroes
    ;     should be shown
    ;     (will be replaced with spaces if
    ;     nonzero)
    ;========================================
    prepNumberString:
      ; handle zero specially
      ld a,h
      or l
      jr nz,@numberIsNonzero
        @numberIsZero:
        
        ; if digit count iz zero, output string is "0"
        ld a,b
        or a
        ld a,$00+vwfDigitStartOffset
        jr nz,+
          ld (numberPrintBuffer+0),a
          ld a,terminatorIndex
          ld (numberPrintBuffer+1),a
          ret
        +:
        
        ; if digit count nonzero, fill with "0" or spaces (depending on C)
        ; to digit count
        
        ld a,c
        or a
        jr z,+
          ; C nonzero = show zeroes
          ld a,$00+vwfDigitStartOffset
          jr ++
        +:
          ; C zero = show spaces
          ld a,$00+vwfDigitSpaceOffset
        ++:
        
        ld de,numberPrintBuffer
        dec b
        jr z,+
        -:
          ld (de),a
          inc de
          djnz -
        +:
        ; final digit must be zero
        ld a,$00+vwfDigitStartOffset
        ld (de),a
        inc de
        ; write terminator
        ld a,terminatorIndex
        ld (de),a
        ret
      
      @numberIsNonzero:
      
      ;=====
      ; if number exceeds our capacity to display, show as a string of 9s
      ;=====
      
/*      ; >= 10000 is undisplayable
      push hl
        ld de,10000
        or a
        sbc hl,de
      pop hl
      jr c,+
        ld hl,9999
        jr @overflowChecksDone
      +: */
      
      ld a,b
      
      ; 10000
      cp $04
      jr nz,+
      push hl
        ld de,10000
        or a
        sbc hl,de
      pop hl
      jr c,++
        ld hl,9999
      ++:
      jr @overflowChecksDone
      +:
      
      ; 1000
      cp $03
      jr nz,+
      push hl
        ld de,1000
        or a
        sbc hl,de
      pop hl
      jr c,++
        ld hl,999
      ++:
      jr @overflowChecksDone
      +:
      
      ; 100
      cp $02
      jr nz,+
      push hl
        ld de,100
        or a
        sbc hl,de
      pop hl
      jr c,++
        ld hl,99
      ++:
      jr @overflowChecksDone
      +:
      
      ; 10
      cp $01
      jr nz,+
      push hl
        ld de,10
        or a
        sbc hl,de
      pop hl
      jr c,++
        ld hl,9
      ++:
;      jr @overflowChecksDone   ; not needed
      +:
      
      @overflowChecksDone:
      
      ;=====
      ; convert to BCD
      ;=====
      
      push bc
/*        call bcdConv4Digit
        ; B = thousands
        ; C = hundreds
        ; D = tens
        ; A = ones
        ld (numberConvBuffer+3),a
        ld a,d
        ld (numberConvBuffer+2),a
        ld a,c
        ld (numberConvBuffer+1),a
        ld a,b
        ld (numberConvBuffer+0),a */
        ex de,hl
        call bcdConv16Bit
      pop bc
      
      ;=====
      ; convert raw BCD to VWF
      ;=====
      
      ; save digit setting
      push bc
        ; convert raw BCD digits to VWF encoding
        ld hl,numberConvBuffer
        ld de,numberPrintBuffer
        ld b,maxPrintingDigits
        -:
          ld a,(hl)
          add a,vwfDigitStartOffset
          ld (de),a
          inc hl
          inc de
          djnz -
      pop bc
      
      ; if digit count is zero, remove leading zeroes
      ; (since we handled zero specially, there must be at least one
      ; nonzero digit. unless the number exceeded 9999 in which case we
      ; have other problems anyway.)
      ld a,b
      or a
      jr nz,+
        ; locate first nonzero digit
        ld hl,numberPrintBuffer
        ld b,maxPrintingDigits
        -:
          ld a,(hl)
          cp $00+vwfDigitStartOffset
          jr nz,++
            inc hl
            djnz -
        ++:
        
        @removeLeadingDigits:
        
        ; copy backward
        ld de,numberPrintBuffer
        -:
          ld a,(hl)
          ld (de),a
          inc hl
          inc de
          djnz -
        
        ; add terminator
        ld a,terminatorIndex
        ld (de),a
        
        ; nothing left to do (no leading zeroes)
        ret
      +:
      
      @checkLeadingZeroes:
      ; if C zero, leading zeroes should be replaced with spaces
      ld a,c
      or a
      jr nz,+
        ld hl,numberPrintBuffer
        -:
          ld a,(hl)
          cp $00+vwfDigitStartOffset
          jr nz,++
            ld a,vwfDigitSpaceOffset
            ld (hl),a
            inc hl
            jr -
        ++:
      +:
      
      @checkDigitCount:
      
      ; if digit limit exists, shift to match
      ; if limit equal to max digit count, we're done
      ld a,b
      or a
      cp maxPrintingDigits
      jr nz,+
        ld a,terminatorIndex
        ld (numberPrintBuffer+maxPrintingDigits),a
        ret
      +:
      
      ; otherwise, get pointer to start of content we want to print
      ; in HL
      ; subtract target number of digits from max
      ld a,maxPrintingDigits
      sub b
      ; add to base buffer address
      ld hl,numberPrintBuffer
      ld e,a
      ld d,$00
      add hl,de
      jr @removeLeadingDigits
    
    .ends
.endif


