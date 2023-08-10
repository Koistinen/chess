# Copyright 2023 Urban Koistinen, Affero License
import chess

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

for ply in -1..100:
  echo "Ply: ", ply
  for side in 0..1:
    echo "Side: ", side
    for ♔sq in 0..63:
      echo "♔sq: ", ♔sq.sq2str
      for ♚sq in 0..63:
        for ♕sq in 0..63:
          if ♔sq != ♚sq and ♔sq != ♕sq and ♚sq != ♕sq:
            var p: Pos
            p.addPiece(♔, ♔sq)
            p.addPiece(♚, ♚sq)
            p.addPiece(♕, ♕sq)
            p.side = side
            var index = p.genIndex
            case ply
            of -1: # illegal?
              dtc[index] = if p.kingCapture: illegal
                           else: unknown
            of 0: # check mate?
              if p.isCheckmate and 1 == side:
                dtc[index] = checkMate
            of 1:
              if black == side:
                if p.isStalemate:
                  dtc[index] = draw
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
                    dtc[index] = best.int8

# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
