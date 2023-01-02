# Copyright 2022 Urban Koistinen - GNU Affero
import strutils

type Square* = range[0..63]
proc square*(file, rank: int):Square = rank*8+file
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
      if 0 == (bb and bitboard(square(file, rank))):
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

proc emptyPosition: Position =
  result.so[0] = 0
  result.so[1] = 0
  result.pawns = 0
  result.knights = 0
  result.bishops = 0
  result.rooks = 0
  result.queens = 0
  result.game50 = 0
  result.halfmoves = 0
  result.kings[0] = 64 # missing white king is illegal position
  result.kings[1] = 64 # missing black king is illegal position
  result.ep = 0
  result.castling = 0
  
proc addPiece*(p: Position, piece: char, sq: Square): Position =
  result = p
  var bb: Bitboard = bitboard(sq)
  var side: int = if isLowerAscii(piece): 1 else: 0
  result.so[side] = p.so[side] or bb
  case piece.toLowerAscii
  of 'p': result.pawns = p.pawns or bb
  of 'n': result.knights = p.knights or bb
  of 'b': result.bishops = p.bishops or bb
  of 'r': result.rooks = p.rooks or bb
  of 'q': result.queens = p.queens or bb
  of 'k':
    assert result.kings[side] == 64 # no previous king
    result.kings[side] = sq.uint8
  else: assert false
  

proc fen(s: string): Position =
  result = emptyPosition()
  var board: string = s
  var rank: int = 7
  var file: int = 0
  for c in board:
    assert file < 8 or c == '/'
    case c
    of '/':
      dec rank
      file = 0
      assert rank >= 0
    of '1'..'8':
      inc(file, c.ord - '0'.ord)
    of 'k','K','q','Q','r','R','b','B','n','N','p','P':
      result = result.addPiece(c, square(file, rank))
      inc file
    else: assert false

proc startingPosition: Position =
  fen("rnbqkbnr/pppppppp/////PPPPPPPP/RNBQKBNR")
      
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
  var p = startingPosition()
  echo "white pieces:"
  echo p.so[0]
  echo "black pieces:"
  echo p.so[1]
  echo "pawns:"
  echo p.pawns
  echo "queens:"
  echo p.queens
  echo "rooks:"
  echo p.rooks
  echo "bishops:"
  echo p.bishops
  echo "bishops:"
  echo p.bishops
  echo "knights:"
  echo p.knights
  echo "kings: ", p.kings[0].Square, ", ", p.kings[1].Square
  p = fen("8/p7/1P6/1r3p1k/7P/3R1KP1/8/8") # b - - 0 0
  echo "8/p7/1P6/1r3p1k/7P/3R1KP1/8/8 b - - 0 0"
  echo "white pieces:"
  echo p.so[0]
  echo "black pieces:"
  echo p.so[1]
  echo "pawns:"
  echo p.pawns
  echo "queens:"
  echo p.queens
  echo "rooks:"
  echo p.rooks
  echo "bishops:"
  echo p.bishops
  echo "bishops:"
  echo p.bishops
  echo "knights:"
  echo p.knights
