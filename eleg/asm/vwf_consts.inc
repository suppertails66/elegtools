 
;=====
; vwf settings
;=====

; maximum number of digits that can be printed
.define maxPrintingDigits 5

.define vwfWindowRBorderIndex $1A
;  .define controlCodeStartIndex $F0
.define controlCodeStartIndex $F0
.define controlCodeLimitIndex $FF
.define vwfTileBrIndex $F0
.define opNumIndex $F8
.define opNameIndex $F9
.define opInlineNumIndex $FA
.define vwfBoxClearIndex $FD
.define vwfWaitIndex $FE
.define vwfBrIndex $FF
.define terminatorIndex $00

.define maxVwfTiles $B8

.define vwfDigitStartOffset $07
.define vwfDigitSpaceOffset $1F

.define opTerminator $FE

;=====
; new ops
;=====

.define opTextShortJump $ED
.define opTextWaitEndJump $EE
.define opTextEndJump $EF
.define opTileBr $F0
.define opTextJump $F1

.define spaceOpsStart $C0

;=====
; game stuff
;=====

.define textTileEnd $B8
.define textNumbersStart $76

.define numConversionBuffer $C393
;.define screenTilemapBuffer $C930
.define screenTilemapBufferVisible $C949
.define screenTilemapBufferW 24
;.define screenTilemapBufferH 
.define screenTilemapBufferVisibleH 18

.define forceEncountersOffFlag $C2BF

.define textSpeed $C399

.define origPrintXY $C390
  .define origPrintX $C390
  .define origPrintY $C391
.define windowHalfSizeFlag $C3A8

.define runTextScript $2C83
.define printCbcChar $2ECD
.define charToTilemapBuffer $2EF3
.define yxCoordsToVisibleScreenBuf $4AE2

;=====
; misc
;=====

.define vwfTileQueueExpMemAccessByte $0C
.define emptyBgTile $00
.define windowBgTile $6D
  
; base tile at which vwf tiles are initially allocated
.define vwfTileBase_main $0001
; one past the last index of assignable vwf tiles
;.define vwfTileSize_main $00B8-vwfTileBase_main
.define vwfTileSize_main $00B8-vwfTileBase_main
; if nonzero, assume nametable scroll is zero regardless of actual value
.define vwfScrollZeroFlag_main $00
; high byte for nametable prints
.define vwfNametableHighMask_main $00

;  .define screenVisibleW 20
;  .define screenVisibleH 18
;  .define screenVisibleX 3
;  .define screenVisibleY 2
.define screenVisibleW 20
.define screenVisibleH 18
.define screenVisibleX 6
.define screenVisibleY 3

.define ramBankIdentifier $FE
.define noBankIdentifier $FF
.define newStringSentinel $80


