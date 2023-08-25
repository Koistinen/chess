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
#    wz50[n-1] else
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
  pt: PieceType
  length: int
  bits: int
  sq: Square

proc pieceIndexSeq(eg: string): seq[PieceIndex] =
  for rune in eg.toRunes:
    var pi: PieceIndex
    pi.pt = ("♚♛♜♝♞♟□♙♘♗♖♕♔".toRunes.find(rune)-6).PieceType
    pi.length = 6
    result.add(pi)
  result[0].length = 4

proc totalLength(pis: seq[PieceIndex]): int =
  for pi in pis:
    result.inc(pi.length)

var pis = pieceIndexSeq(endgame)
proc size(pis: seq[PieceIndex]): int =
  1 bsl pis.totalLength

# I hope the compiler is able to optimize these to use PDEP/PEXT
proc depositBits(msk, source: int): int =
  var b=0
  var m=msk
  while m != 0:
    if source.testBit(b) != 0:
      result.setMask(mask.band -mask)
    m.mask(m - 1)
    inc b
 
proc extractBits(msk, source: int): int =
  var b=0
  var m=msk
  while m != 0:
    if source.band msk.band -mask != 0:
      result.setBit b
    m.mask(m - 1)
    inc b

U64 _pext_u64(U64 val, U64 mask) {
  U64 res = 0;
  for (U64 bb = 1; mask; bb += bb) {
    if ( val & mask & -mask )
      res |= bb;
    mask &= mask - 1;
  }
  return res;
} 

proc index(pis: seq[PieceIndex]): int =
  for pi = in pis:
    

b🛇 = newBitSeq(pis.size)
for i in 0..<pis.size:
  

proc genIndex(p: Pos): int =
  var ♔sq, ♚sq, ♕sq: 0..63
  for sq in 0..63:
    case p.bd[sq]
    of ♔:
      ♔sq = sq
    of ♚:
      ♚sq = sq
    of ♕:
      ♕sq = sq
    else:
      discard
  return ♕sq+64*(♚sq+64*(♔sq+64*p.side))

for i in 0..<(2*64*64*64):
  dtc[i] = unknown
  
for ply in -1..24:
  echo "Ply: ", ply
  for side in white..black:
    echo "Side: ", side
    var c = 0
    for ♔sq in 0..63:
      for ♚sq in 0..63:
        for ♕sq in 0..63:
          if ♔sq != ♚sq and ♔sq != ♕sq and ♚sq != ♕sq:
            var p: Pos
            p.addPiece(♔, ♔sq)
            p.addPiece(♚, ♚sq)
            p.addPiece(♕, ♕sq)
            p.side = side
            var index = p.genIndex
            if unknown == dtc[index]:
              case ply
              of -1: # illegal?
                dtc[index] = if p.kingCapture: illegal
                             else: unknown
              of 0: # check mate or stalemate or queen capture?
                if black == side:
                  if p.isCheckmate:
                    dtc[index] = checkMate
                  if p.isStalemate:
                    dtc[index] = draw
                  for mv in p.genLegalMoves:
                    if p.bd[mv.to] == ♕:
                      dtc[index] = draw
              else: # ply > 0
                if white == side:
                  for mv in p.genLegalMoves:
                    var p2 = p
                    p2.makeMove(mv)
                    if ply > dtc[p2.genIndex]:
                      if dtc[index] != ply.int8:
                        inc c
                      dtc[index] = ply.int8
                else: # black
                  var best = checkMate
                  for mv in p.genLegalMoves:
                    var p2 = p
                    p2.makeMove mv
                    best = max(best, dtc[p2.genIndex])
                  if ply > best:
                    inc c
                    dtc[index] = ply.int8
    echo "count: ", c
var f = newFileStream("KQK.bigbin", fmWrite)
if not f.isNil:
  f.write dtc
else:
  echo "Error creating file."
f.flush
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
