import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal
import tables
import threadpool

import coloring
import find
import trial
from ../util import `*`, times, `{}`, createFile, numLines, optParam

const threadCount = 8

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

var ioLock: Lock
initLock(ioLock)

proc put(s: string; y: int) =
  stdout.setCursorPos(0, y)
  stdout.eraseLine()
  stdout.write(s)
  stdout.flushFile()

var threads: array[threadCount, Thread[int]]

var assignments: array[threadCount, Channel[(int, int, TrialSpec)]]

# The threads will do the work and respond with a signal
# iff the next p should be advanced to
# Sends back the given p
var responses: array[threadCount, Channel[int]]

for i in 0 ..< threadCount:
  assignments[i].open(maxItems = 1)
  responses[i].open()

proc work(id: int) {.thread.} =
  var lastUpdate = epochTime()
  while true:
    let (p, N, spec) = assignments[id].recv()

    # Store a (count, success) tuple as data
    var colorings = 0
    var successes = 0

    let fileloc = spec.outloc / "$#.txt" % $N

    if fileExists(fileloc):
      let file = open(fileloc, mode = fmRead)
      defer: file.close()
      let existingData = file.readAll().splitLines()
      try:
        colorings = parseInt(existingData[0])
        successes = parseInt(existingData[1])
      except ValueError:
        put("WARNING: data in " & fileloc & " corrupt; overwriting", threadCount + 1)
        colorings = 0
        successes = 0

    defer:
      let file = open(fileloc, mode = fmWrite)
      file.write($colorings & "\n" & $successes & "\n")
      file.close()

    var col = initColoring(spec.C, N)
    while colorings < spec.coloringCount:
      col.randomize()
      colorings += 1
      if col.hasMMP_progression(spec.pattern):
        successes += 1

      template formatPercent(x): string = (x * 100).formatFloat(format = ffDecimal, precision = 1).align(5)

      # Because IO is (presumably) such a huge portion of the runtime, only update every now and then
      const pause = 0.3  # minmum time between IO updates (s)
      if epochTime() > lastUpdate + pause:
        lastUpdate = epochTime()
        withLock(ioLock):
          let aN = ($N).align(len($spec.maxN))
          let aTrialCount = ($colorings).align(len($spec.coloringCount))
          put("[Thread $#] [$#] [N=$#] [Trial #$#/$#; $#%] :: $#%" %
            [
              $id,
              spec.description,
              aN,
              aTrialCount,
              $spec.coloringCount,
              (colorings / spec.coloringCount).formatPercent,
              (successes / colorings).formatPercent,
            ],
            id + 1,
          )

    if colorings == successes:
      responses[id].send(p)

proc main() =
  eraseScreen()
  put("Press <return> to exit.", 0)

  var stopThread: Thread[void]
  stopThread.createThread do:
    discard readLine(stdin)
    quit()

  var threads: array[threadCount, Thread[int]]
  for i in 0 ..< threadCount:
    threads[i].createThread(work, i)

  var p = 0
  let trialGen = arithmeticTrialGen
  while true:
    let trialSpec = trialGen(p)
    p += 1

    if not dirExists(trialspec.outloc):
      createDir(trialspec.outloc)

    var N = 1
    block nextP:
      while true:
        for i in 0 ..< threadCount:
          if responses[i].peek > 0:
            if responses[i].recv() == p:
              break nextP
          if assignments[i].trySend((p, N, trialSpec)):
            N += 1

main()
