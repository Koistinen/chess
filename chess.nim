# Copyright 2022-2023 Urban Koistinen - GNU Affero
import strutils
import std/unicode except split
#import std/bitops

proc square*(file, rank: int): int = file+8*rank
proc file2ch(file: int): char = "abcdefgh"[file]
proc rank2ch(rank:int): char = "12345678"[rank]
proc str2sq(s: string): int = square(s[0].ord-'a'.ord,s[1].ord-'1'.ord)
proc sq2file(sq: int): int = 7 and sq
proc sq2rank(sq: int): int = sq shr 3
proc sq2str* (sq: int): string =
  result.add(sq.sq2file.file2ch)
  result.add(sq.sq2rank.rank2ch)

# -6..6: ♚♛♜♝♞♟□♙♘♗♖♕♔
type Piece* = enum
  ♚ = -6, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕, ♔
proc isBlack*(pt: Piece): bool = pt < □
proc isWhite*(pt: Piece): bool = pt > □
type Side* = 0..1
const white* = 0
const black* = 1
type Square* = 0..63
type Pos* = object
  bd*: array[Square, Piece]
  g50: int
  side*: int
  ep: int
  castling: int

proc startingPos*: Pos =
  result.bd = [
    ♖,♘,♗,♕,♔,♗,♘,♖,
    ♙,♙,♙,♙,♙,♙,♙,♙,
    □,□,□,□,□,□,□,□,
    □,□,□,□,□,□,□,□,
    □,□,□,□,□,□,□,□,
    □,□,□,□,□,□,□,□,
    ♟,♟,♟,♟,♟,♟,♟,♟,
    ♜,♞,♝,♛,♚,♝,♞,♜]
  result.castling = 0xf
  
proc xside(p: Pos): int = 1 - p.side
  
proc castlingString(p: Pos): string =
  for i in 1..4:
    if 0 != (1 shl i and p.castling): result.add("KQkq"[i])
  if 0 == result.len: result = "-"

const fenPc*: array[-6..6, char] = ['k','q','r','b','n','p',' ','P','N','B','R','Q','K']

proc pieceChar(p: Pos, sq: int): char =
  fenPc[p.bd[sq].int]

proc pos2term*(p: Pos): string =
  for rank in countdown(7, 0):
    for file in 0..7:
      result.add(
        if 0 == (rank+file) mod 2: "\e[47m"
        else: "\e[49m")
      result.add ' '
      result.add(
        "♚♛♜♝♞♟ ♙♘♗♖♕♔".toRunes[
          6 + p.bd[square(file, rank)].int])
      result.add ' '
    result.add "\e[49m\n"

proc `$`*(p: Pos): string =
  for rank in countdown(7,0):
    for file in countup(0,7):
      var pc = p.bd[square(file, rank)]
      result.add(
        if □ == pc:
          [' ','-'][1 and (rank+file)]
        else:
          fenPc[pc.int])
    result.add('\n')
  result.add("g50: ")
  result.add($p.g50)
  result.add(" side: ")
  result.add($p.side)
  result.add(" ep: ")
  result.add(
    if 0 < p.ep: p.ep.sq2str
    else: "-")
  result.add(" castling: ")
  result.add(p.castlingString)

proc addPiece*(p: var Pos, piece: char, sq: int) =
  p.bd[sq] = (fenPc.find(piece)-6).Piece

proc addPiece*(p: var Pos, piece: Piece, sq: int) =
  p.bd[sq] = piece

proc p2fen*(p: Pos): string =
  for rank in countdown(7,0):
    var empty = 0
    for file in countup(0,7):
      if □ == p.bd[square(file,rank)]:
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
  result.add($p.g50)
  result.add(' ')
  result.add('0')

proc fen2p*(s: string): Pos =
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
    else:
      result.addPiece(c, square(file,rank))
      inc file
  if a[1] == "b":
    result.side = 1
  for c in a[2]:
    if '-' != c: result.castling = result.castling or 1 shl "KQkq".find(c)
  if "-" != a[3]: result.ep = str2sq(a[3])
  result.g50 = a[4].parseInt

type Move* = object
  fr: int
  to*: int
  flags: int
  promoted: int

proc move(fr, to: int): Move =
  result.fr = fr
  result.to = to
proc move(fr, to, flags: int): Move =
  result = move(fr,to)
  result.flags = flags

proc `$`*(mv: Move): string = result.add(
  if 6 == mv.flags : "O-O"
  elif 7 == mv.flags: "O-O-O"
  else:
    mv.fr.sq2str & mv.to.sq2str & (
      if mv.flags in 2..5: ["N", "B", "R", "Q"][mv.flags-2]
      elif 1 == mv.flags: " e.p."
      else: ""))

proc inbound(file, rank: int): bool = file in 0..7 and rank in 0..7
proc occupied*(p: Pos, sq: int): bool = □ != p.bd[sq]
proc ownPiece(p: Pos, sq: int): bool =
  if p.side == 0: □ < p.bd[sq]
  else: □ > p.bd[sq]
proc xPiece(p: Pos, sq: int): bool =
  if p.side != 0: □ < p.bd[sq]
  else: □ > p.bd[sq]
proc genMove(r: var seq[Move], p: Pos, fr, file, rank: int) =
  if inbound(file, rank):
    let to = square(file,rank)
    if not p.ownPiece(to): r.add(move(fr,to))
  
proc genSweep(r: var seq[Move], p: Pos, fr, dfile, drank: int) =
  var file = dfile + fr.sq2file
  var rank = drank + fr.sq2rank
  while inbound(file,rank) and not p.ownPiece(square(file, rank)):
    r.add(move(fr,square(file, rank)))
    if p.occupied(square(file, rank)): break
    file = file + dfile
    rank = rank + drank

proc genMoves(p: Pos): seq[Move] =
  for fr in 0..63:
    if p.ownPiece(fr):
      let file = fr.sq2file
      let rank = fr.sq2rank
      case p.bd[fr]
      of □: discard
      of ♘,♞:
        for s1 in [-1,1]:
          for s2 in [-1,1]:
            result.genMove(p, fr, file+2*s1, rank+s2)
            result.genMove(p, fr, file+s1, rank+2*s2)
      of ♝,♗:
        for dfile in [-1,1]:
          for drank in [-1,1]:
            result.genSweep(p, fr, dfile, drank)
      of ♜,♖:
        for s in [-1,1]:
          result.genSweep(p, fr, s, 0)
          result.genSweep(p, fr, 0, s)
      of ♛,♕:
        for s1 in -1..1:
          for s2 in -1..1:
            if 0 != (s1 or s2):
              result.genSweep(p, fr, s1, s2)
      of ♚,♔:
        for s1 in -1..1:
          for s2 in -1..1:
            if 0 != (s1 or s2):
              result.genMove(p, fr, file+s1, rank+s2)
        if 0 != (p.castling and (1 shl (2*p.side))) and
           □ == p.bd[fr+1] and
           □ == p.bd[fr+2]: result.add(move(fr,fr+2,14))
        if 0 != (p.castling and (2 shl (2*p.side))) and
           □ == p.bd[fr-1] and
           □ == p.bd[fr-2] and
           □ == p.bd[fr-3]: result.add(move(fr,fr-2,15))
      of ♟:
        if 1 == rank:
          if not p.occupied(fr-8):
            for prom in 2..5:
              result.add(move(fr, fr-8, prom))
          if file > 0 and p.xPiece(fr-9):
            for prom in 2..5:
              result.add(move(fr, fr-9, prom))
          if file < 7 and p.xPiece(fr-7):
            for prom in 2..5:
              result.add(move(fr, fr-7, prom))
        else:
          if not p.occupied(fr-8):
            result.add(move(fr, fr-8))
            if 6 == rank and not p.occupied(fr-16):
              result.add(move(fr, fr-16))
          if file > 0:
            if p.xPiece(fr-9): result.add(move(fr,fr-9))
          if file < 7:
            if p.xPiece(fr-7): result.add(move(fr, fr-7))
      of ♙:
        if 6 == rank:
          if not p.occupied(fr+8):
            for prom in 2..5:
              result.add(move(fr, fr+8, prom))
          if file > 0 and p.xPiece(fr+7):
            for prom in 2..5:
              result.add(move(fr, fr+7, prom))
          if file < 7 and p.xPiece(fr+9):
            for prom in 2..5:
              result.add(move(fr, fr+9, prom))
        else:
          if not p.occupied(fr+8):
            result.add(move(fr, fr+8))
            if 1 == rank and not p.occupied(fr+16):
              result.add(move(fr, fr-16))
          if file > 0:
            if p.xPiece(fr+7): result.add(move(fr, fr+7))
          if file < 7:
            if p.xPiece(fr+9): result.add(move(fr, fr+9))
  if p.ep > 0:
    if white == p.side:
      if 0 < p.ep.sq2file and ♙ == p.bd[p.ep-9]:
        result.add(move(p.ep-9, p.ep, 1))
      if 7 > p.ep.sq2file and ♙ == p.bd[p.ep-7]:
        result.add(move(p.ep-7, p.ep, 1))
    else:
      if 0 < p.ep.sq2file and ♟ == p.bd[p.ep+7]:
        result.add(move(p.ep+7, p.ep, 1))
      if 7 > p.ep.sq2file and ♟ == p.bd[p.ep+9]:
        result.add(move(p.ep+9, p.ep, 1))

proc isCapture*(p: Pos, mv: Move): bool =
  if p.bd[mv.to] != □:
    return true
  return 1 == mv.flags

