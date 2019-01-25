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

const threadCount = 8

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

#-- DB Initialization --#

let db = open("data.db", "", "", "")

db.exec(sql"""
CREATE TABLE IF NOT EXISTS data (
  attempts INTEGER NOT NULL,
  c INTEGER NOT NULL,
  k INTEGER NOT NULL,

  n INTEGER NOT NULL
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
  when defined(instantIO):
    stdout.setCursorPos(0, y)
    stdout.eraseLine()
    stdout.write(s)
    stdout.flushFile()
  else:
    if printChannel.ready:
      printChannel.send((s, y))

#-- Worker threads --#

type Assignment = tuple[C, N, K, attempts: int]
var assignmentChannels: array[threadCount, Channel[Assignment]]
for ch in assignmentChannels.mitems:
  ch.open(1)

# When a thread gets a success count of 0, it responds with its
# assignment so that we may skip all k'>k
var responseChannels: array[threadCount, Channel[Assignment]]
for ch in responseChannels.mitems:
  open(ch)

proc work(id: int) {.thread.} =
  while true:
    let assignment = assignmentChannels[id].recv()
    let (C, N, K, attempts) = assignment
    let successes = generateSuccessCount(C, N, K, attempts)
    put(fmt"[Thread {($id).align($threadCount)}] [c={C}] [n={N}] [k={($K).align($N)}] [a={attempts}] :: {formatPercent(successes / attempts)}% ({($successes).align($attempts)})", id + 1)
    if successes == attempts:
      withLock(dbLock):
        if db.getValue(sql"SELECT n FROM DATA WHERE c=? AND k=? AND attempts=?", C, K, attempts) == "":
          defer: db.exec(sql"INSERT INTO DATA (c, k, attempts, n) VALUES (?, ?, ?, ?)", C, K, attempts, N)
      responseChannels[id].send(assignment)

var threads: array[threadCount, Thread[int]]
for i in 0 ..< threadCount:
  threads[i].createThread(work, i)

proc tryAssign(assignment: Assignment): bool =
  ## Returns if was successfully assigned
  for ch in assignmentChannels.mitems:
    if ch.ready:
      ch.send(assignment)
      return true

#-- Main loop --#

eraseScreen()
put("Press <return> to exit.", 0)

var stopThread: Thread[void]
stopThread.createThread do:
  discard readLine(stdin)
  db.close()
  quit()

proc checkResponses(assignment: Assignment): bool =
  # If any thread has responded with the current state, skip k'>k
  for ch in responseChannels.mitems:
    if ch.peek() > 0:
      let response = ch.recv()
      if response.C == assignment.C and response.K == assignment.K and response.attempts == assignment.attempts:
        put(fmt"Skipping c={assignment.C} n>{assignment.N} k={assignment.K} a={assignment.attempts} since zeta_{assignment.attempts}({assignment.C}, {assignment.N}, {assignment.K}) = 1", threadCount + 2)
        return true

iterator upfrom(x0 = 1): int =
  var x = x0
  while true:
    yield x
    x.inc()

const C = 2
for K in upfrom(db.getValue(sql"SELECT MAX(k) FROM data").parseInt.catch(ValueError, 1)):
  for A in countup(500_000, 10_000_000, 500_000):
    block nextA:
      for N in upfrom(K):  # for n<=k, guaranteed zeta=0
        let assignment = (C, N, K, A)
        while true:
          if checkResponses(assignment):
            break nextA
          if tryAssign(assignment):
            break
