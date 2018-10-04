import tables
import io
import misc
import parsecsv
import strutils
import math

var meanT = initTable[tuple[n: int, p: float], float]()
var meanG = initTable[tuple[n: int, p: float], float]()
var tDiffSum = initTable[tuple[n: int, p: float], float]()
var gDiffSum = initTable[tuple[n: int, p: float], float]()
var tCount = initTable[tuple[n: int, p: float], float]()
var gCount = initTable[tuple[n: int, p: float], float]()
var npPair: seq[tuple[n: int, p: float]] = @[]

var csv: CsvParser
csv.open("Turan_Stat.txt")
csv.readHeaderRow()

var n: int
var p: float
var t: float
var g: float

while csv.readRow():
    try:
      n = parseInt(rowEntry(csv, "n"))
      p = parseFloat(rowEntry(csv, "p"))
      t = parseFloat(rowEntry(csv, "TuranDiff"))
      g = parseFloat(rowEntry(csv, "GreedyDiff"))

      meanT[(n,p)] = t
      meanG[(n,p)] = g

      npPair.add((n,p))
    except ValueError:
      echo "Got (", n, ", ", p, ") for (n,p)"

csv.open("Turan_X.txt")
csv.readHeaderRow()
#[
while csv.readRow():
  try:
    n = parseInt(rowEntry(csv, "n"))
    p = parseFloat(rowEntry(csv, "p"))
    t = parseFloat(rowEntry(csv, "TuranDiff"))
    g = parseFloat(rowEntry(csv, "GreedyDiff"))

    if tDiffSum.hasKey((n,p)):
      tDiffSum[(n,p)] = tDiffSum[(n,p)] + pow( (t - meanT[(n,p)]), 2)
    else:
      tDiffSum[(n,p)] = pow( t - meanT[(n,p)], 2)

    if gDiffSum.hasKey((n,p)):
      gDiffSum[(n,p)] = gDiffSum[(n,p)] + pow( (g - meanG[(n,p)]), 2)
    else:
      gDiffSum[(n,p)] = pow( g - meanG[(n,p)], 2)

    if tCount.hasKey((n,p)):
      tCount[(n,p)] = tCount[(n,p)] + 1
    else:
      tCount[(n,p)] = 1

    if gCount.hasKey((n,p)):
      gCount[(n,p)] = gCount[(n,p)] + 1
    else:
      gCount[(n,p)] = 1
  except:
    echo "Got (", n, ", ", p, ") for (n,p)"
csv.close

let file = open("Real_Stat", mode = fmAppend)

for tup in npPair:
  file.writeRow(tup.n, tup.p, sqrt(tDiffSum[tup] / tCount[tup]), sqrt(gDiffSum[tup] / gCount[tup]))
]#
