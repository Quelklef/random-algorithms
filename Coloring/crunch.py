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
    meta_loc = os.path.join(target_dir, f"{p:05}-meta.txt")

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
        plt.suptitle(f"P = {p}")
        plt.xlabel("N")
        plt.ylabel("%")

      # Fit to function if possible
      y0 = A = k = x0 = None
      if len(xs) >= 4:
        #(y0, A, k, x0), covariance = curve_fit(exponential, xs, ys, p0=[max(ys), 1, 1/3, avg(xs)], maxfev=1000000)
        (y0, A, k, x0), covariance = curve_fit(logistic, xs, ys, p0=[-.2, 1.2, .3, .3 * avg(xs)], maxfev=1000000)
        if args.make_pgraphs and args.do_fit:
          sample_xs = np.linspace(min(xs), max(xs), 20)
          plt.plot(sample_xs, logistic(sample_xs, y0, A, k, x0), color='r')

      if args.make_pgraphs:
        loc = os.path.join(target_dir, f"{p:05}-scatter.png")
        if args.update_p or not os.path.isfile(loc):
          plt.scatter(xs, ys, s=4)
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
    if not filename.endswith("-meta.txt"): continue
    p = int(filename[:-len("-meta.txt")])
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
  graphs = [
    (
      "P-V.png",
      "P vs V",
      "P",
      "V",
      itemgetter("P"),
      itemgetter("V"),
      special,
    ),
    (
      "P-y0.png",
      "P vs y0",
      "P",
      "y0",
      itemgetter("P"),
      itemgetter("y0"),
      special,
    ),
    (
      "P-A.png",
      "P vs A",
      "P",
      "A",
      itemgetter("P"),
      itemgetter("A"),
      special,
    ),
    (
      "P-k.png",
      "P vs k",
      "P",
      "k",
      itemgetter("P"),
      itemgetter("k"),
      special,
    ),
    (
      "P-x0.png",
      "P vs x0",
      "P",
      "x0",
      itemgetter("P"),
      itemgetter("x0"),
      special,
    ),
    (
      "y0-A.png",
      "y0 vs A",
      "0",
      "A",
      itemgetter("y0"),
      itemgetter("A"),
      None,
    ),
    (
      "x0-V.png",
      "x0 vs V",
      "x0",
      "V",
      itemgetter("x0"),
      itemgetter("V"),
      None,
    ),
  ]

  os.makedirs(os.path.join(target_dir, "all"), exist_ok=True)
  for filename, title, x_label, y_label, x_get, y_get, special in graphs:
    plt.suptitle(title)

    xs = np.array(list(map(x_get, data)))
    ys = np.array(list(map(y_get, data)))
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

    plot_loc = os.path.join(target_dir, "all", filename)
    plt.overwritefig(plot_loc, bbox_inches='tight')
    print(f"All-plot {plot_loc} generated.")
    plt.clf()

#    plt.scatter(
#      *unzip([(p, y) for p, y in zip(ps, ys) if is_power(p + 1, 2)]),
#      color='red',
#      s=15,
#    )

