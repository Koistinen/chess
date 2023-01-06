# Copyright 2022 Urban Koistinen - GNU Affero
import strutils

type Square* = range[0..63]
proc square*(file, rank: int):Square = rank*8+file
proc rank*(sq: Square):int=sq.int shr 3
proc file*(sq: Square):int=sq.int and 7
proc sq2str* (sq: Square):string =
  result.add("abcdefgh"[sq.file])
  result.add("12345678"[sq.rank])

type Bitboard* = uint64
proc bitboard* (sq: Square):Bitboard = 1u64 shl sq
proc bb2str* (bb: Bitboard): string =
  for rank in countdown(7,0):
    if rank<7: result.add('\n')
    for file in countup(0,7):
      if 0 == (bb.Bitboard and bitboard(square(file, rank))):
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

proc `$`*(p: Position): string =
  var oc: Bitboard = p.so[0] or p.so[1]
  for rank in countdown(7,0):
    for file in countup(0,7):
      var sq: Bitboard = bitboard(square(file, rank))
      if 0 == (oc and sq):
        result.add(if 1 == (1 and (rank+file)): '-' else: ' ')
      else:
        var pieceChar: char = 'k'
        if sq == (sq and p.knights): pieceChar = 'n'
        elif sq == (sq and p.bishops): pieceChar = 'b'
        elif sq == (sq and p.rooks): pieceChar = 'r'
        elif sq == (sq and p.queens): pieceChar = 'q'
        elif sq == (sq and p.pawns): pieceChar = 'p'
        if sq == (sq and p.so[0]):
          pieceChar = (pieceChar.int - ' '.int).char
        result.add(pieceChar)
    result.add('\n')
  result.add("game50: ")
  result.add($p.game50)
  result.add(" halfmoves: ")
  result.add($p.halfmoves)
  result.add(" epsquare: ")
  if 0 < p.ep: result.add(p.ep.sq2str)
  else: result.add("no")
  result.add(" castling: ")
  result.add(p.castling.BiggestInt.toBin(4))

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
  result.castling = 0xf
  
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
  var fenArgs: string = s
  var rank: int = 7
  var file: int = 0
  for c in fenArgs[0]:
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
  echo (bitboard(square(0,1)) or bitboard(square(2,2))).bb2str
  echo square(0,1).sq2str
  echo square(2,2).sq2str
  var mv: Move
  mv.fr = 12
  mv.to = 28
  echo isPromotion(mv)
  var p = startingPosition()
  echo p
  p = fen("8/p7/1P6/1r3p1k/7P/3R1KP1/8/8") # b - - 0 0
  echo "8/p7/1P6/1r3p1k/7P/3R1KP1/8/8 b - - 0 0"
  echo p
