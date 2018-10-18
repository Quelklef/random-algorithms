import locks
import terminal
import times
import strutils
import db_sqlite
import strformat

import coloring
import algo
import ../util

when not isMainModule:
  echo("Please run only as main module.")
  quit()

const threadCount = 16

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

#-- DB Initialization --#

let db = open("data.db", "", "", "")

db.exec(sql"""
CREATE TABLE IF NOT EXISTS data (
  c INTEGER NOT NULL,
  k INTEGER NOT NULL,
  n INTEGER NOT NULL,
  attempts INTEGER NOT NULL,
  successes INTEGER NOT NULL
)
""")

var dbLock: Lock
initLock(dbLock)

#-- IO --#

# Because most printing in this module is for pure UX, i.e., it's not
# strictly necessary, we define a `put` function which MAY OR MAY
# NOT display a message at a certain y value. If it's already in
# the process of printing something, it will ignore the request.

var printChannel: Channel[(string, int)]
printChannel.open()

var printer: Thread[void]
printer.createThread do:
  while true:
    let (s, y) = printChannel.recv()
    stdout.setCursorPos(0, y)
    stdout.eraseLine()
    stdout.write(s)
    stdout.flushFile()

proc put(s: string; y: int) =
  if printChannel.ready:
    printChannel.send((s, y))

#-- Worker threads --#

type Assignment = tuple[c, n, k, attempts: int]
var assignmentChannels: array[threadCount, Channel[Assignment]]

for ch in assignmentChannels.mitems:
  open(ch)

proc assign(assignment: Assignment) =
  while true:
    for ch in assignmentChannels.mitems:
      if ch.ready:
        ch.send(assignment)
        return

proc work(id: int) {.thread.} =
  while true:
    let (C, N, K, attempts) = assignmentChannels[id].recv()
    let successes = generateSuccessCount(C, N, K, attempts)
    withLock(dbLock):
      db.exec(sql"INSERT INTO data (c, n, k, attempts, successes) VALUES (?, ?, ?, ?, ?)", C, N, K, attempts, successes)
    put(fmt"[Thread {($id).align($threadCount)}] [c={C}] [n={N}] [k={($K).align($N)}] :: {formatPercent(successes / attempts)}% ({($successes).align($attempts)}/{attempts})", id + 1)

var threads: array[threadCount, Thread[int]]

for i in 0 ..< threadCount:
  threads[i].createThread(work, i)

#-- Main loop --#

eraseScreen()
put("Press <return> to exit.", 0)

var stopThread: Thread[void]
stopThread.createThread do:
  discard readLine(stdin)
  quit()

for C in 2 .. 2:
  for N in 1 .. Inf:
    for K in 1 .. N:
      for attempts in countup(5_000, 50_000, 5_000):
        # If there is already a row for this data, skip it
        if db.getValue(sql"SELECT rowid FROM data WHERE c=? AND n=? AND k=? AND attempts=?", C, N, K, attempts) != "":
          put(fmt"Skipping c={C} n={N} k={K} attempts={attempts} as data has already been generated.", threadCount + 2)
        else:
          assign((C, N, K, attempts))

db.close()
