"""
Usage:
  paper [--appendix]

Options:
  -h --help    Show help
  --appendix   Generate appendix
"""

import os
import rapidjson as json
from scipy.optimize import curve_fit
import numpy as np
import math
import matplotlib.pyplot as plt
import matplotlib
from docopt import docopt
from operator import itemgetter
import inspect
from statistics import mean
from time import sleep

args = docopt(__doc__)

# Make matplotlib faster
matplotlib.use('TkAgg')

# Constants
source_dir = "data/arithmetic"
target_dir = "crunched/arithmetic"

if not os.path.isdir(target_dir):
  os.makedirs(target_dir)

# Output to the LaTeX file
output_parts = []
paper_fileloc = "paper.tex"

def unzip(xss):
  return list(map(list, zip(*xss)))

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

def is_power(n, b):
  if n < 1:
    return False
  elif n == 1:
    return True
  return is_power(n / b, b)
def is_VDW(d):
  return is_power(d["p"] + 1, 2)

def iter_ps():
  """Generate (p value, dirloc) for all ps in integer order"""
  # Sort simply for aestetic/user experience reasons
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

# Map p (as string b.c json requires string keys)
# to metadata
data = {}

# First, read known data
data_fileloc = os.path.join(target_dir, "data.json")
if os.path.isfile(data_fileloc):
  with open(data_fileloc, 'r') as f:
    print(f"Reading from {data_fileloc}.")
    try:
      data = json.load(f)
    except ValueError:
      print(f"File corrupt; starting from scratch.")
sleep(1)

# For each p
for p, p_dirloc in iter_ps():
  if str(p) in data:
    print(f"Skipping data generation for p={p}.")
    continue

  xs = []
  ys = []
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
      xs.append(n)
      ys.append(successes / attempts)
    elif attempts == successes:
      V = n

  data[str(p)] = {
    "xs": xs,
    "ys": ys,
    "p": p,
    "V": V,
  }
  print(f"Generating data for p={p}.")

# Now we fit all ps to a logistic curve
for p_str, meta in data.items():
  p = int(p_str)
  if "y0" in meta and "A" in meta and "k" in meta and "x0" in meta:
    print(f"Skipping data extension for p={p}.")
    continue

  xs = meta["xs"]
  ys = meta["ys"]

  # Fit to function if possible
  can_fit = len(xs) >= 4
  y0 = A = k = x0 = None
  if can_fit:
    (y0, A, k, x0), covariance = curve_fit(logistic, xs, ys, p0=[-.2, 1.2, .3, .3 * mean(xs)], maxfev=1000000)

  meta.update({
    "y0": y0,
    "A": A,
    "k": k,
    "x0": x0
  })
  print(f"Data extended for p={p}.")

# Now weite all this known data back out
with open(data_fileloc, 'w') as f:
  json.dump(data, f)
  print(f"{data_fileloc} rewritten.")
sleep(1)

vals = data.values()

def specify(template, **context):
  context = context or globals()
  s = 'f"""' + (template
    .replace("{", "{{")
    .replace("}", "}}")
    .replace("\\", "\\\\")
    .replace("[[", "{")
    .replace("]]", "}") ) + '"""'
  return eval(s, context)

def echo(s):
  output_parts.append(specify(s))

def fit(xs, ys, func, p0, bounds=None):
  """ Fit a curve over some xs and ys and plot it, returning fit params """
  params, covariance = curve_fit(func, xs, ys, p0=p0, maxfev=1000000)
  if not bounds:
    bounds = (min(xs), max(xs))
  sample_xs = np.linspace(*bounds, 200)
  plt.plot(sample_xs, func(sample_xs, *params), color='r', linewidth=1)
  return params

def validate(data, x_get, y_get):
  """ Discard all x or y values that are None or
  correspond to a y or x value that is None """
  result = []
  for d in data:
    if x_get(d) is not None and y_get(d) is not None:
      result.append(d)
  return result

bold = {'c': 'r', 's': 30}
small = {'s': 4}

def graph(xs, ys, x_label, y_label, *, title=None, filename=None, fit_to=None, style={}, keep=False):
  fileloc = os.path.join(target_dir, filename or f"{x_label}-{y_label}{'-fitted' if fit_to else ''}.png")

  plt.suptitle(title or f"{x_label} vs {y_label}")
  plt.xlabel(x_label)
  plt.ylabel(y_label)

  plt.scatter(xs, ys, **style)
  params = None
  if fit_to:
    params = fit(xs, ys, *fit_to)
  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  if not keep:
    plt.clf()

  if fit_to:
    return fileloc, params
  return fileloc

def pgraph(p, fitted=False):
  """ Return fileloc, never fitting params """
  xs = data[str(p)]["xs"]
  ys = data[str(p)]["ys"]

  if fitted and len(xs) >= 4:  # required for fitting
    fit_to=(logistic, [-0.2, 1.2, 0.3, 0.3 * mean(xs)])
  else:
    fit_to = None

  if fitted:
    filename = f"scatter-{p:08}-fitted.png"
  else:
    filename = f"scatter-{p:08}.png"

  fileloc = os.path.join(target_dir, filename)
  if os.path.isfile(fileloc):
    print(f"Not generating {fileloc} as it already exists.")
  else:
    graph(xs, ys, "N", "%", title=f"p ={p}; pattern = {p:b}", filename=filename, fit_to=fit_to)

  return fileloc