proc makeMove*(p: var Pos, mv: Move) =
  p.ep = 0
  if p.bd[mv.fr] == [♙, ♟][p.side]:  
    p.g50 = 0
    if 0 == (8 and (mv.fr xor mv.to)):
      p.ep = (mv.fr+mv.to) shr 1
    elif 1 == mv.flags:
      p.bd[square(mv.to.sq2file, mv.fr.sq2rank)] = □
  elif p.bd[mv.to] != □:
    p.g50 = 0
  else: p.g50.inc
  p.bd[mv.to] = p.bd[mv.fr]
  p.bd[mv.fr] = □
  if mv.fr == square(4,0) or mv.to == square(4,0):
    p.castling = p.castling and not 3
  if mv.fr == square(7,0) or mv.to == square(7,0):
    p.castling = p.castling and not 1
  if mv.fr == square(0,0) or mv.to == square(0,0):
    p.castling = p.castling and not 2
  if mv.fr == square(4,7) or mv.to == square(4,7):
    p.castling = p.castling and not 12
  if mv.fr == square(7,7) or mv.to == square(7,7):
    p.castling = p.castling and not 4
  if mv.fr == square(0,7) or mv.to == square(0,7):
    p.castling = p.castling and not 8
  if mv.flags in 2..5:
    p.bd[mv.to] = (mv.flags*(2*p.side-1)).Piece
  if 6 == mv.flags:
    p.bd[mv.to-1] = p.bd[mv.to+1]
    p.bd[mv.to+1] = □
  if 7 == mv.flags:
    p.bd[mv.to+1] = p.bd[mv.to-2]
    p.bd[mv.to-2] = □
  p.side = p.xside

proc kingCapture*(p: Pos): bool =
  let sq = p.bd.find([♚, ♔][p.side])
  for mv in p.genMoves:
    if mv.to == sq: return true
  return false
    
proc inCheck*(p: Pos): bool =
  let sq = p.bd.find([♚, ♔][p.xside])
  var p2 = p
  p2.side = p2.xside
  for mv in p2.genMoves:
    if mv.to == sq: return true
  return false
    
proc genLegalMoves*(p: Pos): seq[Move] =
  for mv in p.genMoves:
    var p1 = p
    p1.makeMove(mv)
    if not p1.kingCapture:
      result.add(mv)

proc isCheckmate*(p: Pos): bool =
  if p.genLegalMoves.len > 0: return false
  return p.inCheck

proc isStalemate*(p: Pos): bool =
  if p.genLegalMoves.len > 0: return false
  return not p.inCheck
  
proc move2niceshortstr*(p: Pos, mv: Move): string =
  type MoveString = object
    mv: Move
    s: string
  proc moveString(mv: Move, s: string): MoveString =
    result.mv = mv
    result.s = s
  var msseq: seq[MoveString]
  for mv in p.genLegalMoves:
    let fr = mv.fr
    let to = mv.to
    let capt =
      if p.occupied(to) or 1 == mv.flags:
        "x"
      else:
        ""
    case p.bd[fr]
    of □: discard
    of ♚,♔:
      msseq.add(moveString(mv,"K" & capt & sq2str(to)))
      msseq.add(moveString(mv,"K" & sq2str(fr) & capt & sq2str(to)))
    of ♛,♕:
      msseq.add(moveString(mv,"Q" & capt & sq2str(to)))
      msseq.add(moveString(mv,"Q" & fr.sq2file.file2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"Q" & fr.sq2rank.rank2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"Q" & sq2str(fr) & capt & sq2str(to)))
    of ♜,♖:
      msseq.add(moveString(mv,"R" & capt & sq2str(to)))
      msseq.add(moveString(mv,"R" & fr.sq2file.file2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"R" & fr.sq2rank.rank2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"R" & sq2str(fr) & capt & sq2str(to)))
    of ♝,♗:
      msseq.add(moveString(mv,"B" & capt & sq2str(to)))
      msseq.add(moveString(mv,"B" & fr.sq2file.file2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"B" & fr.sq2rank.rank2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"B" & sq2str(fr) & capt & sq2str(to)))
    of ♘,♞:
      msseq.add(moveString(mv,"N" & capt & sq2str(to)))
      msseq.add(moveString(mv,"N" & fr.sq2file.file2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"N" & fr.sq2rank.rank2ch & capt & sq2str(to)))
      msseq.add(moveString(mv,"N" & sq2str(fr) & capt & sq2str(to)))
    of ♟, ♙:
      var pr: string = ""
      if mv.flags in 2..5:
        pr.add(fenPc[mv.flags-2])
      if "" == capt:
        msseq.add(moveString(mv, sq2str(to) & pr))
      else:
        msseq.add(moveString(mv, fr.sq2file.file2ch & capt & sq2str(to) & pr))
  for ms in msseq:
    if ms.mv == mv:
      var n: int
      for ms2 in msseq:
        if ms.s == ms2.s: n.inc
      if n == 1: return ms.s
  return "No unique move description found!(error)"
  
when isMainModule:
  var p = fen2p("///////k1KQ4 b - - 0")
  echo p
  echo "In check: ", p.incheck, " King Capure: ", p.kingCapture
  for mv in p.genLegalMoves:
    echo mv
