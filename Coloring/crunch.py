import os
import shutil
import json
from scipy.optimize import curve_fit
import numpy as np
import math
import matplotlib.pyplot as plt
import matplotlib
import time

# Make matplotlib faster
matplotlib.use('TkAgg')

def unzip(l):
  return map(list, zip(*l))

def owf(*args, **kwargs):
  loc = args[0]
  if os.path.isfile(loc):
    os.remove(loc)
  else:
    os.makedirs(os.path.dirname(loc), exist_ok=True)
  plt.savefig(*args, **kwargs)
plt.overwritefig = owf

source_dir = "data/arithmetic"
target_dir = "crunched/arithmetic"
if not os.path.isdir(target_dir):
  os.makedirs(target_dir)

avg = lambda i: sum(i) / len(i)

def exponential(x, y0, A, k, x0):
  return y0 - A * np.exp(-k * (x - x0))
def logistic(x, y0, A, k, x0):
  return y0 + A / (1 + np.exp(-k * (x - x0)))

fitting = logistic

# { P => metadata }
p_data = {}

# For each p
for dir in os.listdir(source_dir):
  if not os.path.isdir(os.path.join(source_dir, dir)): continue
  p = int(dir)

  # { N => success_rate }
  percents = {}
  V = None

  # For each N
  for filename in os.listdir(os.path.join(source_dir, dir)):
    if os.path.isdir(os.path.join(source_dir, dir, filename)): continue
    N = int(filename[:-len(".txt")])
    pair = open(os.path.join(source_dir, dir, filename)).read().split("\n")
    attempts = int(pair[0])
    successes = int(pair[1])
    success_rate = successes / attempts

    # We ignore 0% and 100% values because it is known that all
    # x-values below the recorded x have 0% and all x-values above
    # the recorded x have 100%
    if attempts != successes != 0:
      percents[N] = success_rate
    elif attempts == successes:
      V = N

  xs, ys = unzip(percents.items()) if percents else ([], [])

  # set y-axis values
  plt.gca().set_ylim([0, 1])
  plt.suptitle(f"P = {p}")
  plt.xlabel("N")
  plt.ylabel("%")

  # Fit to function if possible
  y0 = A = k = x0 = None
  if len(xs) >= 4:
    #(y0, A, k, x0), covariance = curve_fit(fitting, xs, ys, p0=[max(ys), 1, 1/3, avg(xs)], maxfev=100000)
    (y0, A, k, x0), covariance = curve_fit(fitting, xs, ys, p0=[-.2, 1.2, .3, .3 * avg(xs)], maxfev=100000)
    sample_xs = np.linspace(min(xs), max(xs), 20)
    plt.plot(sample_xs, fitting(sample_xs, y0, A, k, x0))

  plt.scatter(xs, ys)
  loc = os.path.join(target_dir, f"{p:05}-scatter.png")
  plt.overwritefig(loc, bbox_inches='tight')
  print("Scatterplot " + loc + " generated.")
  plt.clf()

  # Save metadata
  meta = {
    "V": V,  # First N with 100% success rate
    "attempts": len(xs),

    "y0": y0,
    "A": A,
    "k": k,
    "x0": x0,
  }
  p_data[p] = meta
  meta_loc = os.path.join(target_dir, f"{p:05}-meta.txt")
  f = open(meta_loc, "w")
  f.write(json.dumps(meta))
  f.close()
  print("Metadata file " + meta_loc + " generated.")

# Now we make graphs out of the metadata

ps = sorted(p_data.keys())
attr_lists = {}
attrs = p_data[ps[0]].keys()
for attr in attrs:
  attr_lists[attr] = []
  for p in ps:
    attr_lists[attr].append(p_data[p][attr])

for attr in attrs:
  ys = attr_lists[attr]

  plt.suptitle(f"P vs {attr}")
  plt.xlabel("P")
  plt.ylabel(attr)

  plt.scatter(ps, ys)
  plot_loc = os.path.join(target_dir, "all", f"{attr}-plot.png")
  plt.overwritefig(plot_loc, bbox_inches='tight')
  print(f"All-plot {plot_loc} generated.")
  plt.clf()