def metagraph(x_get, y_get, **kwargs):
  if isinstance(x_get, str):
    kwargs["x_label"] = x_get
    x_get = itemgetter(x_get)
  if isinstance(y_get, str):
    kwargs["y_label"] = y_get
    y_get = itemgetter(y_get)

  validated = validate(vals, x_get, y_get)
  return graph(list(map(x_get, validated)), list(map(y_get, validated)), style=small, **kwargs)

VDW_vals = list(filter(is_VDW, vals))

def graphVDW(x_attr, y_attr, fit_to, bounds=None):
  x_get = itemgetter(x_attr)
  y_get = itemgetter(y_attr)

  validated = validate(VDW_vals, x_get, y_get)

  xs = list(map(x_get, validated))
  ys = list(map(y_get, validated))
  plt.scatter(xs, ys, **bold)

  if fit_to:
    fit_fun, p0 = fit_to

    xs_nonVDW = list(map(x_get, validate(vals, x_get, y_get)))
    bounds = (min(xs_nonVDW), max(xs_nonVDW))
    params = fit(xs, ys, fit_fun, p0, bounds=bounds)

  filename = f"{x_attr}-{y_attr}-VDW.png"
  fileloc = os.path.join(target_dir, filename)
  plt.savefig(fileloc)
  plt.clf()

  if fit_to:
    return fileloc, params
  return fileloc

def img_latex(fileloc):
  return specify(r"\includegraphics[width=2.6in]{[[ fileloc ]]}", fileloc=fileloc)

def params_latex(f, params):
  param_names = inspect.getargspec(f)[0]

  result = r"\begin{tabular}{c|l}"
  lines = []
  for pname, param in zip(param_names, params):
    lines.append(f"${pname}$ & ${param}$")
  result += r"\\".join(lines)
  result += r"\end{tabular}"

  return result

echo(r"""
\documentclass{article}
\usepackage[utf8]{inputenc}
\usepackage{mathtools}

\title{Empirically Deriving an Approximation for the Van der Waerden Function $W(c,k)$ at $c=2$.}
\author{Eli Maynard, Merlin Maynard}
\date{October 2018}

\usepackage{natbib}
\usepackage{graphicx}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage{algorithm}
\usepackage[noend]{algpseudocode}
\usepackage{bm}

\usepackage{amsthm}
\usepackage{thmtools}
\usepackage{enumitem} % To avoid "Too deeply nested error"
\usepackage{mdframed}

\usepackage{setspace}
\linespread{2}

\usepackage[a4paper, total={6in, 9in}]{geometry}

\setlength{\parskip}{\baselineskip}

\begin{document}

\maketitle

\newpage

\begin{abstract}
We programmatically generated and then analyzed data to find an approximation function for the Van der Waerden function $W(c,k)$ for $c=2$. Data generated were the probabilities for some arbitrary $c$-coloring of size $n$ to contain a monochromatic arithmetic subset of size $k$. Two approaches were taken to approximate $W(2, k)$. First, we found the first $n$ for each $k$ to result in a 100\% probability; approximating this $n$ for a given $k$ is approximating $W(2, k)$. Second, we derived a function approximating, for some $k$ and $n$, the probability that an arbitrary 2-coloring of size $n$ contains a monochromatic subsequence of size $k$. Solving to find the $n$ for which the probability is 100\%, we get an approximation for $W(2, k)$.

In fact, we dealt with (a subset of) ``patterns of $p$'', which is a generalization of monochromatic arithmetic subsequences of size $k$ in which one or more elements may be missing. Data were generated regarding patterns, but much less analysis was done in comparison to the data regarding monochromatic arithmetic subsequences.
\end{abstract}

\newpage

\section{Introduction}

\subsection{$c$-Colorings}

A \textit{c-coloring} of size $n$ is a sequence of $n$ elements, where each elements is one of $c$ distinct items, or ``colors''. For instance, a 3-coloring of size $4$ may be
$$\phantom{.}\text{Red Red Blue Purple}.$$

In this paper, $c$ will never exceed $9$, so $c$-colorings will be represented as a number in which each digit corresponds to one color. The previous coloring would be written as just
$$\phantom{,}0012;$$
$0$ for $\text{Red}$, $1$ for $\text{Blue}$, and $2$ for $\text{Purple}$.

\subsection{Monochromatism and Monochromatic Arithmetic Subsequences}

A \textit{monochromatic arithmetic subsequence} of size $k$, or \textit{MAS(k)}\footnote{Referred to in some other texts a \textit{size-}$k$ \textit{arithmetic progression}}, is a selection of items from a $c$-coloring such that all items are the same distance apart and the same color. For instance:
\begin{align*}
    \text{Coloring: }& 2302310311 \\
    \text{MAS($3$): }& \text{\phantom{2}3\phantom{00}3\phantom{00}3\phantom{00}}
\end{align*}
The indicies of the $3$s are $1, 3, \text{and } 5,$ respectively. Since $5 - 3 = 3 - 1 = 2$, the subsequence is arithmetic; since $3 = 3 = 3$, it is monochromatic; therefore, it is a MAS.

\subsection{Van der Waerden's Theorem}

Van der Waerden's Theorem states that
$$\forall k,c \in \mathbb{N}, \exists n \in \mathbb{N} \mid \forall c\text{-coloring } C\text{ of size } n, C \text{ has some MAS} (k)
$$
\noindent
The smallest satisfactory $n$ for a given $c, k$ is denoted $W(c, k)$.

That is, given a number of colorings $c$ and subsequence size $k$, there exists some $W(c, k)$; any $c$-coloring of the size $W(c, k)$ has a monochromatic arithmetic subsequence of size $k$. Furthermore, this property doesn't hold for any natural less than $W(c, k)$.

Consider an example. Choose a number... Unfortunately, since this is a paper, I cannot know the number you chose. I'll assume it's 10. So let $k=10$. Then consider the natural numbers $\mathbb{N}$ in which we classify each number as either a prime or a composite. Van der Waerden's theorem guarantees that we can always find $k=10$ numbers evenly spaced which are either all prime or all composite.

In fact, Van der Waerden's Theorem is even more general. We can let $k$ be any number, and we can split the naturals into any number $c$ of partitionings and always find $k$ evenly-spaced numbers in a row which are all in the same partition. Furthermore, Van der Waerden's theorem says that you don't need \textit{all} the naturals, just ``enough''. How much is ``enough'' is unknown in general and is denoted by the function $W(c,k)$.

This is Van der Warden's theorem. But why do we care? Why do we care about approximating $W(c,k)$? According to William Gasarch of the University of Maryland, ``There are NO applications of [Van der Waerden's] theorem.''

Note that, as well as colorings smaller than $W(c,k)$ \textit{not} being guaranteed a MAS($k$) (due to $W(c,k)$ being the minimal value), all colorings bigger than $W(c,k)$ \textit{are} guaranteed a MAS($k$). This is because all colorings larger than $W(c,k)$ contain a coloring of the size $W(c,k)$, which has a guaranteed MAS($k$). Thus, $W(c,k)$ ``splits'' $\mathbb{N}$ into two contiguous sections: numbers for which $c$-colorings of that size are not guaranteed a MAS($k$), and numbers for which $c$-colorings of that size are guaranteed have a MAS($k$).

\subsection{A Lower Bound for $W(c, k)$}

Since $\mathbb{N}$ is ``split'' into the ``haves'' and ``have-nots'', finding a lower bound for $W(c, k)$ may be accomplished by finding a function $f \mid \forall c, k\in \mathbb{N}, \exists c$-coloring $C$ of size $f(c, k) \mid C$ has no MAS($k$); since $f$ produces only have-nots, it must be a lower bound. Thus, we attempt to find such an $f$:

The goal of the proof is to, given some $c$ and $k$, find a $B$ and $n$ for which:
$$ \text{\#$c$-colorings of size $n$ with some MAS($k$)} \leq B < \text{\#$c$-colorings of size $n$} $$
for if this is true, then so is
$$ \text{\#$c$-colorings of size $n$ with some MAS($k$)} < \text{\#$c$-colorings of size $n$} $$
and therefore there must be a $c$-coloring of size $n$ with no MAS($k$).

The number of $c$-colorings of size $n$ is
$$\phantom{.}c^n.$$

Upper bounding the number of possible $c$-colorings of size $n$ that contain a MAS($k$) is not so easy. To find $B$, consider the process of choosing some $c$-coloring of size $n$ that contains a MAS($k$). It would look like:
\begin{align*}
    & \text{1. Choose the starting point $p_0$ for the MAS($k$)} \\
    & \text{2. Choose the distance between each item of the MAS($k$)} \\
    & \text{3. Choose the color of the items in the MAS($k$)} \\
    & \text{4. Choose the colors of the items not in the MAS($k$)}
\end{align*}
If we can find how many choices there are in each step, then, assuming decisionsv are made independently of each other, according to the combinatorical product principle, the total number of choices will be the product of these numbers.

Step (1.) has $n-k+1$ options, but the arithmetic is easier (and still sufficient) by choosing the upper bound $n$. Step (2.) has $\lfloor(n - p_0) / k\rfloor$ choices (if colorings are 1-indexed), but the bound must be independent of other variables, so we choose the bound $n/k$. Step (3.) has $c$ choices, one for each color. Step (4.) has $c^{n-k}$ choices, $c$ choices of color for each $n-k$ items left. Thus, the bound on total number of possibilities is:
$$ B = n\cdot \frac{n}{k}\cdot c\cdot c^{n-k} = \frac{n^2 \cdot c^{n-k+1}}{k} $$

Since we constructed $B$ to be an upper bound, we know that $\text{\#$c$-colorings of size $n$ with some MAS($k$)} \leq B$. All we need is to find an $n$ for which $B < \#\text{$c$-colorings of size $n$}$. We may do this by working backwards:
\begin{align*}
    B &< \#\text{$c$-colorings of size $n$} \\
    \frac{n^2 \cdot c^{n-k+1}}{k} &< c^n \\
    n^2 \cdot c^{n-k+1} &< k\cdot c^n \\
    n^2 \cdot c^{1-k} &< k \\
    n^2 &< k\cdot c^{k-1} \\
    \lvert n \rvert &< \sqrt{k\cdot c^{k-1}}
\end{align*}

Thus, given a $c$ and $k$, choose $n \in \mathbb{N} \mid n<\sqrt{k \cdot c^{k-1}}$. Then $\exists c$-coloring $C$ of size $n$ that contain no MAS($k$). Therefore, $W_L(c, k) = \big\lfloor \sqrt{k \cdot c^{k-1}} \big\rfloor - 1$ is a lower bound of $W(c,k)$.

\subsection{Patterns}

Van der Waerden's theorem concerns only MAS($k$)s, but our research deals with a superset of these, which we call patterns. Instead
of only looking for arithmetic subsequences, of the form:
$$\phantom{,}a, a+d, a+2d, a+3d, ..., a+(k-1)d,$$
we consider arithmetic sequences with 0 or more items missing. So, consider $c=2, k=5, n=20$. Given a 2-coloring
of size 20, instead of looking for MAS(5)s, of the form
$$\phantom{,}a, a+d, a+2d, a+3d, a+4d,$$
we consider subsequences such as:
\begin{gather*}
a, a+d, a+2d, a+3d, a+4d \\
a, a+d, \phantom{a+2d,}a+3d, a+4d \\
a, \phantom{a+d,}\phantom{a+2d,}a+3d, \phantom{a+4d} \\
a, a+d, a+2d, \phantom{a+3d,}a+4d \\
\phantom{a,} a+d, \phantom{a+2d,}\phantom{a+3d,}a+4d \\
\phantom{.}a, \phantom{a+d,}\phantom{a+2d,}\phantom{a+3d,}a+4d .
\end{gather*}

When both the first and last elements, $a$ and $a+(k-1)d$, respectively, are present, the pattern acts as expected. Otherwise, there is a slight complication. Consider the patterns $P_0 = ``a, a+d$'' and $P_1 = ``a, a+d, +a2d$ but with the $a+2d$ element missing'', and the coloring $C=3434$. Then For $a=1, d=2$, $P_0$ is $1, 3$; $C_1 = C_3 = 4$, so $P_0$ describes a monochromatic subset of $C$. $P_1$ would, too, except that the $a+2d$ element is $5$, which is out of the range of $C$ (that is, $\nexists C_5$), so $P_1$ cannot be applied at all to $C$.

Patterns are assigned a value ``$p$'', which is essentially an invertible encoding of the pattern. In this paper, all patterns include the first element $a$; therefore, since we only consider when $c=2$, may be encoded as a binary number of length $k$; a $1$ denotes an element ``retained'', and a $0$ denotes an element ``ommitted''. Thus, we define the $p$ of a pattern to be the integer value of the binary number corresponding to that pattern. For instance,
\begin{align*}
    \text{pattern} &= a, a+d, \phantom{a+2d,} a+3d, \phantom{a+4d,} a+5d \\
    \text{binary encoding} &= \hspace{1pt}1 \hspace{14pt}1 \hspace{23pt}0 \hspace{25pt}1 \hspace{26pt}0 \hspace{25pt}1 \\
    p = \text{value of binary number} &= 53
\end{align*}
The point of missing end elements comes into play here, as well. Consider another example:
\begin{align*}
    \text{pattern} &= a, \phantom{a+d}, a+2d, a+3d \text{ but with the $a+3d$ element missing} \\
    \text{binary encoding} &= \hspace{1pt}1 \hspace{14pt}0 \hspace{26pt}1 \hspace{25pt}0 \text{ because $a+3d$ is missing} \\
    p = \text{value of binary number} &= 10
\end{align*}
Note that this is different from the $p$ of $a, a+2d$, for which the binary is $101$ and $p$ is $5$.

\section{Materials and Methods}

A program was written to collect data answering the question ``for some $c, n, p$, what is the chance that an arbitrary $c$-coloring of size $n$ has a monochromatic subset matching some pattern designated by $p$?''. In a sense, the data is a mapping $(c, n, p) \longrightarrow probability$.

The program was roughly the following:

\begin{algorithm}
\begin{algorithmic}[1]

    \Function{trials}{$c$, $numTrials$} \Comment{Was only run for $c=2$.}
    \For{$p \in \mathbb{N}^+$}  \Comment{We use $p$-values as a way to iterate over patterns.}
        \State $pattern \gets \Call{make-pattern}{p}$ \Comment{\textsc{make-pattern} translates $p$-values back to patterns.}
        \For{$n \in \mathbb{N}^+$} \Comment{Does not loop forever; break condition is on line 13.}
            \State $attempts \gets 0$
            \State $successes \gets 0$
            \Loop{ $numTrials$ \textbf{times}}
                \State $coloring \gets \Call{make-random-coloring}{c n}$
                \State $attempts \gets attempts + 1$
                \If{$coloring$ contains a monochromatic subset matching $pattern$}
                    \State $successes \gets sucesses + 1$
                \EndIf
            \EndLoop
            \State \Call{record-data}{$c$, $p$, $n$, $attempts$, $successes$}
            \If{$attempts = successes$}  \Comment{If 100\% success rate, then now that all larger $n$s will have a 100\% success rate as well...}
                \State \textbf{break} \Comment{...so skip them; go to next $p$.}
            \EndIf
        \EndFor
    \EndFor
\EndFunction

\end{algorithmic}
\end{algorithm}

In reality, the program is more complicated as it has to reify a $pattern$ as a datatype and reify the proposition ``$coloring$ contains a monochromatic subset matching $pattern$''; additionally, it runs on multiple threads. This simplified version, however, is sufficient to understand the paper and data.

\section{Results}

In total, $[[ len(vals) ]]$ $p$-values were analyzed and therefore $[[ len(vals) ]]$ graphs generated. They are available in full in the appendix. Each graph relates the size $n$ of some arbitrary coloring, on the $x$-axis, to the probability said coloring has no monochromatic placement of the given pattern, on the $y$-axis.
    
\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(pgraph(13)) ]]
    [[ img_latex(pgraph(15)) ]]
    [[ img_latex(pgraph(23)) ]]
    [[ img_latex(pgraph(31)) ]]
    \caption{Some $p$-graphs look logistic}
    \label{fig:logistic}
\end{figure}

The graphs in Figure \ref{fig:logistic} were cherry picked to look logistic. Many, such as those in Figure \ref{fig:exponential}, look like they could instead be exponential.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(pgraph(17)) ]]
    [[ img_latex(pgraph(34)) ]]
    [[ img_latex(pgraph(36)) ]]
    [[ img_latex(pgraph(40)) ]]
    \caption{Some $p$-graphs look exponential}
    \label{fig:exponential}
\end{figure}

However, all graphs look like they \textit{could} be logistic, so we fit the parameterized logistic curve
$$\sigma^*(x) = y_0 + \frac{A}{1 + e^{-k (x - x_0)}}$$
over them, as shown in figure \ref{fig:fit}. There's an interesting subtlety here: we know that for $n=W(c, k)$, the chance of a $c$-coloring of size $n$ having a MAS($k$) is 100\% by the definition of $W(c, k)$. However, these curves look like the \textit{approach}, but never \textit{reach}, 1. And if they ever \textit{do} reach 1, then they will also reach numbers above 1, due to the nature of logistics. This makes little sense, though; then we're predicting an above-100\% chance of a coloring having a MAS($k$). In order to sidestep this issue, we do something quite clever: we cross our fingers and hope it works out. The result of the logistic fitting is shown in Figure \ref{fig:fit}. Observe that the logistic fit works well for both the logistic-looking and exponential-looking graphs.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(pgraph(13, fitted=True)) ]]
    [[ img_latex(pgraph(15, fitted=True)) ]]
    [[ img_latex(pgraph(23, fitted=True)) ]]
    [[ img_latex(pgraph(31, fitted=True)) ]]
    
    [[ img_latex(pgraph(17, fitted=True)) ]]
    [[ img_latex(pgraph(34, fitted=True)) ]]
    [[ img_latex(pgraph(36, fitted=True)) ]]
    [[ img_latex(pgraph(40, fitted=True)) ]]
    \caption{Logistic curves were fit over the $p$-graphs}
    \label{fig:fit}
\end{figure}

The logistic curve isn't perfect, though. One issue is that many graphs exhibit a strange small deviation from the logistic curve before continuing along with it. A kind of a ``kink''. Figure \ref{fig:kinky} shows some examples. These kinky graphs are actually rather common to high $p$-values.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(pgraph(5485)) ]]
    [[ img_latex(pgraph(5487)) ]]
    [[ img_latex(pgraph(5494)) ]]
    [[ img_latex(pgraph(5499)) ]]
    \caption{Some $p$-graphs are ``kinked'' in comparison to the logistic fit.}
    \label{fig:kinky}
\end{figure}

$p = 5631$, shown in Figure \ref{fig:degenerate} has an especially kinky graph, looking almost more like a piecewise exponential/linear/exponential/exponential function rather than a logistic curve. This is particularly worrying because it has so many datapoints, making the emergent pattern seem less like an anomaly.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(pgraph(5631)) ]]
    [[ img_latex(pgraph(5631, fitted=True)) ]]
    \caption{The graph for $p = 5631$ is especially kinky.}
    \label{fig:degenerate}
\end{figure}

The data, in general, are certainly not \textit{actually} logistic. However, they're close enough; a logistic curve fits \textit{reasonably} well over the graphs. So, we ill use it for simplicity.

Now we'd like to be able to curve fit onto the function of the $y_0$, $A$, $k$, and $x_0$ parameters, but there's an issue. These parameters are bound to a certain \textit{pattern}, not a number. In order to curve fit, we need a function of numbers; we achieve by using the pattern's $p$-value\footnote{Remember that $P$ is invertible.}. We may then plot $y_0$, $A$, $k$, and $x_0$ as functions of this $p$ value:

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(metagraph("p", "y0")) ]]
    [[ img_latex(metagraph("p", "A")) ]]
    [[ img_latex(metagraph("p", "k")) ]]
    [[ img_latex(metagraph("p", "x0")) ]]
    \caption{The logistic parameters were compared to $p$. Pattern which consist of all $1$s, which are those for which $P + 1$ is a power of $2$, are drawn in red.}
    \label{fig:summary}
\end{figure}

First and foremost, it seems to be the case that $y_0 = -A$. In fact, they have a near perfect linear association, as shown in Figure \ref{fig:y0_vs_A}. The consequence of this is, that since $\sigma$'s range is $(y_0, y_0 + A)$, then the size of the range is constant for all the graphs.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(metagraph("y0", "A")) ]]
    [[ img_latex(metagraph("p", lambda d: d["y0"] / d["A"] if d["y0"] and d["A"] else None, y_label="y0/A", filename="p-y0overA.png")) ]]
    \caption{$y0$ and $A$ have a near-perfect linear relation.}
    \label{fig:y0_vs_A}
\end{figure}

We also kept track of the first $n$ to result in a 100\% success rate; we called this value $V$. $p$ vs $V$ is shown in Figure \ref{fig:p_vs_V}.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(metagraph("p", "V")) ]]
    \caption{$P$ was compared to $V$, the first $n$ to result in a 100\% success rate.}
    \label{fig:p_vs_V}
\end{figure}

TODO: Talk about the binary-like recursive nature of Figure \ref{fig:p_vs_V}

The plots of $V$ and $x_0$ seem to be similar and indeed exhibit a ``linear-ish'' relationship, as shown in Figure \ref{fig:V_vs_x0}.

\begin{figure}[H]
    \centering
    \noindent
    [[ img_latex(metagraph("x0", "V")) ]]
    \caption{$V$ and $x_0$ exhibit a ``linear-ish'' relationship.}
    \label{fig:V_vs_x0}
\end{figure}

\section{Discussion}

Before we begin, something should be quickly addressed. In this paper, there are two variables named $k$: one denoting the size of a $MAS$ and the other denoting the value of the parameter $k$ in curve fitting. In order to unambiguously differentiate between the two, we will call the former $k_W$, ``$W$'' for ``Waerden''\footnote{$k_V$ is not used because $V$ is another logistic parameter.}.

\subsection{Approximation via $V$}

The most obvious way to approximate $W(2, k_W)$ is to derive a relationship between $k_W$ and $V$, as $V$ \textit{just is} an empirically derived Van der Waerden number\footnote{That is, the value $W(2,k_W)$ may be approximated by the $V$ corresponding to the $p$ corresponding to the $k_W$.}. However, $V$ is currently known in relation to $p$. There are two ways to solve this.

\subsubsection{By Discarding Extraneous Values}

First, we may discard all $p$-values not corresponding to a $k_W$\footnote{i.e., not colored red}, arriving at Figure \ref{fig:kw_vs_V}. Inspired by our lower bound $W_L(c, k_W)$, we fit the data with a parameterized $W_L$:
$$W_L^*(k_W) = y_0 + A\sqrt{k_W \cdot 2^{k(k_W-x_0) - 1}} $$

\begin{figure}[H]
    \centering
    \noindent
""")

