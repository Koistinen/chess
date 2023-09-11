# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams
import std/bitops
import std/unicode
import system
import std/strutils

type PieceIndex = object
  pt: Piece
  length: int
  bits: int
  sq: Square

type PieceIndexSeq* = seq[PieceIndex]

proc newPieceIndexSeq*: PieceIndexSeq = discard

proc add*(pis: var PieceIndexSeq, pt: Piece, sq: int) =
  var pi: PieceIndex
  pi.pt = pt
  pi.sq = sq
  pis.add pi

proc totalLength(pis: seq[PieceIndex]): int =
  for pi in pis:
    result.inc pi.length

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

proc setMasks*(pis: var seq[PieceIndex]) =
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
    
let pieceRunes = "♚♛♜♝♞♟□♙♘♗♖♕♔".toRunes
proc piece2Rune(pt: Piece): Rune = pieceRunes[pt.int+6]
proc pis2str(pis: seq[PieceIndex]): string =
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

proc lookup*(pis: PieceIndexSeq, side: Side): bool =
  var egstr: string
  for pt in countdown(♔, ♙):
    for pi in pis:
      if pi.pt == pt: egstr.add pt.piece2Rune
  for pt in ♚..♟:
    for pi in pis:
      if pi.pt == pt: egstr.add pt.piece2Rune
  echo "Looking up: ", pis.index.toOct(10), " in ", egstr
  false # fake lookup

when isMainModule:
  var pis = newPieceIndexSeq()
  # order they are added does not matter
  pis.add(♔, "e3".str2sq)
  pis.add(♚, "e1".str2sq)
  pis.add(♖, "a7".str2sq)
  pis.setMasks
  echo lookup(pis, white)
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔

