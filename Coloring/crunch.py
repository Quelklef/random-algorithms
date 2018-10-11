"""
Usage:
  crunch p (metafiles | graph | both) [--for <pred>] [--no-fit] [--out <loc>] [--redo] [--quiet]
  crunch meta [--quiet]

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
import inspect

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

def func_parameters(f):
  return inspect.getargspec(f)[0]

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
all_dir = "crunched/arithmetic/all"
latex_fileloc = "crunched/arithmetic/all/latex.txt"

# Ensure dirs exist
if not os.path.isdir(target_dir):
  os.makedirs(target_dir)
if not os.path.isdir(all_dir):
  os.makedirs(all_dir)

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
def WLstar(x, y0, A, k, x0):
  return y0 + A * ((x * (2 ** (k * (x - x0) - 1))) ** .5)

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
  with open(n_fileloc) as f:
    data = f.read().split("\n")
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

        with open(meta_fileloc, 'w') as f:
          rapidjson.dump(meta, f)
        print("Metadata file " + meta_fileloc + " generated.")

if args["meta"]:
  def get_metadata():
    """Find metadata for all ps"""
    result = []
    for filename in os.listdir(target_dir):
      fileloc = os.path.join(target_dir, filename)
      if not os.path.isfile(fileloc): continue
      if not filename.startswith("meta-"): continue
      with open(os.path.join(target_dir, filename)) as f:
        data = f.read()
      result.append(rapidjson.loads(data))
    return result

  def fit(xs, ys, func, p0, bounds=None):
    """ Fit a curve over some xs and ys and plot it, returning fit params """
    params, covariance = curve_fit(func, xs, ys, p0=p0, maxfev=1000000)
    if not bounds:
      bounds = (min(xs), max(xs))
    sample_xs = np.linspace(*bounds, 200)
    plt.plot(sample_xs, func(sample_xs, *params), color='r', linewidth=1)
    return params

  def is_VDW(d):
    return is_power(d["p"] + 1, 2)

  small = {'s': 2}
  bold = {'c': 'r', 's': 30}

  def validate(data, x_get, y_get):
    """ Discard all x or y values that are None or
    correspond to a y or x value that is None """
    result = []
    for d in data:
      if x_get(d) is not None and y_get(d) is not None:
        result.append(d)
    return result

  def write_all_fig(filename):
    fileloc = os.path.join(all_dir, filename)
    print(f"Writing figure to {fileloc}.")
    plt.overwritefig(fileloc, bbox_inches='tight')

  def simple_scatter(data, x_get, y_get, **kwargs):
    if isinstance(x_get, str):
      x_get = itemgetter(x_get)
    if isinstance(y_get, str):
      y_get = itemgetter(y_get)

    data = validate(data, x_get, y_get)

    xs = list(map(x_get, data))
    ys = list(map(y_get, data))
    plt.scatter(xs, ys, **small)

    return xs, ys

  def VDW_highlight(data, y_attr, highlight_VDW=False):
    """ Highlight the VDW x values on the plot """
    x_get = itemgetter("p")
    y_get = itemgetter(y_attr)
    VDW_data = validate(list(filter(is_VDW, data)), x_get, y_get)
    VDW_xs = list(map(x_get, VDW_data))
    VDW_ys = list(map(y_get, VDW_data))
    plt.scatter(VDW_xs, VDW_ys, **bold)
    return VDW_xs, VDW_ys

  def to_latex(s):
    return ''.join(c for c in s if c.isalpha())

  def make_latex_commands(param_names, param_vals, x_attr, y_attr):
    lines = []
    for pname, pval in zip(param_names, param_vals):
      pval_str =  '{0:.2f}'.format(pval)  # Format float not in scientific notation
      line = "\\newcommand{\\%s}{%s}" % (to_latex(x_attr + y_attr + pname), pval_str)
      lines.append(line)
    return "\n".join(lines) + "\n"

  def VDW_scatter_and_fit(data, y_attr, fit_func, p0):
    """
    Create a graph of p vs y_attr;
    create a duplicate with VDW values highlightes;
    create a duplicate with VDW values fit
    """#
    x_attr = "p"

    plt.suptitle(f"{x_attr} vs {y_attr}")
    plt.xlabel(x_attr)
    plt.ylabel(y_attr)

    xs, ys = simple_scatter(data, x_attr, y_attr)
    write_all_fig(f"{x_attr}-{y_attr}.png")

    VDW_xs, VDW_ys = VDW_highlight(data, y_attr)
    write_all_fig(f"{x_attr}-{y_attr}-highlight.png")

    params = fit(VDW_xs, VDW_ys, fit_func, p0, bounds=(min(xs), max(xs)))
    write_all_fig(f"{x_attr}-{y_attr}-fitted.png")
    plt.clf()

    return make_latex_commands(func_parameters(fit_func)[1:], params, x_attr, y_attr)

  def simple_scatter_write(data, x_attr, y_attr):
    """ Generate a simple scatterplot and write it. """
    plt.suptitle(f"{x_attr} vs {y_attr}")
    plt.xlabel(x_attr)
    plt.ylabel(y_attr)

    simple_scatter(data, x_attr, y_attr)

    write_all_fig(f"{x_attr}-{y_attr}.png")
    plt.clf()

  # Now we make graphs out of the metadata
  data = get_metadata()
  with open(latex_fileloc, 'w') as lf:
    lf.write( VDW_scatter_and_fit(data, "V" , logarithmic, [0 , 100, 2, -1]) )
    lf.write( VDW_scatter_and_fit(data, "y0", linear     , [1 , 1         ]) )
    lf.write( VDW_scatter_and_fit(data, "A" , linear     , [1 , 1         ]) )
    lf.write( VDW_scatter_and_fit(data, "k" , reciprocal , [50, 50        ]) )
    lf.write( VDW_scatter_and_fit(data, "x0", logarithmic, [1 , 1  , 1, -1]) )

    simple_scatter_write(data, "y0", "A")
    simple_scatter_write(data, "x0", "V")

    # kW vs V
    plt.suptitle("kW vs V")
    plt.xlabel("kW")
    plt.ylabel("V")

    data = list(filter(is_VDW, data))

    xs = list(map(lambda d: len(bin(d["p"])) - 2, data))
    ys = list(map(itemgetter("V"), data))

    plt.scatter(xs, ys, **bold)
    plt.overwritefig(os.path.join(all_dir, "kW-V.png"), bbox_inches='tight')

    # kw vs V (fitted)
    param_vals = fit(xs, ys, WLstar, [0, 2, 1, 0])
    write_all_fig("kW-V-fitted.png")
    plt.clf()
    lf.write( make_latex_commands(func_parameters(WLstar), param_vals, "kW", "V") )

    # P vs y0/A
    plt.suptitle("P vs p0/A")
    plt.ylabel("p0/A")
    simple_scatter(data, "p", lambda d: d["y0"] / d["A"] if d["y0"] and d["A"] else None)
    write_all_fig("y0-over-A.png")
    plt.clf()
