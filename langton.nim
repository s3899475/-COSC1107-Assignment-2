# simple langton's ant simulation

type
  Direction* = enum
    UP,
    RI,
    DN,
    LE

  Turn = enum
    None,
    Left,
    Right,
    UTurn

  Position = tuple[x, y: int]

  Ant* = ref object
    arr: seq[int]
    size*: tuple[x, y: int]
    def: string
    nstates*: int
    dir*: Direction
    pos*: Position

proc newAnt*(def: string, size: tuple[x, y: int], initial_dir: Direction = UP): Ant =
  #Ant(def: def, nstates:def.len, grid: newGrid[int](default=0), dir: initial_dir, pos: (0, 0))
  Ant(arr: newSeq[int](size.x*size.y), size: size, def: def, nstates:def.len, dir: initial_dir, pos: (size.x div 2, size.y div 2))

proc `[]`*(a: Ant, x, y: int): int =
  a.arr[y*a.size.x + x]

proc `[]=`*(a: Ant, x, y, val: int) =
  a.arr[y*a.size.x + x] = val

proc to_rotation(ch: char): Turn =
  case ch
  of 'N':
    None
  of 'L':
    Left
  of 'R':
    Right
  of 'U':
    UTurn
  else:
    raise newException(ValueError, "invalid ant definition")

proc turn(a: var Ant, turn: Turn) =
  case turn
  of None:
    discard
  of Right:
    case a.dir
    of UP:
      a.dir = RI
    of RI:
      a.dir = DN
    of DN:
      a.dir = LE
    of LE:
      a.dir = UP
  of Left:
    case a.dir
    of UP:
      a.dir = LE
    of RI:
      a.dir = UP
    of DN:
      a.dir = RI
    of LE:
      a.dir = DN
  of UTurn:
    case a.dir
    of UP:
      a.dir = DN
    of RI:
      a.dir = LE
    of DN:
      a.dir = UP
    of LE:
      a.dir = RI

proc move(a: var Ant) =
  case a.dir
  of UP:
    a.pos.y -= 1
  of RI:
    a.pos.x += 1
  of DN:
    a.pos.y += 1
  of LE:
    a.pos.x -= 1

proc get_state*(a: Ant): int {.inline.} =
  a[a.pos.x, a.pos.y]

proc in_bounds*(a: Ant): bool {.inline.} =
  a.pos.x >= 0 and a.pos.x < a.size.x and a.pos.y >= 0 and a.pos.y < a.size.y

proc step*(a: var Ant) =
  let state = a.get_state()

  a.turn(a.def[state].to_rotation)
  # change state
  a[a.pos.x, a.pos.y] = (state + 1) mod a.nstates

  a.move()

