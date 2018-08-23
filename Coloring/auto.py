import time
import os

"""
Run multiThread.nim with arithmetic masks, iterating
up in binary numbers.
"""

trials = 250

os.system("nim c -d:release -d:auto --threads:on multiThread")
input("\nPress enter to continue...")

"""
We want to skip over all binary numbers with leading or trailing 0s.
We emulate this by prepending and appending each binary string with
a 1, and starting with running 1 and 11 on their own.
"""

def commands():
  yield f"./multiThread 2 arithmetic 1 {trials}"
  yield f"./multiThread 2 arithmetic 11 {trials}"

  n = 0
  while True:
    nbin = "1" + bin(n)[2:] + "1"
    yield f"./multiThread 2 arithmetic {nbin} {trials}"
    n += 1

wait = 3  # Seconds
for command in commands():
  # Give a slight pause so that user can CTRL-C to quit
  print(f"Running '{command}' in {wait}s...")
  time.sleep(wait)
  os.system(command)
