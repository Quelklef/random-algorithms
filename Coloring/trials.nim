import locks
import terminal
import times
import strutils
import os

import coloring
import find
import ../util

const threadCount = 16

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

let C = 2
let desiredTrialCount = 500_000
var assignments: array[threadCount, Channel[(int, int, string, string, proc(d: int): Coloring {.closure, gcSafe.})]]

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
    let (p, N, outloc, description, pattern) = assignments[id].recv()

    # Store a (count, success) tuple as data
    var attempts = 0
    var successes = 0

    let fileloc = outloc / "$#.txt" % $N

    if fileExists(fileloc):
      let file = open(fileloc, mode = fmRead)
      defer: file.close()
      let existingData = file.readAll().splitLines()
      try:
        attempts = parseInt(existingData[0])
        successes = parseInt(existingData[1])
      except ValueError:
        put("WARNING: data in " & fileloc & " corrupt; overwriting", threadCount + 1)
        attempts = 0
        successes = 0

    defer:
      let file = open(fileloc, mode = fmWrite)
      file.write($attempts & "\n" & $successes & "\n")
      file.close()

    var col = initColoring(C, N)
    while attempts < desiredTrialCount:
      col.randomize()
      attempts += 1
      if col.hasMMP_progression(pattern):
        successes += 1

      template formatPercent(x: float, p = 1): string = (x * 100).formatFloat(format = ffDecimal, precision = p).align(4 + p)

      # Because IO is (presumably) such a huge portion of the runtime, only update every now and then
      const pause = 1  # minmum time between IO updates (s)
      if epochTime() > lastUpdate + pause:
        lastUpdate = epochTime()
        withLock(ioLock):
          let aId = ($id).align(len($threadCount))
          let aCurrentTrialCount = ($attempts).align(len($desiredTrialCount))
          put("[Thread $#] [$#] [N=$#] [Trial #$#/$#; $#%] :: $#%" %
            [
              aId,
              description,
              $N,
              aCurrentTrialCount,
              $desiredTrialCount,
              (attempts / desiredTrialCount).formatPercent,
              (successes / attempts).formatPercent(5),
            ],
            id + 1,
          )

    if attempts == successes:
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
  while true:
    let outloc = "data/$#" % $p
    let patternStr = p.toBase(2)
    let description = "p=$#, pattern=$#" % [$p, $patternStr]
    let pattern = proc(d: int): Coloring {.closure, gcSafe.} =
      result = initColoring(2, d * (patternStr.len - 1) + 1)
      for i, c in patternStr:
        if c == '1':
          result[i * d] = 1

    p += 1

    if not dirExists(outloc):
      createDir(outloc)

    var N = 1
    block nextP:
      while true:
        for i in 0 ..< threadCount:
          if responses[i].peek > 0:
            if responses[i].recv() == p:
              break nextP
          if assignments[i].trySend((p, N, outloc, description, pattern)):
            N += 1

main()
