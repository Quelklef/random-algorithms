import os
from scipy.optimize import curve_fit
import numpy as np
import math
import matplotlib.pyplot as plt
import time

sumf = sum

avg = lambda i: sumf(i) / len(i)

# Patterns to ignore
OUTLIERS = ['1', '11', '101', '111', '11111101']

def sigmoid(x, y0, A, k, x0):
  return y0 + A / (1 + np.exp(-k * (x - x0)))

def P(pattern):
  # Reversible mapping from a pattern to a narual
  return int(pattern, 2)

y0s = []
As = []
ks = []
x0s = []
Ps = []

for root, dirs, files in os.walk('data'):
  # First, transform the data from lists of ints representing the number
  # of flips per trial to a percent chance that an arbitrary coloring
  # of size n is satisfactory

  C = 2  # Known
  pattern = root[len("data/C=00002;pattern=arithmetic("):-len(")")]
  if not pattern or pattern in OUTLIERS:
    print(f'Skipping "{pattern}"')
    if pattern:
      print(f'({int(pattern, 2)})')
    time.sleep(1)
    continue

  xs = []
  ys = []

  for file_loc in files:
    text = open(os.path.join(root, file_loc)).read()

    N = int(file_loc[len("N="):-len(".txt")])

    sum = 0
    count = 0

    for line in text.split("\n"):
      if line:
        sum += int(line) + 1  # Add one for the implicit success trial
        count += 1

    if sum:
      p = 1 - count / sum  # This is the propability
      xs.append(N)
      ys.append(p)

  # Ensure N >= M
  if len(xs) >= 4:
    # Fit to logistic
    (y0, A, k, x0), covariance = curve_fit(sigmoid, xs, ys, p0=[0.5, 0.5, .3 * avg(xs), avg(xs)], maxfev=100000)
    y0s.append(y0)
    As.append(A)
    ks.append(k)
    x0s.append(x0)
    Ps.append(P(pattern))
    print(y0, A, k, x0)

    sample_xs = np.linspace(min(xs), max(xs), 500)
    plt.plot(sample_xs, (y0 + A / (1 + np.exp(-k * (sample_xs - x0)))))

  plt.scatter(xs, ys)
  print(pattern)
  plt.savefig(f'plots/vdw-{pattern}.png', bbox_inches='tight')
  plt.clf()

plt.xlabel("P")
sample_Ps = np.linspace(min(Ps), max(Ps), 500)

def linear(x, m, y0):
  return m * x + y0

def filterdata(Ys, pred):
  resPs = []
  resYs = []
  for i in range(len(Ys)):
    if pred(Ps[i]):
      resPs.append(Ps[i])
      resYs.append(Ys[i])
  return resPs, resYs

def is_power_of_N(x, p):
  if x == 1:
    return True
  if x < 1:
    return False
  return is_power_of_N(x / p, p)

# y0
# linear ?

(m, y0), covariance = curve_fit(linear, Ps, y0s)
plt.plot(sample_Ps, (m * sample_Ps + y0))

plt.ylabel("y0")
plt.scatter(Ps, y0s)
plt.savefig(f'plots/__y0s.png', bbox_inches='tight')
plt.clf()

# A
# linear

plt.ylabel("A")
plt.scatter(Ps, As)
plt.scatter(*filterdata(As, lambda P: is_power_of_N(P + 1, 2)), c='#ff0000')
plt.savefig(f'plots/__As.png', bbox_inches='tight')
plt.clf()

# k

plt.ylabel("k")
plt.scatter(Ps, ks)
plt.savefig(f'plots/__ks.png', bbox_inches='tight')
plt.clf()

# x0

plt.ylabel("x0")
plt.scatter(Ps, x0s)
plt.savefig(f'plots/__x0s.png', bbox_inches='tight')
plt.clf()