xs = list(map(lambda d: len(bin(d["p"])) - 2, VDW_vals))
ys = list(map(itemgetter("V"), VDW_vals))
echo(img_latex(graph(xs, ys, "kW", "V")))
fileloc, params = graph(xs, ys, "kW", "V", fit_to=(WLstar, [0, 2, 1, 0]))
y0, A, k, x0 = params
kW_V_y0, kW_V_A, kW_V_k, kW_V_x0 = params
echo(img_latex(fileloc))

echo(r"""
    \caption{An approximation of $W(c, k_W)$, fit with $W_L^*(c, k_W)$.}
    \label{fig:kw_vs_V}
\end{figure}

The result of the curve fitting is shown in Figure \ref{fig:appx_via_V_results}.

\begin{figure}[H]
    \centering
    \caption{Curve-fitting coefficients from $W_L^*$ approximation.}
    \phantom{blank line}
    [[ params_latex(WLstar, params) ]]
    \label{fig:appx_via_V_results}
\end{figure}

Plugging the coefficients from Figure \ref{fig:appx_via_V_results} of the curve fitting back into $W_L^*$, we get the approximation:
$$W(2,k_W) \approx [[ y0 ]] + [[ A ]] \sqrt{k_W \cdot 2^{[[ k ]] (k_W+ [[ x0 ]]) - 1}}$$

\subsubsection{By Composition}

Second, we could instead fit a curve to these points of interest in their current position and then compose that with $P^{-1}$ to arrive at another approximation. The data were fit against the parameterized logarithmic curve
$$\phantom{.}\ln^*(x) = y_0 + A\ln(k(x-x_0)).$$
The result of the curve fitting is shown in Figure \ref{fig:appx_via_V_composition}.

\begin{figure}[H]
    \centering
    \noindent
""")

echo(img_latex(metagraph("p", "V", keep=True)))
fileloc, params = graphVDW("p", "V", fit_to=(logarithmic, [0, 100, 2, -1]))
echo(img_latex(fileloc))
y0, A, k, x0 = params
p_V_y0, p_V_A, p_V_k, p_V_x0 = params

echo(r"""
    \caption{A curve was fit over the $P$ vs $V$ graph for the values of interest.}
    \label{fig:appx_via_V_composition}
\end{figure}

The derived coefficients are:

\begin{figure}[H]
    \centering
    \caption{Curve-fitting coefficients from $\ln^*$ approximation.}
    \phantom{blank line}
    [[ params_latex(logarithmic, params) ]]
    \label{fig:appx_via_V_results}
\end{figure}

Thus, given a $p$ of interest, which is one that is colored red, we may approximate $V$ with:
$$\phantom{.}V(p) \approx [[ y0 ]] + [[ A ]] \ln([[ k ]] (p - [[ x0 ]])).$$

This is one step away from the goal; we want to know $V$ in terms of $k_W$, not $p$. Thus, we need a mapping $M$ from $k_W$ to $p$; then $\ln^* \circ \ M$ approximates $W(c, k_W)$. The $p$s we're dealing with are those patterns which are all $1$s, so each $p$ is in a position of a power of 2 minus 1. Thus, we may let $M(k_W) = 2^{k_W}-1$; then $M$ maps $k_W$s their corresponding $p$ values. Composing $M$ with with $\ln^*$, arrive at:
$$W(2,k_W) \approx [[ y0 ]] + [[ A ]] \ln([[ k ]] ((2^{k_W} - 1) - [[ x0 ]]))$$

\subsection{Approximation via Logistic Parameters}

Alternatively, we could fit curves to approximate $\sigma$'s $y_0$, $A$, $k$, and $x_0$ for a given $k_W$, thus producing an approximate logistic curve for some $k_W$; solving this general curve for 100\% would result in an approximation of $W(2,k_W)$.

While this method seems more arcane, it has a notable advantage. The previous two methods required us making a guess as to what the shape of the $p$ vs $V$ and $kW$ vs $V$ graphs are; this is equivalent to guessing the shape of the actual $W(2, k_W)$ function, a shape that is yet to be derived by mathematicians\footnote{It \textit{has} been proven that $W(2, k_W)$ is primitive recursive or slower \citep{primitiveRecursive}.} the shape, then, is quite the leap of faith.

In contrast, here, we still need to guess the shapes of curves, namely, that the $p$ vs $\%$ curves are logistic and also the shapes of the parameter curves; however, we are at least guessing different curves and these curves aren't so high-profile.

Again, we can do this by discarding or by composition.

\subsubsection{By Discarding Extraneous Values}

\subsubsection{By Composition}

$P$ vs $y_0$ and $P$ vs $A$ were fit against the parameteraized linear function:
$$\phantom{;}L^*(x) = y_0 + Ax;$$

\begin{figure}[H]
    \centering
""")

