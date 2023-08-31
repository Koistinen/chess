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
#  bz50[-1] =
#    1 if illegal even if considering possibility of
#        black pieces having been captured
#    0 else
#
#  only look at moves from legal positions

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
    result.inc pi.length

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

var b🛇 = newSeq[bool](pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var w, b = 0
  var p: Pos
  for pi in pis:
    var illegal = false
    if p.occupied(pi.sq):
      if pi.pt.isBlack: discard
      elif p.bd[pi.sq].isWhite: discard
      elif p.bd[pi.sq] == ♚: illegal = true
      else:
        p.addPiece(pi.pt, pi.sq)
        inc w
        dec b
    else:
      p.addPiece(pi.pt, pi.sq)
      if pi.pt.isWhite:
        inc w
      else:
        inc b
  p.side = black
  if not illegal:
    illegal = p.kingCapture
  b🛇[i] = illegal
    
var bz50 = newSeq[seq[bool]](101)
var wz50 = newSeq[seq[bool]](101)
bz50[0] = newSeq[bool](pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var w, b = 0
  var illegal = false
  var p: Pos
  for pi in pis:
    if p.occupied(pi.sq):
      if pi.pt.isBlack:
        if p.bd[pi.sq].isBlack: illegal = true
      elif p.bd[pi.sq] == ♚: illegal = true
      elif p.bd[pi.sq].isWhite:
        if pi.pt.isWhite: illegal = true
      else:
        p.addPiece(pi.pt, pi.sq)
        inc w
    else:
      p.addPiece(pi.pt, pi.sq)
      if pi.pt.isWhite:
        inc w
      else:
        inc b
  p.side = black
  if w+b == pis.len:
    bz50[0][i] = p.isCheckmate
  elif not illegal:
    bz50[0][i] = p.lookup

wz50[0] = newSeq[bool](pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var w, b = 0
  var illegal = false
  var p: Pos
  for pi in pis:
    if p.occupied(pi.sq):
      if pi.pt.isWhite:
        if p.bd[pi.sq].isWhite: illegal = true
      elif p.bd[pi.sq].isBlack:
        if pi.pt.isBlack: illegal = true
      else:
        p.addPiece(pi.pt, pi.sq)
        inc b
        dec w
    else:
      p.addPiece(pi.pt, pi.sq)
      if pi.pt.isWhite:
        inc w
      else:
        inc b
  p.side = white
  if w+b == pis.len:
    wz50[0][i] = p.kingCapture # for pseudolegal
  elif illegal:
    wz50[0][i] = true
  else:
    wz50[0][i] = p.lookup

var f = newFileStream(endgame & ".eg3", fmWrite)
if not f.isNil:
  f.write b🛇
else:
  echo "Error creating file."
f.flush
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
