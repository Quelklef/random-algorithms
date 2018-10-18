import locks
import terminal
import times
import strutils
import db_sqlite
import strformat

import coloring
import algo
import ../util

const threadCount = 16

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

#-- DB Initialization --#

let db = open("data.db", "", "", "")

db.exec(sql"""
CREATE TABLE IF NOT EXISTS data (
  C INTEGER NOT NULL,
  K INTEGER NOT NULL,
  N INTEGER NOT NULL,
  attempts INTEGER NOT NULL,
  successes INTEGER NOT NULL
)
""")

#-- IO --#

var ioLock: Lock
initLock(ioLock)
proc put(s: string; y: int) =
  withLock(ioLock):
    stdout.setCursorPos(0, y)
    stdout.eraseLine()
    stdout.write(s)
    stdout.flushFile()

#-- Worker threads --#

var threads: array[threadCount, Thread[int]]
type Assignment = tuple[c, n, k, attempts: int]
var assignmentChannels: array[threadCount, Channel[Assignment]]

for ch in assignmentChannels.mitems:
  open(ch, 1)

proc assign(assignment: Assignment) =
  while true:
    for ch in assignmentChannels.mitems:
      if ch.trySend(assignment):
        return

proc formatPercent(x: float, p = 1): string =
  return (x * 100).formatFloat(format = ffDecimal, precision = p).align(4 + p)

proc work(id: int) {.thread.} =
  let showId = ($id).align(len($threadCount))
  var lastUpdate = epochTime()

  while true:
    let (C, N, K, attempts) = assignmentChannels[id].recv()
    let successes = generateSuccessCount(C, N, K, attempts)
    db.exec(sql"INSERT INTO data (c, n, k, attempts, successes) VALUES (?, ?, ?, ?, ?)", C, N, K, attempts, successes)
    put(fmt"[Thread {showId}] [c={C}] [n={N}] [k={($K).align(len($N))}] :: {formatPercent(successes / attempts)}% ({successes}/{attempts})", id + 1)

#-- Main loop --#

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

  for C in [2]:
    for N in 1 .. Inf:
      for K in 1 .. N:
        for attempts in countup(5_000, 50_000, 5_000):
          if db.getAllRows(sql"SELECT null FROM data WHERE c=? AND n=? AND k=? AND attempts=?", C, N, K, attempts).len > 0:
            put(fmt"Skipping c={C} n={N} k={K} as data has already been generated.", threadCount + 2)
            continue
          else:
            assign((C, N, K, attempts))

when isMainModule:
  main()
