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
    for ♔sq in 0..63:
#      echo "♔sq: ", ♔sq.sq2str
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
                  else:
                    if ♚sq == 0 and ♕sq == 1 and ♔sq == 2:
                      echo "Can't be!"
              of 1:
                if black == side:
                  if p.isStalemate:
                    dtc[index] = draw
                  else:
                    if unknown == dtc[index]:
                      var best = checkMate
                      for mv in p.genLegalMoves:
                        var p2 = p
                        p2.makeMove mv
                        best = max(best, dtc[p2.genIndex])
                      if ply-1 == best:
                        dtc[index] = ply.int8
                else:
                  for mv in p.genLegalMoves:
                    var p2 = p
                    p2.makeMove(mv)
                    if checkMate == dtc[p2.genIndex]:
                      dtc[index] = 1
              else:
                if white == side:
                  if unknown == dtc[index]:
                    for mv in p.genLegalMoves:
                      var p2 = p
                      p2.makeMove(mv)
                      if ply-1 == dtc[p2.genIndex]:
                        dtc[index] = ply.int8
                else:
                  if unknown == dtc[index]:
                    var best = checkMate
                    for mv in p.genLegalMoves:
                      var p2 = p
                      p2.makeMove mv
                      best = max(best, dtc[p2.genIndex])
                    if ply-1 == best:
                      dtc[index] = ply.int8
var f = newFileStream("KQK.bigbin", fmWrite)
if not f.isNil:
  f.write dtc
else:
  echo "Error creating file."
f.flush
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
