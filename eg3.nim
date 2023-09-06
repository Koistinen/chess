# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams
import std/bitops
import std/unicode
import system
import std/strutils

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
proc depositBits(msk, source: int, debug=false): int =
  if debug: echo "depositBits: ", source.toOct(2)
  var b=0
  var m=msk
  while m != 0:
    if source.testBit(b):
      if debug: echo "depositBits: b = ", b
      result.setMask(m.and -m)
    if debug:
      echo "depositBits: ", result.toOct(6)," ", m.toOct(6)
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

proc index(pis: seq[PieceIndex], debug=false): int =
  for pi in pis:
    if debug:
      echo "index: ", pi.bits.toOct(6), ", ", pi.sq.sq2str
    result += pi.bits.depositBits(pi.sq)
    

proc pis2str(pis: seq[PieceIndex]): string =
  let pieceRunes = "♚♛♜♝♞♟□♙♘♗♖♕♔".toRunes
  for pi in pis:
    result.add pieceRunes[pi.pt.int+6]
    result.add pi.sq.sq2str
    result.add ' '

proc index(p: Pos, debug=false): int =
  var pis: seq[PieceIndex]
  for sq in 0..63:
    if p.bd[sq] != □:
      var pi: PieceIndex
      pi.sq = sq
      pi.pt = p.bd[sq]
      pis.add pi
  setMasks(pis)
  if debug: echo "indexing Pos: ", pis.pis2str
  result = pis.index(debug)

proc set(pis: var seq[PieceIndex], i: int) =
  for k, pi in pis:
    pis[k].sq = extractBits(pi.bits, i)

# fake lookup, works for ♔♕♚ and ♔♖♚
proc lookup(p: Pos): bool =
  if p.side == white: p.kingCapture
  else: false

pis.setMasks

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
#  echo p
  if not illegal:
    illegal = p.kingCapture
  b🛇[i] = illegal
  
# bz50 has only lowest possible ply set true if loss
# false for illegal
# true at ply = 0 if single black piece captured and loss
var bz50 = newSeq[seq[bool]](101)

# wz50 has all possible ply set true if win
# true for illegal
# false if single white piece captured and not win
var wz50 = newSeq[seq[bool]](101)

var wCount: array[0..100, int]
var bCount: array[0..100, int]

proc computeBlack0(i: int) =
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
    elif p.kingCapture: false
    elif captured == 0:
      if p.isCheckmate:
        inc bCount[0]
        echo bCount[0]
        echo p.pos2term
        true
      else: false
    elif captured == 1: p.lookup
    else: false

bz50[0] = newSeq[bool](pis.size)
var f = newFileStream(endgame & ".b0", fmRead)
if not f.isNil:
  for i, b in bz50[0]:
    f.read bz50[0][i]
else:
  for i in 0..<pis.size:
    computeBlack0(i)
  f = newFileStream(endgame & ".b0", fmWrite)
  if not f.isNil:
    for b in bz50[0]:
      f.write b
    f.flush

proc computeWhite0(i: int, debug = false) =
  var captured = 0
  var illegal = false
  var p: Pos
  pis.set(i)
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
  if debug:
    echo "computeWhite"
    if not illegal:
      echo p.pos2term
  wz50[0][i] =
    if illegal: true
    elif captured == 0: p.kingCapture
    elif captured == 1: p.lookup
    else: true

wz50[0] = newSeq[bool](pis.size)
f = newFileStream(endgame & ".w0", fmRead)
if not f.isNil:
  for i, b in bz50[0]:
    f.read wz50[0][i]
else:
  for i in 0..<pis.size:
    computeWhite0(i)
  f = newFileStream(endgame & ".w0", fmWrite)
  if not f.isNil:
    for b in wz50[0]:
      f.write b
    f.flush

proc compute(ply, i: int, debug=false) =
  pis.set(i)
  var captured = 0
  var illegal = false
  var p = newPos(black)
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
  if debug:
    echo pis.pis2str
    echo p.pos2term
  if not illegal:
    illegal = p.kingCapture
  bz50[ply][i] =
    # loss if one and all legal move lead to loss
    if illegal: false
    elif captured == 0:
      var moves = p.genLegalMoves
      var loss = true
      var newLoss = false
      for mv in moves:
        var p2 = p
        p2.makeMove mv
        if debug: echo p2.index(true).toOct(6)
        if debug: echo p2.pos2term, wz50[ply-1][p2.index]
        if not wz50[ply-1][p2.index]: loss = false
        elif ply == 1: newLoss = true
        elif not wz50[ply-2][p2.index]: newLoss = true
      if moves.len == 0: loss = false
      if debug:
        echo "compute loss and newLoss: ", loss, " ", newLoss
      loss and newLoss
    else: false
  if bz50[ply][i]: inc bCount[ply]
  if debug: echo "black: ", i.toOct(6)," ",bz50[ply][i]
  captured = 0
  illegal = false
  p = newPos(white)
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
    if illegal: true
    elif captured == 0:
      var moves = p.genLegalMoves
      var win = wz50[ply-1][i]
      for mv in moves:
        var p2 = p
        p2.makeMove mv
        if bz50[ply-1][p2.index]: win = true
      win or wz50[ply-1][i]
    else: wz50[ply-1][i]
  if wz50[ply][i]: inc wCount[ply]

bz50[1] = newSeq[bool](pis.size)
wz50[1] = newSeq[bool](pis.size)

for ply in 1..25:
  bz50[ply] = newSeq[bool](pis.size)
  wz50[ply] = newSeq[bool](pis.size)
  for i in 0..<pis.size:
    compute(ply, i, false)
  
f = newFileStream(endgame & ".eg3", fmWrite)
if not f.isNil:
  for ply in 0..100:
    for b in bz50[ply]:
      f.write b
    for b in wz50[ply]:
      f.write b
else:
  echo "Error creating file."
f.flush

# output statistics
for ply in 0..25:
  if ply > 0:
    echo bCount[ply], ", ", wCount[ply]-wCount[ply-1]
  else:
    echo bCount[ply]
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔

