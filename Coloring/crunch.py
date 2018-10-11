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
from operator import itemgetter

parser = argparse.ArgumentParser()
parser.add_argument(
  "--graphs",
  help="Make p graphs",
  dest="make_pgraphs",
  action="store_true"
)
parser.add_argument(
  "--fit",
  help="Fit a curve over p-graphs",
  dest="do_fit",
  action="store_true",
)
parser.add_argument(
  "--meta",
  help="Generate metadata and make meta graphs",
  dest="do_meta",
  action="store_true"
)
parser.add_argument(
  "--update",
  help="Regenerate existing p files",
  dest="update_p",
  action="store_true"
)
parser.add_argument(
  "--highlight",
  help="Highlight VDW numbers in all-graphs",
  dest="highlight_vdw_numbers",
  action="store_true",
)
parser.add_argument(
  "--p-pred",
  help="Only do certain ps based on a predicate such as 'p==3' or 'p>100'",
  dest="p_pred",
)
parser.add_argument(
  "--p-filename",
  help="Filename for p, such as '{p}.png' or (the default) 'scatter-{p:05}.png'.",
  dest="p_filename",
)
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
def logarithmic(x, y0, A, k, x0):
  return y0 + A * np.log(k * (x - x0))
def linear(x, y0, A):
  return y0 + A * x
def reciprocal(x, y0, A):
  return y0 + A / x

fitting = logistic

# For each p
if args.make_pgraphs or args.do_meta:
  # Sort simply for aestetic/user experience reasons
  for dir in sorted(os.listdir(source_dir), key=int):
    if not os.path.isdir(os.path.join(source_dir, dir)): continue
    p = int(dir)
    if args.p_pred:
      if not eval(args.p_pred):
        print(f"Skipping p={p}")
        continue

    print(f"Analyzing p={p}")
    meta_loc = os.path.join(target_dir, f"meta-{p:05}.txt")

    if args.make_pgraphs or (args.do_meta and (args.update_p or not os.path.isfile(meta_loc))):
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

      if args.make_pgraphs:
        # set y-axis values
        plt.gca().set_ylim([0, 1])
        plt.suptitle(f"P = {p}; pattern = {p:b}")
        plt.xlabel("N")
        plt.ylabel("%")

      # Fit to function if possible
      y0 = A = k = x0 = None
      if len(xs) >= 4:
        #(y0, A, k, x0), covariance = curve_fit(exponential, xs, ys, p0=[max(ys), 1, 1/3, avg(xs)], maxfev=1000000)
        (y0, A, k, x0), covariance = curve_fit(logistic, xs, ys, p0=[-.2, 1.2, .3, .3 * avg(xs)], maxfev=1000000)

      if args.make_pgraphs:
        loc = os.path.join(target_dir, (args.p_filename or "scatter-{p:05}.png").format(p=p))
        if args.update_p or not os.path.isfile(loc):
          plt.scatter(xs, ys, s=10, zorder=1)
          if args.do_fit and len(xs) >= 4:
            sample_xs = np.linspace(min(xs), max(xs), 200)
            plt.plot(sample_xs, logistic(sample_xs, y0, A, k, x0), color='r', linewidth=1, zorder=2)
          plt.overwritefig(loc, bbox_inches='tight')
          print("Scatterplot " + loc + " generated.")
      plt.clf()

      if args.do_meta and (args.update_p or not os.path.isfile(meta_loc)):
        # Save metadata
        meta = {
          "P": p,
          "V": V,  # First N with 100% success rate
          "attempts": len(xs),

          "y0": y0,
          "A": A,
          "k": k,
          "x0": x0,
        }
        f = open(meta_loc, "w")
        json.dump(meta, f)
        f.close()
        print("Metadata file " + meta_loc + " generated.")

if args.do_meta:
  # Now we make graphs out of the metadata
  data = []
  for filename in os.listdir(target_dir):
    if not os.path.isfile(os.path.join(target_dir, filename)): continue
    if not filename.startswith("meta-"): continue
    p = int(filename[len("meta-"):-len(".txt")])
    f = open(os.path.join(target_dir, filename))
    data.append(json.loads(f.read()))
    f.close()

  def is_power(n, b):
    if n < 1:
      return False
    elif n == 1:
      return True
    return is_power(n / b, b)

  special = (
    lambda p: is_power(p + 1, 2),
    'r',
    20,
  )
  constTrue = lambda d: True
  VDW_only = lambda d: is_power(d["P"] + 1, 2)
  graphs = [
    (
      "P-V.png",  # filename
      "P vs V",  # title
      "P",  # x axis title
      "V",  # y axis title
      itemgetter("P"),  # map dict -> x value
      constTrue,  # filter dict -> bool
      itemgetter("V"),  # map dict -> y value
      special,  # colors (function of X, not dict)
      None, # curve fitting -- (curve, p0)
    ),
    (
      "P-V-fitted.png",
      "P vs V",
      "P",
      "V",
      itemgetter("P"),
      VDW_only,
      itemgetter("V"),
      (constTrue, 'C0', 20),
      (logarithmic, [0, 100, 2, -1]),
    ),
    (
      "kW-V.png",
      "kW vs V",
      "kW",
      "V",
      lambda d: len(bin(d["P"])) - 2,
      VDW_only,
      itemgetter("V"),
      (constTrue, 'r', 20),
      None,
    ),
    (
      "kW-V-fitted.png",
      "kW vs V",
      "kW",
      "V",
      lambda d: len(bin(d["P"])) - 2,
      VDW_only,
      itemgetter("V"),
      (constTrue, 'C0', 20),
      # y0 A k x0
      ((lambda x, y0, A, k, x0: y0 + A * ((x * (2 ** (k * (x - x0) - 1))) ** .5)), [0, 2, 1, 0]),
    ),
    (
      "P-y0.png",
      "P vs y0",
      "P",
      "y0",
      itemgetter("P"),
      constTrue,
      itemgetter("y0"),
      special,
      None,
    ),
    (
      "P-y0-fitted.png",
      "P vs y0",
      "P",
      "y0",
      itemgetter("P"),
      VDW_only,
      itemgetter("y0"),
      (constTrue, 'C0', 20),
      (linear, [1, 1]),
    ),
    (
      "P-A.png",
      "P vs A",
      "P",
      "A",
      itemgetter("P"),
      constTrue,
      itemgetter("A"),
      special,
      None,
    ),
    (
      "P-A-fitted.png",
      "P vs A",
      "P",
      "A",
      itemgetter("P"),
      VDW_only,
      itemgetter("A"),
      (constTrue, 'C0', 20),
      (linear, [1, 1]),
    ),
    (
      "P-k.png",
      "P vs k",
      "P",
      "k",
      itemgetter("P"),
      constTrue,
      itemgetter("k"),
      special,
      None,
    ),
    (
      "P-k-fitted.png",
      "P vs k",
      "P",
      "k",
      itemgetter("P"),
      VDW_only,
      itemgetter("k"),
      (constTrue, 'C0', 20),
      #(logarithmic, [0, -1, 1, 0]),
      (reciprocal, [50, 50]),
      #(exponential, [0, .1, -1, 10]),
      #None,
    ),
    (
      "P-x0.png",
      "P vs x0",
      "P",
      "x0",
      itemgetter("P"),
      constTrue,
      itemgetter("x0"),
      special,
      None,
    ),
    (
      "P-x0-fitted.png",
      "P vs x0",
      "P",
      "x0",
      itemgetter("P"),
      VDW_only,
      itemgetter("x0"),
      (constTrue, 'C0', 20),
      (logarithmic, [1, 1, 1, -1]),
    ),
    (
      "y0-A.png",
      "y0 vs A",
      "y0",
      "A",
      itemgetter("y0"),
      constTrue,
      itemgetter("A"),
      None,
      None,
    ),
    (
      "x0-V.png",
      "x0 vs V",
      "x0",
      "V",
      itemgetter("x0"),
      constTrue,
      itemgetter("V"),
      None,
      None,
    ),
    (
      "y0-over-A.png",
      "P vs y0/A",
      "P",
      "y0/A",
      itemgetter("P"),
      constTrue,
      lambda d: d["y0"] / d["A"] if d["y0"] and d["A"] else None,
      None,
      None,
    ),
  ]

  os.makedirs(os.path.join(target_dir, "all"), exist_ok=True)
  for filename, title, x_label, y_label, x_get, filter_f, y_get, special, fitting in graphs:
    print("######", filename)
    plt.suptitle(title)

    filtered_data = list(filter(filter_f, data))
    filtered_data = list(filter(
      # Can be None if unable to fit curve due to <4 values
      lambda d: x_get(d) is not None and y_get(d) is not None
      , filtered_data
    ))
    xs = np.array(list(map(x_get, filtered_data)))
    ys = np.array(list(map(y_get, filtered_data)))
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.scatter(
      xs,
      ys,
      s=1,
    )

    if args.highlight_vdw_numbers and special:
      sp_predicate, sp_color, sp_size = special
      sp_xs, sp_ys = unzip([(x, y) for x, y in zip(xs, ys) if sp_predicate(x)])
      plt.scatter(
        np.array(sp_xs),
        np.array(sp_ys),
        color=sp_color,
        s=sp_size,
      )

    if fitting:
      fit_func, p0 = fitting
      sample_xs = np.linspace(min(xs), max(xs), 200)
      params, covariance = curve_fit(fit_func, xs, ys, p0=p0, maxfev=1000000)
      print(params)
      #print(covariance)
      plt.plot(sample_xs, fit_func(sample_xs, *params), color='r', linewidth=1, zorder=2)

    plot_loc = os.path.join(target_dir, "all", filename)
    plt.overwritefig(plot_loc, bbox_inches='tight')
    print(f"All-plot {plot_loc} generated.")
    plt.clf()

