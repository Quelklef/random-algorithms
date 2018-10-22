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
  n INTEGER NOT NULL,
  k INTEGER NOT NULL,
  attempts INTEGER NOT NULL,
  successes INTEGER NOT NULL
)
""")

db.exec(sql"DROP INDEX IF EXISTS ka_index")
db.exec(sql"DROP INDEX IF EXISTS na_index")

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

type Assignment = tuple[C, N, K, attempts: int]
var assignmentChannels: array[threadCount, Channel[Assignment]]
for ch in assignmentChannels.mitems:
  open(ch)

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
    withLock(dbLock):
      defer: db.exec(sql"INSERT INTO data (c, n, k, attempts, successes) VALUES (?, ?, ?, ?, ?)", C, N, K, attempts, successes)
    put(fmt"[Thread {($id).align($threadCount)}] [c={C}] [n={N}] [k={($K).align($N)}] [a={attempts}] :: {formatPercent(successes / attempts)}% ({($successes).align($attempts)})", id + 1)
    if successes == 0:
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

let attemptsMin = 5_000
let attemptsStep = 5_000
let attemptsMax = 500_000

var C = db.getValue(sql"SELECT MAX(c) FROM data").parseInt.catch(ValueError, 2)
var N = db.getValue(sql"SELECT MAX(n) FROM data WHERE c=?", C).parseInt.catch(ValueError, 1)
var A = db.getValue(sql"SELECT MAX(attempts) FROM data WHERE C=? AND n=?", C, N).parseInt.catch(ValueError, attemptsMin)
var K = db.getValue(sql"SELECT MAX(k) FROM data WHERE C=? AND n=? AND attempts=?", C, N, A).parseInt.catch(ValueError, 1)

# Order of iteration: C, N, A, k

template incN =
  N.inc()

template incA =
  if A == attemptsMax:
    incN()
  else:
    A += attemptsStep

template incK =
  if K == N:
    K = 1
    incA()
  else:
    K.inc()

template nextAssignment =
  incK()

proc checkResponses(assignment: Assignment): bool =
  # If any thread has responded with the current state, skip k'>k
  for ch in responseChannels.mitems:
    if ch.peek() > 0:
      let response = ch.recv()
      if response.C == assignment.C and response.N == assignment.N and response.attempts == assignment.attempts:
        put(fmt"Skipping c={assignment.C} n={assignment.N} k>{assignment.K} a={assignment.attempts} since zeta_{assignment.attempts}({assignment.C}, {assignment.N}, {assignment.K}) = 0", threadCount + 2)
        return true

while true:
  let assignment = (C, N, K, A)
  while true:
    if checkResponses(assignment) or tryAssign(assignment):
      break
  nextAssignment()
