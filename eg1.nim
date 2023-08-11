# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams

const illegal = -1
const checkMate = 0
const unknown = 101
const draw =102

var dtc: array[2*64*64*64, int8]

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
              of 0: # check mate?
                if black == side:
                  if p.isCheckmate:
                    dtc[index] = checkMate
                    inc c
                  else:
                    if p.isStalemate:
                      dtc[index] = draw
              else:
                if white == side:
                  for mv in p.genLegalMoves:
                    var p2 = p
                    p2.makeMove(mv)
                    if ply > dtc[p2.genIndex]:
                      if dtc[index] != ply.int8:
                        inc c
                      dtc[index] = ply.int8
                else:
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