echo(img_latex(metagraph("p", "y0", keep=True)))
fileloc, params = graphVDW("p", "y0", fit_to=(linear, [1, 1]))
p_y0_y0, p_y0_A = params
echo(img_latex(fileloc))

echo(r"""
    \caption{$P$ vs $y_0$ was fit against $L^*$.}
\end{figure}

\begin{figure}[H]
    \centering
    \caption{Result parameters for $L^*$ fit against $P$ vs $y_0$}
    \phantom{blank line}
    [[ params_latex(linear, params) ]]
\end{figure}

\begin{figure}[H]
    \centering
""")

echo(img_latex(metagraph("p", "A", keep=True)))
fileloc, params = graphVDW("p", "A", fit_to=(linear, [1, 1]))
p_A_y0, p_A_A = params
echo(img_latex(fileloc))

echo(r"""
    \caption{$P$ vs $A$ was fit against $L^*$.}
\end{figure}

\begin{figure}[H]
    \centering
    \caption{Result parameters for $L^*$ fit against $P$ vs $A$}
    \phantom{blank line}
    [[ params_latex(linear, params) ]]
\end{figure}

$P$ vs $k$ was fit against the parameterized reciprocal function:
$$\phantom{;}I^*(x) = y0 + \frac{A}{x};$$

\begin{figure}[H]
    \centering
""")

