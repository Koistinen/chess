import chess
import streams

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

var f = newFileStream("KQk.eg2", fmread)
discard f.readData(dtc.addr, dtc.sizeof)
var count: array[-1..103, int]

for i in (0*64*64*64)..<(1*64*64*64):
  let v = dtc[i]
  if not (v in -1..103):
    echo "out of bound value at ", i, ": ", v
  else:
    inc count[v]
for i in -1..103:
  echo i, ": ", count[i]
  count[i] = 0
for i in (1*64*64*64)..<(2*64*64*64):
  let v = dtc[i]
  if not (v in -1..103):
    echo "out of bound value at ", i, ": ", v
  else:
    inc count[v]
for i in -1..103:
  echo i, ": ", count[i]
for ♔sq in 0..63:
  for ♚sq in 0..63:
    for ♕sq in 0..63:
      if ♔sq != ♚sq and ♔sq != ♕sq and ♚sq != ♕sq:
        var p: Pos
        p.addPiece(♔, ♔sq)
        p.addPiece(♚, ♚sq)
        p.addPiece(♕, ♕sq)
        p.side = white
        var index = p.genIndex
        if dtc[index] == 19:
          echo p.p2fen
