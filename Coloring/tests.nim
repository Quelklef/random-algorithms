import unittest
import macros
import random

import coloring
import find

proc genStringNum(base, length: int): string =
  ## Generate s string of given length that
  ## encodes a random number of the given base
  result = ""
  for _ in 1 .. length:
    result &= chr(rand(base - 1) + ord('0'))

template testMany(name: string, body: untyped): untyped =
  test name:
    for _ in 1 .. 100:
      body

func `!`(s: string): Coloring[2] =
  initColoring(2, s)

suite "Testing twoColoring":
  setup:
    discard  # Run before each test
  teardown:
    discard  # Run after each test

  testMany "(C=2) initColoring / $":
    let s = genStringNum(2, rand(500))
    check($ !s == s)

  testMany "(C=2) []":
    let s = genStringNum(2, rand(500))
    let col = !s
    for i, car in s:
      check($col[i] == $car)

  testMany "(C=2) >>=":
    let shift = rand(1 .. 63)
    let s = genStringNum(2, 64 + rand(300))
    var col = !s
    let befor = ($col)[0 ..< ^shift]
    col >>= shift
    let after = ($col)[shift ..< ^0]
    check(befor == after)

  testMany "(C=2) == / !=":
    let len = rand(1 .. 500)
    let s = genStringNum(2, len)
    var c0 = !s
    var c1 = !s
    check(c0 == c1)
    let pos = rand(len - 1)
    c0[pos] = if c0[pos] == 0: 1 else: 0
    check(c0 != c1)

  test "(C=2) homoegenous":
    check homogenous(!"010", !"101")
    check homogenous(!"11111", !"11111")
    check homogenous(!"00100", !"11011")
    check homogenous(!"10101010101", !"10101010101")

  test "has_MAS":
    discard

  discard  # Run once after each test
