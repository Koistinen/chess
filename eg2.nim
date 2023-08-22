# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams
import std/algorithm
import std/sequtils

const illegal = -1
const checkMate = 0
const unknown = 101
const draw =102
const staleMate = 103

type
  PieceInfo = object
    pt: Piece
    sq: 0..63
  PieceList = seq[PieceInfo]

proc pieceInfo(pt: Piece, sq: 0..63): PieceInfo =
  result.pt = pt
  result.sq = sq

proc add(pl: var PieceList, pt: Piece, sq: 0..63 = 0) =
  pl.add(pieceInfo(pt, sq))

proc cmpPieceInfo(a, b: PieceInfo): int =
  cmp(a.pt, b.pt)

proc genPieceList(p: Pos): PieceList =
  var ♔sq, ♚sq, ♕sq: 0..63
  for sq in 0..63:
    let pt = p.bd[sq]
    if pt != □:
      result.add(pt, sq)
  result.sort(cmpPieceInfo, Descending)

proc first(pl: var PieceList) =
  for i in 0..<pl.len:
    pl[i].sq = 0

proc next(pl: var PieceList): bool =
  for i in 0..<pl.len:
    if pl[i].sq < 63:
      inc pl[i].sq
      return true # success
    else:
      pl[i].sq = 0
  return false # overflow
  
proc indexSize(pl: PieceList): int =
  1 shl (6*pl.len)

proc genIndex(pl: PieceList): int =
  for pi in pl:
    result *= 64
    result += pi.sq

proc tableClass(pl: PieceList): int =
  result = 1
  for pi in pl:
    result *= 12
    var v = 6 + pi.pt.int
    if v > 6: # white piece
      dec v

proc name(pl: PieceList): string =
  for pi in pl:
    result.add(fenPc[pi.pt.int])

proc lookup(p: Pos): int =
  # fake lookup for now
  return draw

proc write(f: FileStream, s: seq[int8]) =
  f.writeData(s[0].addr, s.len)

proc genTb(pl: var PieceList) =
  #initialize
  echo "ply = -1..0"
  var wz50 = newSeq[int8](pl.indexSize) # wtm
  var bz50 = newSeq[int8](pl.indexSize) # btm
  pl.first
  while true:
    var
      p: Pos
      w, b: int8
    block outer:
      for pi in pl:
        if p.bd[pi.sq] != □: # occupied?
          break outer
        p.addPiece(pi.pt, pi.sq)
      p.side = black
      b = unknown
      if p.isCheckmate:
        b = checkmate
      if p.isStalemate:
        b = stalemate
      if p.kingCapture:
        b = illegal
      p.side = white
      w = unknown
      if p.kingCapture:
        w = illegal
    let tbIndex = genIndex(pl)
    wz50[tbIndex] = w
    bz50[tbIndex] = b
    if not pl.next:
      break
  # z50 = 1
  echo "ply = 1"
  pl.first
  while true:
    var
      p: Pos
      w, b: int8
    block outer:
      for pi in pl:
        if p.bd[pi.sq] != □: # occupied?
          w = illegal
          b = illegal
          break outer
        p.addPiece(pi.pt, pi.sq)
      let tbIndex = genIndex(pl)
      p.side = black
      b = bz50[tbIndex]
      if b == unknown:
        # z50 move avoiding loss?
        let ml = p.genLegalMoves
        for mv in ml:
          if p.isCapture(mv):
            var p2 = p
            p2.makeMove(mv)
            if draw == lookup(p2):
              b = draw
          # ignore pawn moves, no pawns allowed
        # ignore possibility of noncapture drawing
      bz50[tbIndex] = b
      p.side = white
      w = wz50[tbIndex]
      if w == unknown:
        # any win with z50 == 1?
        let ml = p.genLegalMoves
        for mv in ml:
          var p2 = p
          p2.makeMove(mv)
          if p.isCapture(mv):
            if lookup(p2) < unknown:
              w = 1 # win with z50 == 1
          else:
            if checkmate == bz50[p2.genPieceList.genIndex]:
              w = 1 # mate in 1
      wz50[tbIndex] = w
    if not pl.next:
      break
  for ply in 2..2:
    echo "ply = ", ply
    pl.first
    while true:
      var
        p: Pos
        w, b: int8
      block outer:
        for pi in pl:
          if p.bd[pi.sq] != □: # occupied?
            w = illegal
            b = illegal
            break outer
          p.addPiece(pi.pt, pi.sq)
        let tbIndex = genIndex(pl)
        p.side = black
        b = bz50[tbIndex]
        if b == unknown:
          # z50 move avoiding loss?
          let ml = p.genLegalMoves
          var best = ply
          for mv in ml:
            if not p.isCapture(mv):
              var p2 = p
              p2.makeMove(mv)
              if wz50[p2.genPieceList.genIndex] > ply-1:
                best = unknown
          b = best.int8
        bz50[tbIndex] = b
        p.side = white
        w = wz50[tbIndex]
        if w == unknown:
          # any win with z50 == ply?
          let ml = p.genLegalMoves
          for mv in ml:
            var p2 = p
            p2.makeMove(mv)
            if not p.isCapture(mv):
              if ply-1 == bz50[p2.genPieceList.genIndex]:
                w = ply.int8
        wz50[tbIndex] = w
      if not pl.next:
        break
  var f = newFileStream(pl.name & ".eg2", fmWrite)
  if not f.isNil:
    f.write(wz50)
    f.write(bz50)
  else:
    echo "Error creating file."
  f.flush

var p = fen2p("KQk b - - 0")
var pl = p.genPieceList
genTb(pl)
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
