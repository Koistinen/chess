# Copyright 2023 Urban Koistinen, Affero License
import chess
import streams
import std/algorithm

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
  result.sort(cmpPieceInfo, Descending) # normalizing

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

proc genTb(pl: var PieceList) =
  var tb: seq[seq[int8]]
  pl.first
  while true:
    block outer:
      var
        p: Pos
        v: int8
      var tbIndex = genIndex(pl)
      for pi in pl:
        if p.bd[pi.sq] != □:
          tb[white][tbIndex] = illegal
          tb[black][tbIndex] = illegal
          break outer
        p.addPiece(pi.pt, pi.sq)
      p.side = black
      v = unknown
      if p.isCheckmate:
        v = checkmate
      if p.isStalemate:
        v = stalemate
      if p.kingCapture:
        v = illegal
      tb[black][tbIndex] = v
      p.side = white
      v = unknown
      if p.kingCapture:
        v = illegal
      tb[white][tbIndex] = v
    if not pl.next:
      break
  var f = newFileStream("KQK.bigbin", fmWrite)
  if not f.isNil:
    f.write tb
  else:
    echo "Error creating file."
  f.flush

var p = fen2p("KQk//////// b - - 0")
var pl = p.genPieceList
genTb(pl)
# ♚, ♛, ♜, ♝, ♞, ♟, □, ♙, ♘, ♗, ♖, ♕ , ♔
