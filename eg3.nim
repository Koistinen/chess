# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams
import std/bitops
import std/unicode

#  bz50[n+1] =
#    1 if every move leads to wz50[n][to_i]
#      and at least one move leads to wz50[n]-wz50[n-1]
#    0 else
#    
#  wz50[n+1] =
#    1 if any move leads to bz50[n]
#    wz50[n] else
#    
#  bz50[0] =
#    1 if checkmate
#      or one black piece has been captured and white win
#        (lookup in subtable)
#    0 else
#      
#  wz50[0] =
#    1 if one white piece has been captured and white win
#      (lookup in subtable)
#    wz50[-1] else
#    
#  wz50[-1] =
#    1 if illegal even if considering possibility of
#        one white piece having been captured
#    0 else
#
#  only look at moves from legal positions

type BitSeq = object
  size: int
  s: seq[uint64]

proc newBitSeq(size: int): BitSeq =
  result.size = size
  result.s = newSeq[uint64]((size+63) div 64)
  
proc `[]=`(bs: var BitSeq, index: int, val: bool) =
  assert index in 0..<bs.size
  if val:
    bs.s[index div 64].setBit(index mod 64)
  else:
    bs.s[index div 64].clearBit(index mod 64)

proc `[]`(bs: BitSeq, index: int): bool =
  assert index in 0..<bs.size
  return bs.s[index div 64].testBit(index mod 64)

const endgame = "♔♖♚"

type PieceIndex = object
  pt: Piece
  length: int
  bits: int
  sq: Square

proc pieceIndexSeq(eg: string): seq[PieceIndex] =
  for rune in eg.toRunes:
    var pi: PieceIndex
    pi.pt = ("♚♛♜♝♞♟□♙♘♗♖♕♔".toRunes.find(rune)-6).Piece
    pi.length = 6
    result.add(pi)
# optimization left for later, accept 4 times worse now
#  result[0].length = 4

proc totalLength(pis: seq[PieceIndex]): int =
  for pi in pis:
    result.inc(pi.length)

var pis = pieceIndexSeq(endgame)
proc size(pis: seq[PieceIndex]): int =
  1 shl pis.totalLength

# Candidates for PDEP/PEXT
proc depositBits(msk, source: int): int =
  var b=0
  var m=msk
  while m != 0:
    if source.testBit(b):
      result.setMask(msk.and -msk)
    m.mask(m - 1)
    inc b
 
proc extractBits(msk, source: int): int =
  var b=0
  var m=msk
  while m != 0:
    if 0 != source.and m.and -m:
      result.setBit b
    m.mask(m - 1)
    inc b

proc setMasks(pis: var seq[PieceIndex]) =
  var w, b = 0
  for i, pi in pis:
    pis[i].bits = 63 shl (6*i)
    

proc index(pis: seq[PieceIndex]): int =
  for pi in pis:
    result += pi.bits.depositBits pi.sq

proc set(pis: var seq[PieceIndex], i: int) =
  for i, pi in pis:
    pis[i].sq = extractBits(pi.bits, i)
    

var b🛇 = newBitSeq(pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var w, b = 0
  var p: Pos
  for pi in pis:
    if p.occupied(pi.sq):
      if pi.pt.isBlack: discard
      elif p.bd[pi.sq].isWhite: discard
      else:
        p.addPiece(pi.pt, pi.sq)
        inc w
    else:
      p.addPiece(pi.pt, pi.sq)
      if p.bd[pi.sq].isWhite:
        inc w
      else:
        inc b
  p.side = black
  if w+b == pis.len:
    b🛇[i] = p.kingCapture
      
var f = newFileStream(endgame & ".eg3", fmWrite)
if not f.isNil:
  f.write b🛇
else:
  echo "Error creating file."
f.flush
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