echo(img_latex(metagraph("p", "k", keep=True)))
fileloc, params = graphVDW("p", "k", fit_to=(reciprocal, [50, 50]))
p_k_y0, p_k_A = params
echo(img_latex(fileloc))

echo(r"""
    \caption{$P$ vs $k$ was fit against $I^*$.}
\end{figure}

\begin{figure}[H]
    \centering
    \caption{Result parameters for $I^*$ fit against $P$ vs $k$}
    \phantom{blank line}
    [[ params_latex(reciprocal, params) ]]
\end{figure}

and $P$ vs $x_0$ was fit against $ln^*$.

\begin{figure}[H]
    \centering
""")

echo(img_latex(metagraph("p", "x0", keep=True)))
fileloc, params = graphVDW("p", "x0", fit_to=(logarithmic, [1, 1, 1, -1]))
p_x0_y0, p_x0_A, p_x0_k, p_x0_x0 = params
echo(img_latex(fileloc))

echo(r"""    
    \caption{$P$ vs $x_0$ was fit against $\ln^*$.}
\end{figure}

\begin{figure}[H]
    \centering
    \caption{Result parameters for $\ln^*$ fit against $P$ vs $x_0$}
    \phantom{blank line}
    [[ params_latex(logarithmic, params) ]]
\end{figure}

Approximating $\%$ with $\sigma^*$:
$$\%(p) = y_0 + \frac{A}{1 + e^{k(p-x_0)}}$$
we may plug in that
\begin{align*}
    y_0 &\approx [[ p_y0_y0 ]] + [[ p_y0_A ]] p \\
    A &\approx [[ p_A_y0 ]] + [[ p_A_A ]] p \\
    K &\approx [[ p_k_y0 ]] + \frac{ [[ p_k_A ]] }{p} \\
    x_0 &\approx [[ p_x0_y0 ]] + [[ p_x0_A ]] \ln([[ p_x0_k ]] (p - [[ p_x0_x0 ]]))
\end{align*}
to find that
$$\%(p) \approx {([[ p_y0_y0 ]] + [[ p_y0_A ]] p)} + \frac{ {[[ p_A_y0 ]] + [[ p_A_A ]] p} }{1 + \exp({{([[ p_k_y0 ]] + \frac{[[ p_k_A ]]}{p})}(p- {([[ p_x0_y0 ]] + [[ p_x0_A ]] \ln([[ p_x0_k ]](p - [[ p_x0_x0 ]])))} )})}$$
and then compose with $M$ to find the desired function of $k_W$:
\begin{gather*}
    \phantom{.}W(2,k_W) = \%(k_W) \approx {([[ p_y0_y0 ]] + [[ p_y0_A ]]  (2^{k_W} - 1) )} + \\ \frac{ {[[ p_A_y0 ]] + [[ p_A_A ]] (2^{k_W} - 1)} }{1 + \exp({{([[ p_k_y0 ]] + \frac{[[ p_k_A ]]}{(2^{k_W} - 1)})}((2^{k_W} - 1)- {([[ p_x0_y0 ]] + [[ p_x0_A ]] \ln([[ p_x0_k ]]((2^{k_W} - 1) - [[ p_x0_x0 ]])))} )})}.
\end{gather*}

Simple and elegant.

TODO: THIS IS WRONG; MUST SOLVE FOR =1

\subsection{Comparison to Known Values}
""")

