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
import fileio
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

var terminalLock: Lock
initLock(terminalLock)

proc put(s: string; y = 0) =
  stdout.setCursorPos(0, y)
  stdout.eraseLine()
  stdout.write(s)
  stdout.flushFile()

proc work(values: tuple[i: int; spec: TrialSpec]) {.thread.} =
  let (i, spec) = values

  while true:
    var N: int
    withLock(nLock):
      N = nextN
      nextN.inc()

    if N > spec.maxN:
      break

    # 'tolerable' means that the thread has found a satisfactory coloring
    # If the thread is intolerable once the tolerance is reached, it's terminated
    var tolerable = false

    if not existsDir(spec.outloc):
      createDir(spec.outloc)
    let filename = spec.outloc / "N=$#.txt" % $N

    if not fileExists(filename):
      createFile(filename)

    var existingTrialCount: int
    block:
      let file = open(filename, mode = fmRead)
      existingTrialCount = file.getFileSize().int
      if '1' in file.readAll():
        tolerable = true
      file.close()

    let file = open(filename, mode = fmAppend)
    defer: file.close()

    var col = initColoring(spec.C, N)
    for t in 1 .. spec.coloringCount - existingTrialCount:
      # Note that we're testing against t here, meaning each time we run the program
      # we give the colorings a 'second chance' to be tolerable
      if t >= spec.tolerance and not tolerable:
        break

      col.randomize()
      if col.hasMMP_progression(spec.pattern):
        file.write(0)
      else:
        tolerable = true
        file.write(1)

      template formatPercent(x): string = x.formatFloat(format = ffDecimal, precision = 1).align(5)

      withLock(terminalLock):
        let trialCount = t + existingTrialCount
        let aN = ($N).align(len($spec.maxN))
        let aTrialCount = ($trialCount).align(len($spec.coloringCount))
        put("[Thread $#] [$#] [N=$#/$#; $#%] [Trial #$#/$#; $#%] [$#; $# left]" %
          [
            $i,
            spec.description,
            aN,
            $spec.maxN,
            (N / spec.maxN * 100).formatPercent,
            aTrialCount,
            $spec.coloringCount,
            (trialCount / spec.coloringCount * 100).formatPercent,
            if tolerable: "  tolerable" else: "intolerable",
            ($max(0, spec.tolerance - t)).align(len($spec.tolerance)),
          ],
          i,
        )

let trialGen = arithmeticTrialGen

proc main() =
  eraseScreen()

  var p = 1
  while true:
    nextN = 1

    let trialSpec = trialGen(p)
    for i in 0 ..< threadCount:
      workerThreads[i].createThread(work, (i: i, spec: trialSpec))
    workerThreads.joinThreads()

    p.inc

main()
