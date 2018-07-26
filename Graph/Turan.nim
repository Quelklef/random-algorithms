import node
import graph
import random
import io
import math
import locks
import strutils
import os
import sequtils
import misc
import times
import terminal

random.randomize()

let tabular = initTabular(
    ["Vertices", "Edges", "Shuffles"],
    [ 3        ,  2     , 10        ],
)
proc report(values: varargs[string, `$`]) =
  echo tabular.row(values)

proc turanDisplay*(n: int, e: int = -1): void =
  var edges = e
  if float(e) > n*(n-1)/2:
    edges = int(n*(n-1)/2)
    echo "Too many edges, defaulting to ", edges, " edges"

  var g: Graph
  if e < 0:
    g = initRandGraph(n)
  else:
    g = initRandGraph(n, edges)

  var turanNum = float(size(g))/(2*numE(g)/size(g) + 1)

  echo "n = ", size(g), ", e = ", numE(g)
  echo "Turan's Theorm: n/(2e/n + 1) = ", turanNum

  var count = 1
  while float(iSet(g)) < turanNum:
    count += 1
    shuffle(g)
  echo "Shuffled ", count, " times"
  display(g)

proc zeroSeq(n: int): seq[int] =
  for i in 0 ..< n:
    result.add(0)

iterator increment(start: float, stop: float, inc: float): float =
  var i = start
  while i < stop:
    yield i
    i += inc

###TESTING THINGS
#COMMAND LINE FILES: number of nodes, increment for p, number of trials per n per p, 1 or 0 (True or False) if all n's in one file or seperate
let n = if (paramCount() >= 1): paramStr(1).parseInt else: 20
let inc = if (paramCount() >= 2): paramStr(2).parseFloat else: 0.1
let numTrials = if (paramCount() >= 3): paramStr(3).parseInt else: 1000
let oneFile = paramCount() >= 4 and paramStr(4).parseInt == 1
const numThreads = 12
var prob: float = 0.0

var threads: array[numThreads, Thread[int]]
proc trials*(w: int) {.thread.}
proc main*() =
  var saveFile: string
  if oneFile:
    saveFile = "Turan_X.txt"
  else:
    saveFile = "Turan_" & intToStr(n) & ".txt"

  setForegroundColor(fgYellow)
  echo "Starting on N = ", n
  for i in 0 ..< numThreads:
    threads[i].createThread(trials, i)
  joinThreads(threads)

  setForegroundColor(fgYellow)
  echo "File saved as: ", saveFile
  resetAttributes()


proc probTuran*(p: float): tuple[diff: float, shuffles: int] =
  var g: Graph
  var e: int

  g = initProbGraph(n, p)
  shuffle(g)
  e = numE(g)
  var turanNum = float(n)/(2*e/n + 1)
  var numS = 1
  while float(iSet(g)) < turanNum:
    numS += 1
    shuffle(g)
  return (diff: float(iSet(g)) - turanNum, shuffles: numS)

proc trials*(w: int) {.thread.} =
  if prob <= 1:
    var saveFile: string
    if oneFile:
      saveFile = "Turan_X.txt"
    else:
      saveFile = "Turan_" & intToStr(n) & ".txt"

    var p = prob
    prob = round(prob + inc, 2)

    let fileName = "Turan_" & intToStr(n) & "_" & p.formatFloat(ffDecimal, 2) & ".txt"
    let file = open(fileName, mode = fmAppend)
    var startTime: float

    setForegroundColor(fgCyan)
    echo "Thread " & intToStr(w) & " starting p = " & p.formatFloat(ffDecimal, 2)
    try:
      startTime = cpuTime()
      for _ in 0 ..< numTrials:
        let (d, s) = probTuran(p)
        file.writeRow(p, s, d)
        #[ #per trial output
        echo zip([$p, $s, $(round(d, 1))], [4, 3, 4]) #implements tabular's display method without memory accessing problems
                   .mapIt(align(it[0], it[1]))
                   .joinSurround(" | ")
                   ]#
    finally:
      close(file)
    concatFile(saveFile, fileName)
    removeFile(fileName)
    #setForegroundColor(fgGreen)
    styledEcho(fgGreen, "p = " & p.formatFloat(ffDecimal, 2) & " done in " & round(cpuTime() - startTime, 2).formatFloat(ffDecimal, 2) & "s")
    trials(w)

when isMainModule:
  main()

#Finds numShuffles for all simple graphs that have n nodes and e edges
proc turanAll*(n:int, e:int): seq[int] =
  var turanNum = float(n)/(2*e/n + 1)
  for i in comb(n, e):
    var g:Graph = initGraph(n)
    var numS = 1
    for j in i:
      addE(n, j, g)
    shuffle(g)
    while float(iSet(g)) < turanNum:
      numS += 1
      shuffle(g)
    result.add(numS)

proc turan*(n: int, e: int = -1): int =
  result = 1
  var edges = e
  if float(e) > n*(n-1)/2:
    edges = int(n*(n-1)/2)
  var g: Graph
  if e < 0:
    g = initRandGraph(n)
  else:
    g = initRandGraph(n, edges)
  var turanNum = float(size(g))/(2*numE(g)/size(g) + 1)
  while float(iSet(g)) < turanNum:
    result += 1
    shuffle(g)

#[
echo tabular.title()
# TODO: for some reason n =1 doesn't work, shouldn't matter tho
for n in 1 .. 10:
  for e in n-1 .. int(n*(n-1)/2):
    #report(n, e, turan(n, e))
    for o in turanAll(n, e):
      report(n, e, o)
close(outFile)
]#
