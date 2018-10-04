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
#COMMAND LINE FILES: number of nodes, increment for p, number of trials per n per p, 1 or 0 (True or False) if all n's in one file or seperate, 1 or 0 to calculate mean

let n = if (paramCount() >= 1): paramStr(1).parseInt else: 20
let inc = if (paramCount() >= 2): paramStr(2).parseFloat else: 0.1
let numTrials = if (paramCount() >= 3): paramStr(3).parseInt else: 1000
let oneFile = paramCount() >= 4 and paramStr(4).parseInt == 1
let stat = if (paramCount() >= 5): paramStr(5).parseInt != 0 else: true
const numThreads = 12
var prob: float = 0.0
var echoLock: Lock
var fileLock: Lock
initLock(echoLock)
initLock(fileLock)

var threads: array[numThreads, Thread[int]]
proc trials*(w: int) {.thread.}
proc main*() =

  var saveFile: string
  if oneFile:
    saveFile = "Turan_X.txt"
  else:
    saveFile = "Turan_" & intToStr(n) & ".txt"

  if stat:
    let statFile = open("Turan_Stat.txt", mode = fmAppend)
    statFile.writeRow("n", "p", "TuranDiff", "GreedyDiff")

  for i in 0 ..< numThreads:
    threads[i].createThread(trials, i)
  joinThreads(threads)

  setForegroundColor(fgYellow)
  echo "File saved as: ", saveFile
  resetAttributes()


proc probTuran*(p: float): tuple[turanDiff: float, shuffles: int, greedyDiff: float] =
  var g: Graph
  var e: int

  g = initProbGraph(n, p)
  shuffle(g)
  e = numE(g)
  var turanNum = float(n)/(2*e/n + 1)
  var numS = 1
  while float(findIndSetLeft(g).len) < turanNum:
    numS += 1
    shuffle(g)
  return (turanDiff: float(iSet(g)) - turanNum, shuffles: numS, greedyDiff: float(greedyISet(g)) - turanNum)

proc trials*(w: int) {.thread.} =
  var p: float
  var sumTuran = 0.0
  var sumGreedy = 0.0

  withLock(fileLock):
    p = prob
    prob = round(prob + inc, 2)
  if p <= 1:
    var saveFile: string
    if oneFile:
      saveFile = "Turan_X.txt"
    else:
      saveFile = "Turan_" & intToStr(n) & ".txt"

    withLock(echoLock):
      if int(p / inc) mod 20 == 0:
        setForegroundColor(fgYellow)
        echo "---------------------------"
        echo "N = ", n
        echo "---------------------------"
      setForegroundColor(fgCyan)
      echo "Thread " & intToStr(w).align(2,'0') & " starting p = " & p.formatFloat(ffDecimal, 2)

    let fileName = "Turan_" & intToStr(n) & "_" & p.formatFloat(ffDecimal, 2) & ".txt"
    let file = open(fileName, mode = fmAppend)
    file.writeRow("n", "p", "Shuffles", "TuranDiff", "GreedyDiff")
    var startTime: float
    try:
      startTime = cpuTime()
      for _ in 0 ..< numTrials:
        let (t, s, g) = probTuran(p)
        if oneFile:
          file.writeRow(n, p, s, t, g)
          #file.writeRow(n, p, t, g) #don't really need data on shuffles
        else:
          file.writeRow(p, s, t, g)
        if stat:
          sumTuran += t
          sumGreedy += g
        #[ #per trial output
        echo zip([$p, $s, $(round(d, 1))], [4, 3, 4]) #implements tabular's display method without memory accessing problems
                   .mapIt(align(it[0], it[1]))
                   .joinSurround(" | ")
                   ]#
    except IOError:
      setForegroundColor(fgRed)
      echo "Error: Failed to open to file: Thread ", w, ", n ", n, ", p ", p
      discard readLine(stdin)
    finally:
      close(file)

    if stat:
      withLock(fileLock):
        let statFile = open("Turan_Stat.txt", mode = fmAppend)
        statFile.writeRow(n, p, sumTuran / float(numTrials), sumGreedy / float(numTrials))

    withLock(fileLock):
      concatFile(saveFile, fileName)
      removeFile(fileName)
    withLock(echoLock):
      styledEcho(fgGreen, "p = " & p.formatFloat(ffDecimal, 2) & " done in " & round(cpuTime() - startTime, 2).formatFloat(ffDecimal, 2) & "s")
    #setForegroundColor(fgGreen)
    trials(w)
  else:
    withLock(echoLock):
      setForegroundColor(fgMagenta)
      echo "Thread " & intToStr(w).align(2,'0') & " is now idle"

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
