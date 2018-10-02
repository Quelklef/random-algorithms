import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal
import tables

import coloring
import find
import trial
from ../util import `*`, times, `{}`, createFile, numLines, optParam

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

const threadCount = 8

var workerThreads: array[threadCount, Thread[tuple[i: int; spec: TrialSpec]]]
var nextN: int
var nLock: Lock
initLock(nLock)

var ioLock: Lock
initLock(ioLock)

proc put(s: string; y = 0) =
  stdout.setCursorPos(0, y)
  stdout.eraseLine()
  stdout.write(s)
  stdout.flushFile()

proc work(values: tuple[i: int; spec: TrialSpec]) {.thread.} =
  let (i, spec) = values
  var lastUpdate = 0.0  # 0 so that always updates on a new pattern

  while true:
    var N: int
    withLock(nLock):
      N = nextN
      nextN.inc()

    if N > spec.maxN:
      break

    # Store a (count, success) tuple as data
    var colorings = 0
    var successes = 0

    let fileloc = spec.outloc / "$#.txt" % $N

    if fileExists(fileloc):
      let file = open(fileloc, mode = fmRead)
      defer: file.close()
      let existingData = file.readAll().splitLines()
      colorings = parseInt(existingData[0])
      successes = parseInt(existingData[1])

    var col = initColoring(spec.C, N)
    while colorings < spec.coloringCount:
      # Note that we're testing against t here, meaning each time we run the program
      # we give the colorings a 'second chance' to be tolerable

      col.randomize()
      colorings += 1
      if col.hasMMP_progression(spec.pattern):
        successes += 1

      template formatPercent(x): string = (x * 100).formatFloat(format = ffDecimal, precision = 1).align(5)

      # Because IO is (presumably) such a huge portion of the runtime, only update every now and then
      const pause = 0.5  # minmum time between IO updates (s)
      if epochTime() > lastUpdate + pause:
        lastUpdate = epochTime()
        withLock(ioLock):
          let aN = ($N).align(len($spec.maxN))
          let aTrialCount = ($colorings).align(len($spec.coloringCount))
          put("[Thread $#] [$#] [N=$#/$#; $#%] [Trial #$#/$#; $#%] :: $#%" %
            [
              $i,
              spec.description,
              aN,
              $spec.maxN,
              (N / spec.maxN).formatPercent,
              aTrialCount,
              $spec.coloringCount,
              (colorings / spec.coloringCount).formatPercent,
              (successes / colorings).formatPercent,
            ],
            i,
          )

    let file = open(fileloc, mode = fmWrite)
    file.write($colorings & "\n" & $successes & "\n")
    file.close()

    if colorings == successes:
      break

let trialGen = arithmeticTrialGen

proc main() =
  eraseScreen()

  var p = 46#1
  while true:
    nextN = 1

    let trialSpec = trialGen(p)

    if not dirExists(trialspec.outloc):
      createDir(trialspec.outloc)

    for i in 0 ..< threadCount:
      workerThreads[i].createThread(work, (i: i, spec: trialSpec))
    workerThreads.joinThreads()

    p.inc()

main()
