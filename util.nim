import options
import os

# TODO: `func`
proc optParam*(n: int): Option[TaintedString] =
  if paramCount() >= n:
    return some(paramStr(n))
  return none(TaintedString)

when isMainModule:
  import strutils
  echo(optParam(1).map(parseInt).get(20))
