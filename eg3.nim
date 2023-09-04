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
  # same order of bits independent of order of pis
  var k = 0
  for pt in Piece:
    for i, pi in pis:
      if pi.pt == pt:
        pis[i].bits = 63 shl (6*k)
        inc k

proc index(pis: seq[PieceIndex]): int =
  for pi in pis:
    result += pi.bits.depositBits pi.sq
    
proc index(p: Pos): int =
  var pis: seq[PieceIndex]
  for sq in 0..63:
    if p.bd[sq] != □:
      var pi: PieceIndex
      pi.sq = sq
      pi.pt = p.bd[sq]
      pis.add pi
  setMasks(pis)
  result = pis.index
    
proc set(pis: var seq[PieceIndex], i: int) =
  for i, pi in pis:
    pis[i].sq = extractBits(pi.bits, i)

proc lookup(p: Pos): bool =
  false # fake lookup, works for ♔♕♚ and ♔♖♚

var b🛇 = newSeq[bool](pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var captured = 0
  var illegal = false
  var p: Pos
  # place white pieces
  for pi in pis:
    if pi.pt.isWhite:
      if p.occupied(pi.sq): illegal = true
      else: p.addPiece(pi.pt, pi.sq)
  # place black pieces
  for pi in pis:
    if pi.pt.isBlack:
      if p.occupied(pi.sq):
        if pi.pt == ♚: illegal = true
        else: inc captured
      else: p.addPiece(pi.pt, pi.sq)
  p.side = black
  if not illegal:
    illegal = p.kingCapture
  b🛇[i] = illegal
    
var bz50 = newSeq[seq[bool]](101)
var wz50 = newSeq[seq[bool]](101)
bz50[0] = newSeq[bool](pis.size)
for i in 0..<pis.size:
  pis.set(i)
  var captured = 0
  var illegal = false
  var p: Pos
  # place white pieces
  for pi in pis:
    if pi.pt.isWhite:
      if p.occupied(pi.sq): illegal = true
      else: p.addPiece(pi.pt, pi.sq)
  # place black pieces
  for pi in pis:
    if pi.pt.isBlack:
      if p.occupied(pi.sq):
        if pi.pt == ♚: illegal = true
        else: inc captured
      else: p.addPiece(pi.pt, pi.sq)
  p.side = black
  bz50[0][i] =
    if illegal: false
    elif captured == 0: p.isCheckmate
    elif captured == 1: p.lookup
    else: false

wz50[0] = newSeq[bool](pis.size)
for i in 0..<pis.size:
  var captured = 0
  var illegal = false
  var p: Pos
  # place black pieces
  for pi in pis:
    if pi.pt.isBlack:
      if p.occupied(pi.sq): illegal = true
      else: p.addPiece(pi.pt, pi.sq)
  # place white pieces
  for pi in pis:
    if pi.pt.isWhite:
      if p.occupied(pi.sq):
        if pi.pt == ♔: illegal = true
        else: inc captured
      else: p.addPiece(pi.pt, pi.sq)
  p.side = white
  wz50[0][i] =
    if illegal: true
    elif captured == 0: p.kingCapture
    elif captured == 1: p.kingCapture or p.lookup
    else: true

for ply in 1..100:
  bz50[ply] = newSeq[bool](pis.size)
  for i in 0..<pis.size:
    pis.set(i)
    var captured = 0
    var illegal = false
    var p: Pos
    # place white pieces
    for pi in pis:
      if pi.pt.isWhite:
        if p.occupied(pi.sq): illegal = true
        else: p.addPiece(pi.pt, pi.sq)
    # place black pieces
    for pi in pis:
      if pi.pt.isBlack:
        if p.occupied(pi.sq):
          if pi.pt == ♚: illegal = true
          else: inc captured
        else: p.addPiece(pi.pt, pi.sq)
    p.side = black
    bz50[ply][i] =
      # loss if one and all legal move lead to loss
      if illegal: false
      elif captured == 0:
        var moves = p.genLegalMoves
        var loss = true
        for mv in moves:
          var p2 = p
          p2.makeMove mv
          if not wz50[ply-1][p2.index]:
            loss = false
        if moves.len == 0:
          loss = false
        loss
      else: false
  
  wz50[ply] = newSeq[bool](pis.size)
  for i in 0..<pis.size:
    var captured = 0
    var illegal = false
    var p: Pos
    # place black pieces
    for pi in pis:
      if pi.pt.isBlack:
        if p.occupied(pi.sq): illegal = true
        else: p.addPiece(pi.pt, pi.sq)
    # place white pieces
    for pi in pis:
      if pi.pt.isWhite:
        if p.occupied(pi.sq):
          if pi.pt == ♔: illegal = true
          else: inc captured
        else: p.addPiece(pi.pt, pi.sq)
    p.side = white
    wz50[ply][i] =
      if illegal: false
      elif captured == 0:
        var moves = p.genLegalMoves
        var win = false
        for mv in moves:
          var p2 = p
          p2.makeMove mv
          if bz50[ply-1][p2.index]:
            win = true
        win
      else: false
  
var f = newFileStream(endgame & ".eg3", fmWrite)
if not f.isNil:
  f.write b🛇
  for ply in 0..100:
    f.write bz50[ply]
    f.write wz50[ply]
else:
  echo "Error creating file."
f.flush
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
