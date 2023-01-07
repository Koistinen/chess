# Copyright 2022 Urban Koistinen - GNU Affero
import strutils

type Square* = range[0..63]
proc square*(file, rank: int):Square = rank*8+file
proc rank*(sq: Square):int=sq.int shr 3
proc file*(sq: Square):int=sq.int and 7
proc sq2str* (sq: Square):string =
  result.add("abcdefgh"[sq.file])
  result.add("12345678"[sq.rank])
proc str2sq(s: string): Square = s[0].ord-'a'.ord+8*(s[1].ord-'1'.ord)
  
type BB* = uint64
proc bb* (sq: Square):Bb = 1u64 shl sq
proc bb2str* (b: Bb): string =
  for rank in countdown(7,0):
    if rank<7: result.add('\n')
    for file in countup(0,7):
      if 0 == (b.Bb and bb(square(file, rank))):
        result.add('-')
      else:
        result.add('+')

type Position* = object # 64 bytes
  so: array[0..1, BB]
  pawns, knights, bishops, rooks, queens: BB
  game50: uint16
  halfmoves: uint16
  kings: array[0..1, uint8]
  ep: uint8
  castling: uint8

proc oc(p: Position): BB = p.so[0] or p.so[1]
  
proc side*(p: Position): uint = 1 and p.halfmoves
  
proc castlingString(p: Position): string =
  if 0 == p.castling: result = "-"
  for i in countup(0,3):
    if 0 < (p.castling and (8u shr i)):
      result.add("KQkq"[i])
proc pieceChar(p: Position, sq: Square): char =
  result = 'k'
  let b = sq.bb
  if b == (b and p.knights): result = 'n'
  elif b == (b and p.bishops): result = 'b'
  elif b == (b and p.rooks): result = 'r'
  elif b == (b and p.queens): result = 'q'
  elif b == (b and p.pawns): result = 'p'
  if b == (b and p.so[0]):
    result = (result.ord - ' '.ord).char
      
proc `$`*(p: Position): string =
  var oc: BB = p.so[0] or p.so[1]
  for rank in countdown(7,0):
    for file in countup(0,7):
      var sq: BB = bb(square(file, rank))
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
  else: result.add("-")
  result.add(" castling: ")
  result.add(p.castlingString)

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
  var b: BB = bb(sq)
  var side: int = if isLowerAscii(piece): 1 else: 0
  result.so[side] = p.so[side] or b
  case piece.toLowerAscii
  of 'p': result.pawns = p.pawns or b
  of 'n': result.knights = p.knights or b
  of 'b': result.bishops = p.bishops or b
  of 'r': result.rooks = p.rooks or b
  of 'q': result.queens = p.queens or b
  of 'k':
    assert result.kings[side] == 64 # no previous king
    result.kings[side] = sq.uint8
  else: assert false
  
proc p2fen(p: Position): string =
  for rank in countdown(7,0):
    var empty = 0
    for file in countup(0,7):
      if 0 == (square(file,rank).bb and p.oc):
        empty.inc
      else:
        if empty > 0: result.add($empty)
        empty = 0
        result.add(p.pieceChar(square(file,rank)))
    if empty > 0: result.add($empty)
    if 0 < rank:
      result.add('/')
  result.add(' ')
  result.add("wb"[p.side])
  result.add(' ')
  result.add(p.castlingString)
  result.add(' ')
  if 0 == p.ep: result.add('-')
  else: result.add(p.ep.sq2str)
  result.add(' ')
  result.add($p.game50)
  result.add(' ')
  result.add($(p.halfmoves div 2))

proc fen2p(s: string): Position =
  result = emptyPosition()
  var a: seq[string] = split(s)
  var rank: int = 7
  var file: int = 0
  for c in a[0]:
    assert file < 8 or c == '/'
    case c
    of '/':
      dec rank
      file = 0
      assert rank >= 0
    of '1'..'8':
      inc(file, c.ord - '0'.ord)
    of 'k','K','q','Q','r','R','b','B','n','N','p','P':
      result = result.addPiece(c, square(file,rank))
      inc file
    else: assert false
  if a[1] == "b":
    result.halfmoves = 1
  else:
    assert "w" == a[1]
  for c in a[2]:
    case c
    of '-': result.castling = 0
    of 'K': result.castling = 8 or result.castling
    of 'Q': result.castling = 4 or result.castling
    of 'k': result.castling = 2 or result.castling
    of 'q': result.castling = 1 or result.castling
    else: assert false
  if "-" == a[3]: result.ep = 0
  else: result.ep = str2sq(a[3]).uint8
  result.game50 = a[4].parseInt.uint16
  result.halfmoves = result.halfmoves + 2*a[5].parseInt.uint16

proc startingPosition: Position =
  fen2p("rnbqkbnr/pppppppp/////PPPPPPPP/RNBQKBNR w KQkq - 0 0")

type Move* = object
  fr: uint8 # 64..127 promotion, 128..191 ep, 192..256 castling
  to: uint8 # high 2 bits say promotion piece in case of promotion

proc isPromotion(mv: Move):bool = 64 <= mv.fr and mv.fr <= 127

when isMainModule:
  echo (bb(square(0,1)) or bb(square(2,2))).bb2str
  echo square(0,1).sq2str
  echo square(2,2).sq2str
  var mv: Move
  mv.fr = 12
  mv.to = 28
  echo isPromotion(mv)
  var p = startingPosition()
  echo p
  echo p.p2fen
  p = fen2p("8/p7/1P6/1r3p1k/7P/3R1KP1/8/8 b - - 0 0")
  echo "8/p7/1P6/1r3p1k/7P/3R1KP1/8/8 b - - 0 0"
  echo p
  echo p.p2fen
