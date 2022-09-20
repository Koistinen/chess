# Copyright 2022 Urban Koistinen - GNU Affero
type Square* = range[0..63]
proc square*(rank, file: int):Square = rank*8+file
proc rank*(sq: Square):int=sq shr 3
proc file*(sq: Square):int=sq and 7
proc `$`* (sq: Square):string =
  result.add("abcdefgh"[sq.file])
  result.add("12345678"[sq.rank])

type Bitboard* = int64
proc bitboard* (sq: Square):Bitboard = 1 shl sq
proc `$`* (bb: Bitboard): string =
  for rank in countdown(7,0):
    if rank<7: result.add('\n')
    for file in countup(0,7):
      if 0 == (bb and bitboard(square(rank, file))):
        result.add('-')
      else:
        result.add('+')

type Position* = object # 8*8 bytes
  white, black, pawn, knight, bishop, rook, queen: Bitboard
  game50: uint32 # least significant bit is side to move
  king: array[0..1, uint8]
  ep: uint8
  castling: uint8

type Move* = object
  fr: uint8 # 64..127 promotion, 128..191 ep, 192..256 castling
  to: uint8 # high 2 bits say promotion piece in case of promotion

when isMainModule:
  echo bitboard(square(0,1)) or bitboard(square(2,2))
  echo square(0,1)
  echo square(2,2)
