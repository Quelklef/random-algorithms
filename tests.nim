
import unittest
import macros
import strutils
import streams
import times
import sets
import os
import terminal

import twoColoring



suite "Testing twoColoring":
  #echo "suite setup: run once before the tests"
  var emptyTwoColoring, randomTwoColoring, fromStringColoring1, fromStringColoring2: TwoColoring

  setup:
    #echo "run before each test"
    emptyTwoColoring = initTwoColoring(64)
    randomTwoColoring = initTwoColoring(64)
    randomize(randomTwoColoring)
    echo "Random TwoColoring: ", $randomTwoColoring
    fromStringColoring1 = fromString("11111")
    fromStringColoring2 = fromString("10110")

  teardown:
    echo "run after each test"


  test "TwoColoring ==":
    check(emptyTwoColoring == emptyTwoColoring)
    check(randomTwoColoring == randomTwoColoring)
    check(fromStringColoring1 == fromStringColoring2)
    #require(true)

  test "TwoColoring []":
    check(fromStringColoring1[0] == 1)
    check(fromStringColoring1[1] == 0)
    check(fromStringColoring1[2] == 1)
    check(fromStringColoring1[3] == 1)
    check(fromStringColoring1[4] == 0)

  echo "suite teardown: run once after the tests"
