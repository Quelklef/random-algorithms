import os
import shutil
import json
from scipy.optimize import curve_fit
import numpy as np
import math
import matplotlib.pyplot as plt
import matplotlib
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--skip", help="Skip to metadata parsing", action="store_true")
args = parser.parse_args()

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
  return y0 + A * np.exp(k * (x - x0))
def logistic(x, y0, A, k, x0):
  return y0 + A / (1 + np.exp(-k * (x - x0)))
def monomial(x, y0, A, k, x0):
  return y0 + A * np.power(x - x0, k)

fitting = logistic

# For each p
if not args.skip:
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
      try:
        attempts = int(pair[0])
        successes = int(pair[1])
      except ValueError:
        print(f"WARNING: data in {os.path.join(source_dir, dir, filename)} corrupt; ignoring.")
      else:
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
      #(y0, A, k, x0), covariance = curve_fit(exponential, xs, ys, p0=[max(ys), 1, 1/3, avg(xs)], maxfev=100000)
      (y0, A, k, x0), covariance = curve_fit(logistic, xs, ys, p0=[-.2, 1.2, .3, .3 * avg(xs)], maxfev=100000)
      sample_xs = np.linspace(min(xs), max(xs), 20)
      plt.plot(sample_xs, logistic(sample_xs, y0, A, k, x0))

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
    meta_loc = os.path.join(target_dir, f"{p:05}-meta.txt")
    f = open(meta_loc, "w")
    json.dump(meta, f)
    f.close()
    print("Metadata file " + meta_loc + " generated.")

# Now we make graphs out of the metadata

p_data = {}
for filename in os.listdir(target_dir):
  if not os.path.isfile(os.path.join(target_dir, filename)): continue
  if not filename.endswith("-meta.txt"): continue
  p = int(filename[:-len("-meta.txt")])
  f = open(os.path.join(target_dir, filename))
  p_data[p] = json.loads(f.read())
  f.close()

ps = sorted(p_data.keys())
attr_lists = {}
attrs = p_data[ps[0]].keys()
for attr in attrs:
  attr_lists[attr] = []
  for p in ps:
    attr_lists[attr].append(p_data[p][attr])

def is_power(n, b):
  if n < 1:
    return False
  elif n == 1:
    return True
  return is_power(n / b, b)

for attr in attrs:
  ys = attr_lists[attr]

  plt.suptitle(f"P vs {attr}")
  plt.xlabel("P")
  plt.ylabel(attr)

  plt.scatter(ps, ys)
  # Plot VDW patterns in red
  if attr == "V":
    VDW_ps, VDW_ys = unzip([(p, y) for p, y in zip(ps, ys) if is_power(p + 1, 2)])
    plt.scatter(VDW_ps, VDW_ys, color='red')
    (y0, A, k, x0), covariance = curve_fit(monomial, VDW_ps, VDW_ys, p0=[0, 5, 3, 0], maxfev=10000)

    f = open(os.path.join(target_dir, "all", "A-fit.txt"), "w")
    json.dump({"y0": y0, "A": A, "k": k, "x0": x0}, f)
    f.close()

    sample_ps = np.linspace(min(ps), max(ps), 20, dtype=np.float64)
    plt.plot(sample_ps, monomial(sample_ps, y0, A, k, x0), color='red')
  plot_loc = os.path.join(target_dir, "all", f"{attr}-plot.png")
  plt.overwritefig(plot_loc, bbox_inches='tight')
  print(f"All-plot {plot_loc} generated.")
  plt.clf()
