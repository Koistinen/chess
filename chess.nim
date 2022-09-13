type Square* = range[0..63]
proc square*(rank, file: int):Square = rank*8+file
proc rank*(sq: Square):int=sq shr 3
proc file*(sq: Square):int=sq and 7
proc `$`* (sq: Square):string =
  result.add("abcdefgh"[sq.file])
  result.add("12345678"[sq.rank])

type Bitboard* = int64
proc bitboard* (sq: Square):Bitboard = 1 shl sq
proc `$`* (bb: Bitboard): string =
  for rank in countdown(7,0):
    if rank<7: result.add('\n')
    for file in countup(0,7):
      if 0 == (bb and bitboard(square(rank, file))):
        result.add('-')
      else:
        result.add('+')
        
echo bitboard(square(0,1)) or bitboard(square(2,2))
echo square(0,1)
echo square(2,2)