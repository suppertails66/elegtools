
.enum $C500
  vwfAllocationArray    ds maxVwfTiles  ; bytes in this array are nonzero if
                                        ; the corresponding tile has been
                                        ; allocated for display
.ende

.enum $C480
  vwfBuffer             ds bytesPerTile ; tiles are composed here before going
                                        ; to the VDP
  vwfAllocationArraySize db             ; number of currently used VWF tiles
                                        ; out of the maximum
  vwfAllocationArrayPos db              ; most recently assigned index in
                                        ; the VWF alloc array
  vwfAllocationArrayBaseTile .dw         ; base tile index the vwf alloc array is
                                        ; targeting
    vwfAllocationArrayBaseTileLo db
    vwfAllocationArrayBaseTileHi db
  vwfFullDeallocFlag    db
  assumeScrollZeroFlag  db              ; when set, assume nametable scroll is
                                        ; zero for purpose of computing
                                        ; screen-local coordinates
  noInterruptDisableFlag db
  
  vwfBufferPending      db              ; nonzero if buffer not empty and
                                        ; not flushed
  vwfBufferAllocatedTile .dw             ; index of currently allocated
                                        ; buffer tile (zero if none)
    vwfBufferAllocatedTileLo db
    vwfBufferAllocatedTileHi db
  vwfPixelOffset        db              ; currently target pixel position in
                                        ; VWF buffer
  vwfTransferCharSize   db
  vwfTransferRight_leftShift    db
  
  vwfNametableHighMask      db          ; OR mask applied to high byte of
                                        ; VWF nametable output
  
  vwfLocalTargetFlag        db          ; if true, print nametable data to RAM
                                        ; rather than directly to VDP
    vwfLocalTargetBaseAddr      dw      ; base address of local nametable
                                        ; target (RAM address of nametable data
                                        ; for upper-left character in printable
                                        ; area)
    vwfLocalTargetW  db                 ; width in tiles of one line in the
                                        ; local nametable target, for
                                        ; linebreak calculations
    vwfLocalTargetH  db                 ; height in tiles of the
                                        ; local nametable target,
                                        ; for garbage collection checks
    vwfLocalTargetCurrLineAddr      dw    ; address of current target line
                                          ; during printing
  
;  printBaseXY           .dw
;    printBaseY            db
;    printBaseX            db
  printOffsetXY         .dw
    printOffsetY          db
    printOffsetX          db
;  printAreaWH           .dw
;    printAreaH            db
;    printAreaW            db
  
  scratch               .dw
    scratchLo             db
    scratchHi             db
  
  bankedCallA           db
  bankedCallHL          dw
  
  inlinePrintNum        dw      ; number printed when an inline_num op
                                ; is encountered
  inlinePrintDigitCount db      ; number of digits in inline print
                                ; (00 = don't care)
  inlinePrintShowLeadingZeroes db
  
  numberPrintBuffer     ds 8    ; buffer for printing script-inline numbers
  numberConvBuffer      ds maxPrintingDigits    ; buffer for temp BCD conversion storage
  
  lastPrintOffsetXY     .dw
    lastPrintOffsetY      db
    lastPrintOffsetX      db
  lastPrintBaseXY       .dw
    lastPrintBaseY        db
    lastPrintBaseX        db
  
;  lastPrintSrcPtr       dw
;  lastPrintSrcBank      db
  curPrintSrcBank       db      ; bank the current string is stored in
  
  waitIndicatorBgTile   dw      ; nametable identifier of the tile we
                                ; will cover up with our new wait indicator.
                                ; in the original game, the wait indicator
                                ; is displayed in the text area itself,
                                ; but we're putting it a line lower (on
                                ; what should be the bottom border of the
                                ; box in all cases where this matters)
                                ; and have to keep track of this.
  
  textScrollTablePointer dw
  textScrollDstTile db
  
  scratchB               .dw
    scratchBLo             db
    scratchBHi             db
  
  nametableCompositionBuffer    ds $90  ; for credits
  nametableCompositionBufferEnd .db
.ende




; expansion memory second page

.define maxVwfTileQueueSize $F0

.struct VwfTileQueueEntry
;  queued        db
  tileData      ds 32
  ; pad to 64 bytes
;  padding       ds 31
.endst

.enum $8000
  vwfTileQueueData      ds maxVwfTileQueueSize
  vwfTileQueueEntries INSTANCEOF VwfTileQueueEntry maxVwfTileQueueSize
  vwfTileQueueSize      db
.ende

.enum $A000
  ; set byte in this map if tile is in queue
  vwfTileUsedData      ds maxVwfTileQueueSize
.ende

.enum $A100
  vwfVisibleAllocationArray      ds maxVwfTiles
.ende


