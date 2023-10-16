# langton's ant terminal program
import terminal, std/exitprocs, parseopt
from os import sleep
from strutils import parseInt
import std/deques

import ../langton

const
  colours: seq[BackgroundColor] = @[
    bgBlack,
    bgWhite,
    bgCyan,
    bgBlue,
    bgMagenta,
    bgRed,
    bgYellow,
    bgGreen,
    bgDefault
  ]

proc colour_print(a: var Ant) =
  for y in 0..<a.size.y:
    for x in 0..<a.size.x:
      setBackgroundColor(colours[a[x, y]])
      if x == a.pos.x and y == a.pos.y:
        stdout.write 'A'
      else:
        stdout.write ' '

    resetAttributes()
    stdout.write '\n'

proc exit() =
  resetAttributes()
  showcursor()
exitprocs.addExitProc(exit)
hideCursor()

var
  ant_definition: string
  sleep_ms = 50
  iterations = 1000
  quick = false
  jump = 0
for kind, key, val in getopt(longNoVal = @["quick"], shortNoVal = {'q'}):
  case kind
  of cmdArgument:
    ant_definition = key
  of cmdLongOption, cmdShortOption:
    case key
    of "sleep", "s": sleep_ms = val.parseInt
    of "iterations", "iters", "i": iterations = val.parseInt
    of "quick", "q": quick=true
    of "jump", "j": jump = val.parseInt
  of cmdEnd: assert(false)
if ant_definition == "":
  echo "define an ant with the characters L, R, U and N"
else:
  var a = newAnt(ant_definition, (50, 50))
  if quick: # quick mode
    for _ in 1..iterations:
      a.step()
    a.colour_print()
  elif jump > 0: # jump mode
    for _ in countup(1, iterations, jump):
      for _ in 1..jump:
        a.step()
      stdout.eraseScreen
      a.colour_print()
      sleep(sleep_ms)
  else: # default mode
    for _ in 1..iterations:
      a.step()
      stdout.eraseScreen
      a.colour_print()
      #echo a
      sleep(sleep_ms)
#[
#sleep(2000)
#var a = initAnt("RL") # default
#var a = initAnt("LLRR") # symetric
#var a = initAnt("LRL") # chaotic
#var a = initAnt("LRRRRRLLR") # square
for _ in 1..10000:
  stdout.eraseScreen
  #echo a
  a.colour_print()
  #echo a.grid
  a.step()
  sleep(10)
]#


