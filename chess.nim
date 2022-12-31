# Copyright 2022 Urban Koistinen - GNU Affero
import strutils

type Square* = range[0..63]
proc square*(rank, file: int):Square = rank*8+file
proc rank*(sq: Square):int=sq shr 3
proc file*(sq: Square):int=sq and 7
proc `$`* (sq: Square):string =
  result.add("abcdefgh"[sq.file])
  result.add("12345678"[sq.rank])

type Bitboard* = uint64
proc bitboard* (sq: Square):Bitboard = 1u shl sq
proc `$`* (bb: Bitboard): string =
  for rank in countdown(7,0):
    if rank<7: result.add('\n')
    for file in countup(0,7):
      if 0 == (bb and bitboard(square(rank, file))):
        result.add('-')
      else:
        result.add('+')

type Position* = object # 8*8 bytes
  so: array[0..1, Bitboard]
  pawns, knights, bishops, rooks, queens: Bitboard
  game50: uint16
  halfmoves: uint16
  kings: array[0..1, uint8]
  ep: uint8
  castling: uint8

proc addPiece*(p: Position, piece: char, sq: Square): Position =
  var bb: Bitboard = bitboard(sq)
  var side: int = if isLowerAscii(piece): 1 else: 0
  result = p
  result.so[side] = p.so[side] or bb
  case piece.toLowerAscii
  of 'p': result.pawns = p.pawns or bb
  of 'n': result.knights = p.knights or bb
  of 'b': result.bishops = p.bishops or bb
  of 'r': result.rooks = p.rooks or bb
  of 'q': result.queens = p.queens or bb
  of 'k': result.kings[side] = sq.uint8
  else: assert false

type Move* = object
  fr: uint8 # 64..127 promotion, 128..191 ep, 192..256 castling
  to: uint8 # high 2 bits say promotion piece in case of promotion

proc isPromotion(mv: Move):bool = 64 <= mv.fr and mv.fr <= 127

  
when isMainModule:
  echo bitboard(square(0,1)) or bitboard(square(2,2))
  echo square(0,1)
  echo square(2,2)
  var mv: Move
  mv.fr = 12
  mv.to = 28
  echo isPromotion(mv)
  
