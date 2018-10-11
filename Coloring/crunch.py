"""
Usage:
  crunch p (metafiles | graph | both) [--for <pred>] [--no-fit] [--out <loc>] [--redo] [--quiet]
  crunch meta [--no-highlight] [--quiet]

Options:
  -h --help        Show this screen.
  --quiet          No console output.

  p                Work on ps.
  metafiles        Generate metafiles.
  graph            Generate graphs.
  both             Generate metafiles and graphs.
  --for <pred>     Only analyze p values matching the predicate, e.g. 'p>100'.
  --no-fit         Do not fit curves over p-graphs.
  --out <loc>      Output graphs to filename [default: scatter-{p}.png].
  --redo           Overwrite, instead of skipping, existing files.

  meta             Generate metagraphs
  --no-highlight   Do not highlight VDW numbers in meta-graphs.
"""

import os
import rapidjson
from scipy.optimize import curve_fit
import numpy as np
import math
import matplotlib.pyplot as plt
import matplotlib
from docopt import docopt
from operator import itemgetter

args = docopt(__doc__)

# Make matplotlib faster
matplotlib.use('TkAgg')

# Util functions

if args["--quiet"]:
  # lol
  print = lambda *args, **kwargs: None
 
def unzip(l):
  return map(list, zip(*l))

def avg(i):
  return sum(i) / len(i)

def is_power(n, b):
  if n < 1:
    return False
  elif n == 1:
    return True
  return is_power(n / b, b)

# Define plt.overwritefig to be plt.savefit, but overwriting
def owf(*args, **kwargs):
  loc = args[0]
  if os.path.isfile(loc):
    os.remove(loc)
  else:
    os.makedirs(os.path.dirname(loc), exist_ok=True)
  plt.savefig(*args, **kwargs)
plt.overwritefig = owf

# Constants
source_dir = "data/arithmetic"
target_dir = "crunched/arithmetic"
# Ensure target_dir exists
if not os.path.isdir(target_dir):
  os.makedirs(target_dir)

# Define fitting curves
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

def iter_ps():
  """Generate (p value, dirloc) for all ps in integer order"""
  for dirname in sorted(os.listdir(source_dir), key=int):
    dirloc = os.path.join(source_dir, dirname)
    if not os.path.isdir(dirloc): continue
    p = int(dirname)
    yield (p, dirloc)

def iter_ns(p_dirloc):
  """Generate (N value, fileloc) for all Ns for some given p"""
  for filename in os.listdir(p_dirloc):
    fileloc = os.path.join(p_dirloc, filename)
    if not os.path.isfile(fileloc): continue
    N = int(filename[:-len(".txt")])
    yield (N, fileloc)

def read_n_file(n_fileloc):
  """Parse a {n}.txt file"""
  data = open(n_fileloc).read().split("\n")
  try:
    attempts = int(data[0])
    successes = int(data[1])
  except ValueError:
    print(f"WARNING: data in {os.path.join(source_dir, dir, filename)} corrupt; ignoring.")
    raise
  else:
    return (successes, attempts)

# For each p
if args["p"]:
  # Sort simply for aestetic/user experience reasons
  for p, p_dirloc in iter_ps():
    if args["--for"] and not eval(args["--for"]):
      print(f"Skipping p={p}")
      continue
    else:
      print(f"Analyzing p={p}")

    meta_fileloc = os.path.join(target_dir, f"meta-{p:05}.txt")
    graph_fileloc = os.path.join(target_dir, args["--out"].format(p=f"{p:05}"))

    if args["--redo"] or not os.path.isfile(meta_fileloc):
      # { N => success_rate }
      percents = {}
      V = None

      # For each N
      for n, n_fileloc in iter_ns(p_dirloc):
        try:
          successes, attempts = read_n_file(n_fileloc)
        except ValueError:
          continue

        success_rate = successes / attempts

        # We ignore 0% and 100% values because it is known that all
        # x-values below the recorded x have 0% and all x-values above
        # the recorded x have 100%
        if attempts != successes != 0:
          percents[n] = success_rate
        elif attempts == successes:
          V = n

      xs, ys = unzip(percents.items()) if percents else ([], [])

      #plt.gca().set_ylim([0, 1])
      plt.suptitle(f"P = {p}; pattern = {p:b}")
      plt.xlabel("N")
      plt.ylabel("%")

      # Fit to function if possible
      can_fit = len(xs) >= 4
      y0 = A = k = x0 = None
      if can_fit:
        (y0, A, k, x0), covariance = curve_fit(logistic, xs, ys, p0=[-.2, 1.2, .3, .3 * avg(xs)], maxfev=1000000)

      if (args["graph"] or args["both"]) and (args["--redo"] or not os.path.isfile(graph_fileloc)):
        plt.scatter(xs, ys, s=10)
        if not args["--no-fit"] and can_fit:
          sample_xs = np.linspace(min(xs), max(xs), 200)
          plt.plot(sample_xs, logistic(sample_xs, y0, A, k, x0), color='r', linewidth=1)
        plt.overwritefig(graph_fileloc, bbox_inches='tight')
        print("Scatterplot " + graph_fileloc + " generated.")
      plt.clf()

      if (args["metafiles"] or args["both"]) and (args["--redo"] or not os.path.isfile(meta_fileloc)):
        # Save metadata
        meta = {
          "p": p,
          "V": V,  # First N with 100% success rate
          "attempts": len(xs),

          "y0": y0,
          "A": A,
          "k": k,
          "x0": x0,
        }

        f = open(meta_fileloc, "w")
        rapidjson.dump(meta, f)
        f.close()
        print("Metadata file " + meta_fileloc + " generated.")

## META GRAPHS ##

def iter_meta():
  """Find metadata for all ps"""
  for filename in os.listdir(target_dir):
    fileloc = os.path.join(target_dir, filename)
    if not os.path.isfile(fileloc): continue
    if not filename.startswith("meta-"): continue
    f = open(os.path.join(target_dir, filename))
    data = f.read()
    f.close()
    yield rapidjson.loads(data)

metagraphs = []

def metagraph(saveloc):
  def wrapper(f):
    f._saveto = saveloc
    metagraphs.append(f)
    return f
  return wrapper

def fit(xs, ys, func, p0):
  params, covariance = curve_fit(func, xs, ys, p0=p0, maxfev=1000000)
  sample_xs = np.linspace(min(xs), max(xs), 200)
  plt.plot(sample_xs, func(sample_xs, *params), color='r', linewidth=1)

def is_VDW(d):
  return is_power(d["p"] + 1, 2)

normal = {'c': 'C0', 's': 20}
bold = {'c': 'r', 's': 40}

def validate(data, x_get, y_get):
  result = []
  for d in data:
    if x_get(d) is not None and y_get(d) is not None:
      result.append(d)
  return result

def simple_scatter(data, x_get, y_get):
  if isinstance(x_get, str) and isinstance(y_get, str):
    plt.suptitle(f"{x_get} vs {y_get}")
  if isinstance(x_get, str):
    plt.xlabel(x_get)
    x_get = itemgetter(x_get)
  if isinstance(y_get, str):
    plt.ylabel(y_get)
    y_get = itemgetter(y_get)

  data = validate(data, x_get, y_get)

  xs = list(map(x_get, data))
  ys = list(map(y_get, data))
  plt.scatter(xs, ys, **normal)

def VDW_scatter(data, y_attr, highlight_VDW=False):
  plt.suptitle(f"p vs {y_attr}")

  x_get = itemgetter("p")
  y_get = itemgetter(y_attr)
  data = validate(data, x_get, y_get)

  xs = list(map(x_get, data))
  ys = list(map(y_get, data))
  plt.scatter(xs, ys, **normal)

  if not args["--no-highlight"]:
    VDW_data = list(filter(is_VDW, data))
    VDW_xs = list(map(itemgetter("p"), data))
    VDW_ys = list(map(itemgetter(y_attr), data))
    plt.scatter(VDW_xs, VDW_ys, **bold)

  return VDW_xs, VDW_ys

@metagraph("P-V.png")
def graph_PvsV(data):
  return VDW_scatter(data, "V")

@metagraph("P-V-fitted.png")
def graph_PvsV_fitted(data):
  fit(*graph_PvsV(data), logarithmic, [0, 100, 2, -1])

@metagraph("kW-V.png")
def graph_kWvsV(data):
  plt.suptitle("kW vs V")
  plt.xlabel("kW")
  plt.ylabel("V")

  data = list(filter(is_VDW, data))

  xs = list(map(lambda d: len(bin(d["p"])) - 2, data))
  ys = list(map(itemgetter("V"), data))

  plt.scatter(xs, ys, **bold)

  return xs, ys

@metagraph("kW-V-fitted.png")
def graph_kWvsV_fitted(data):
  f = (lambda x, y0, A, k, x0: y0 + A * ((x * (2 ** (k * (x - x0) - 1))) ** .5))
  fit(*graph_kWvsV(data), f, [0, 2, 1, 0])

@metagraph("P-y0.png")
def graph_Pvsy0(data):
  return VDW_scatter(data, "y0")

@metagraph("P-y0-fitted.png")
def graph_Pvsy0_fitted(data):
  fit(*graph_Pvsy0(data), linear, [1, 1])

@metagraph("P-A.png")
def graph_PvsA(data):
  return VDW_scatter(data, "A")

@metagraph("P-A-fitted.png")
def graph_PvsA_fitted(data):
  fit(*graph_PvsA(data), linear, [1, 1])

@metagraph("P-k.png")
def graph_Pvsk(data):
  return VDW_scatter(data, "k")

@metagraph("P-k-fitted.png")
def graph_Pvsk_fitted(data):
  fit(*graph_Pvsk(data), reciprocal, [50, 50])

@metagraph("P-x0.png")
def graph_Pvsx0(data):
  return VDW_scatter(data, "x0")

@metagraph("P-x0-fitted.png")
def graph_Pvsx0_fitted(data):
  fit(*graph_Pvsx0(data), logarithmic, [1, 1, 1, -1])

@metagraph("y0-A.png")
def graph_y0vsa(data):
  simple_scatter(data, "y0", "A")

@metagraph("x0-V.png")
def graph_x0vsV(data):
  simple_scatter(data, "x0", "V")

@metagraph("y0-over-A.png")
def graph_Pvsy0overA(data):
  plt.suptitle("P vs p0/A")
  plt.ylabel("p0/A")
  simple_scatter(data, "p", lambda d: d["y0"] / d["A"] if d["y0"] and d["A"] else None)

if args["meta"]:
  # Now we make graphs out of the metadata
  data = list(iter_meta())

  os.makedirs(os.path.join(target_dir, "all"), exist_ok=True)
  for graph in metagraphs:
    graph(data)

    plot_filename = graph._saveto
    plot_fileloc = os.path.join(target_dir, "all", plot_filename)
    plt.overwritefig(plot_fileloc, bbox_inches='tight')
    print(f"All-plot {plot_fileloc} generated.")
    plt.clf()