def M(kW):
  return 2 ** kW - 1
def V_discarding(kW):
  return WLstar(kW, kW_V_y0, kW_V_A, kW_V_k, kW_V_x0)
def V_composition(kW):
  return logarithmic(M(kW), p_V_y0, p_V_A, p_V_k, p_V_x0)
def log_discarding(kW):
  return 0
def log_composition(kW):
  return 0

echo(r"""
\begin{figure}[H]
    \centering
    \caption{Comparison between known $W(2, k_W)$ values and approximations.}
    \phantom{blank line}
    
    \begin{tabular}{c|c|c|c|c|c}
        $k_W$ & $W(2,k_W)$ & $V$ (Discarding) & $V$ (Composition) & Log. (Discarding) & Log. (Composition) \\
        \hline 
        3 & 9    & [[ V_discarding(3) ]] & [[ V_composition(3) ]] & [[ log_discarding(3) ]] & [[ log_composition(3) ]] \\
        4 & 35   & [[ V_discarding(4) ]] & [[ V_composition(4) ]] & [[ log_discarding(4) ]] & [[ log_composition(4) ]] \\
        5 & 178  & [[ V_discarding(5) ]] & [[ V_composition(5) ]] & [[ log_discarding(5) ]] & [[ log_composition(5) ]] \\
        6 & 1132 & [[ V_discarding(6) ]] & [[ V_composition(6) ]] & [[ log_discarding(6) ]] & [[ log_composition(6) ]]
    \end{tabular}
    
    \label{fig:V_comparison}
\end{figure}

\newpage
\bibliographystyle{apa}
\bibliography{references}

""")

if args["--appendix"]:
  echo(r"\newpage \section{Appendix}")
  for p, _ in iter_ps():
    echo(img_latex(pgraph(p)))
    echo(img_latex(pgraph(p, fitted=True)))

echo("""
\end{document}
""")

with open(paper_fileloc, 'w') as f:
  f.write("\n".join(output_parts))
print(f"{paper_fileloc} generated.")
