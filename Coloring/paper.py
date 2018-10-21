"""
Usage:
  paper [--ex]

Options:
  -h --help    Show help
  --ex         Use existing files
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
import sqlite3 as s3

args = docopt(__doc__)

def unzip(l):
  return tuple(map(list, zip(*l)))

# Make matplotlib faster
matplotlib.use('TkAgg')

conn = s3.connect("data.db")
db = conn.cursor()
if args["--ex"]:
  # Make breaking changes such that DB execution almost always returns
  # trash, and file saving is a noop

  class PlotDummy():
    def __getattr__(self, *args, **kwargs):
      return lambda *args, **kwargs: (None, None)
  plt = PlotDummy()

  dummy_rows = [[1] * 100] * 100
  actual_db = db
  class DBDummy():
    def execute(self, sql, *args, **kwargs):
      # Still need to be able to get these lists
      if sql.startswith("SELECT DISTINCT"):
        return actual_db.execute(sql, *args, **kwargs)
      else:
        return dummy_rows
  db = DBDummy()

C_i = 0
N_i = 1
K_i = 2
attempts_i = 3
successes_i = 4

def zeta(row):
  return row[successes_i] / row[attempts_i]

target_dir = "crunched/"

if not os.path.isdir(target_dir):
  os.makedirs(target_dir)

# Output to the LaTeX file
output_parts = []
paper_fileloc = "paper.tex"

# Define fitting curves
def exponential(x, y0, A, q, x0):
  return y0 + A * np.exp(q * (x - x0))
def logistic(x, y0, A, q, x0):
  return y0 + A / (1 + np.exp(-q * (x - x0)))
def monomial(x, y0, A, q, x0):
  return y0 + A * np.power(x - x0, q)
def logarithmic(x, y0, A, q, x0):
  return y0 + A * np.log(q * (x - x0))
def linear(x, y0, A):
  return y0 + A * x
def reciprocal(x, y0, A):
  return y0 + A / x
def arctan(x, y0, A, q, x0):
  return y0 + A * np.arctan(q * (x - x0))
def tanh(x, y0, A, q, x0):
  return y0 + A * np.tanh(q * (x - x0))
def reciprocalSq(x, y0, A):
  return y0 + A / x**2

def appx_zeta(n, k):
  """ zeta approximation derived deductively """
  C = 2.0
  B = 1 - C ** (1-k)
  E = (2 - k) / 2 + (n**2 - n) / (2 * (k - 1))
  return 1 - B ** E

def get_fitting_curve(**kwargs):
  assert len(kwargs) == 1

  if 'n' in kwargs:
    def fitting(x, y0, A, q, x0):
      return y0 + A * appx_zeta(kwargs['n'], q * (x - x0))
  else:  # k
    def fitting(x, y0, A, q, x0):
      return y0 + A * appx_zeta(q * (x - x0), kwargs['k'])

  return fitting

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

def fit(xs, ys, func, p0, bounds=None, **kwargs):
  """ Fit a curve over some xs and ys and plot it, returning fit params """
  params, covariance = curve_fit(func, xs, ys, p0=p0, maxfev=1000000)
  if not bounds:
    bounds = (min(xs), max(xs))
  sample_xs = np.linspace(*bounds, 200)
  plt.plot(sample_xs, func(sample_xs, *params), **kwargs)
  return params

bold = {'c': 'r', 's': 30}
small = {'s': 4}

def graph(xs, ys, x_label, y_label, *, title=None, filename=None, fit_to=None, style={}, keep=False):
  fileloc = os.path.join(target_dir, filename or f"{x_label}-{y_label}{'-fitted' if fit_to else ''}.png")

  plt.suptitle(title or f"{x_label} vs {y_label}")
  plt.xlabel(x_label)
  plt.ylabel(y_label)

  plt.scatter(xs, ys, **style)
  params = None
  if fit_to and len(xs) > len(fit_to[1]):
    params = fit(xs, ys, *fit_to)
  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  if not keep:
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

# LATEX
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

\newcommand{\floor}[1]{\left\lfloor #1 \right\rfloor}

\maketitle

\newpage

\begin{abstract}
TODO: REDO
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

\subsection{The $\zeta$ Function}

We define the $\zeta$ function to be
$$ \phantom{.} \zeta(c, n, k) = \text{The probability of a random $c$-coloring of size $n$ to have a MAS($k$)} . $$

We empirically derive approximations of the $\zeta$ function for certain $c, n, k$ triplets by generating some number $a$ of $c$-colorings of size $n$; the ratio of generated colorings with a MAS($k$) to $a$ is the approximation. Denote this approximation
$$ \phantom{.} \zeta_a(c, n, k) = \text{This particular approximation of $\zeta(c, n, k)$ for $a$ attempts} . $$

It is true that
$$ \phantom{.} \zeta(c, n, k) = 0 \longrightarrow \zeta(c, n, k+1) = 0 .$$
This is because if a $c$-coloring of size $n$ \textit{did} have a MAS($k+1$), then we could remove one of the items of that MAS thus constructing a MAS($k$). So $\zeta(c, n, k+1) \neq 0 \longrightarrow \zeta(c,n,k) \neq 0$ and, by contrapositive, $\zeta(c,n,k)=0\longrightarrow\zeta(c,n,k+1)=0$.

We generalize this and state as well that
$$ \phantom{.} \zeta_a(c, n, k) = 0 \longrightarrow \zeta_a(c, n, k+1) = 0 . $$
\textbf{This is wrong.} It's possible that $\zeta_a(c, n, k) = 0$ only ``by coincidence'', i.e., despite that $\zeta(c,n,k)\neq 0$. So, $\zeta(c,n,k+1)$ may or may not not be $0$ and thus we cannot be sure about $\zeta_a(c,n,k+1)$. We adopt this assertion anyway because it adds a large efficiency boost to trial generation and shouldn't mess anything up too bad.

Also note that
$$ \phantom{.} \zeta(c, n, k) = 1 \longrightarrow \zeta(c, n+1, k) = 1 . $$
This is because a $c$-coloring of size $n+1$ contains a $c$-coloring of size $n$. So if we're guaranteed that a $c$-coloring of size $n$ has a MAS($k$) then we're also guaranteed that any containing $c$-coloring of size $n+1$ has the same MAS($k$).

In general,
$$ \phantom{.} \zeta(c, n+1, k) \geq \zeta(c, n, k) . $$

We may consider $a$ to be a ``confidence'' of the corresponding $\zeta$ approximation, since as $a$ approaches $\infty$, $\zeta_a$ should approach $\zeta$.

\subsection{Approximating $\zeta$}

Note that the probability of some random arithmetic subsquence of size $k$ being monochromatic is
$$ \frac{c}{c^k} = c^{1-k} $$
since out of $c^k$ possible colorings of the arithmetic subsequence, $c$ of them are monochromatic.

We'd like to know the number of arithmetic subsequences for a given $c, n, k$. To do so, consider constructing an arithmetic subsequence. It would look something like:
\begin{gather*}
  \text{1. Choose starting point $p_0$.} \\
  \text{2. Choose distance between items of arithmetic subsequence.}
\end{gather*}

To solve for this, consider assigning $n$ items indicies $1$ through $n$. Step (1.) has $n-k$ choices, and step (2.) has $\floor{ \frac{n-p_0-1}{k-1} }$ choices. Thus,
\begin{align*}
  \text{Number of arithmetic subsequences} &= \sum_{p_0=1}^{n-k}{\floor{\frac{n-p_0-1}{k-1}}} \\
  &\approx \sum_{p_0=1}^{n-k}{\frac{n-p_0-1}{k-1}} \\
  &= \frac{(n-k)(k+n-1)}{2(k-1)} \text{ according to Wolfram$\vert$Alpha}
\end{align*}

Now, $\zeta$, by definition, is the probability that a $c$-coloring of size $n$ has a MAS($k$). Note that this is equal to the probability that it is not the case that every arithmetic subsequence is not monochromatic; this may be reified as:
\begin{align*}
  \zeta &\approx 1 - (1 - P(\text{arithmetic subsequence is monochromatic}))^\text{number of arithmetic subsequences} \\
  &= 1 - (1 - C^{1-k})^\frac{(n-k)(k+n-1)}{2(k-1)}
\end{align*}
and note that
\begin{align*}
  & \frac{(n-k)(k+n-1)}{2(k-1)} \\
  =& \frac{(n-k)((k-1)+n)}{2(k-1)} \\
  =& \frac{(n-k)(k-1) + (n-k)(n)}{2(k-1)} \\
  =& \frac{n-k}{2} + \frac{n(n-k)}{2(k-1)} \\
  =& \frac{n-k}{2} + \frac{n((n-1)-(k-1))}{2(k-1)} \\
  =& \frac{n-k}{2} + \frac{n(n-1)}{2(k-1)} - \frac{n}{2} \\
  =& \frac{n-k}{2} - \frac{n}{2} + \frac{n^2-n}{2(k-1)} \\
  =& \frac{n^2-n}{2(k-1)} - \frac{k}{2} .
\end{align*}
plugging this back in, we get that
$$ \zeta \approx 1-(1-c^{1-k})^{\frac{n^2-n}{2(k-1)}-\frac{k}{2}} . $$
Call this approximation
$$ \zeta^*. $$

Though this turns out to be a fairly decent approximation, it is certainly somewhat incorrect. We know this because by the definition of $W(c,k)$, $\zeta(c, W(c,k), k)$ must be $1$; however, $1$ is not in $\zeta^*$'s domain.

\subsection{Approximating $W(c,k)$}

Using the $\zeta^*$ approximation of $\zeta$, we may find an approximation $W^*$ of $W$.

We know that $W(c,k) = \text{ the first }n \mid \zeta(c,n,k)=1$, so we may find $W$ by solving for the $n$ satisfying $\zeta=1$ and therefore may find $W^*$ by solving for $n$ satisfying $\zeta^*=1$. However, as previously noted, $\zeta^*$ can never be $1$. Instead, we allow for some ``wiggle room'' by generalizing $\zeta^*$ to $\text{Fit}(\zeta^*)$ for
$$\text{Fit}(f) = y_0 + Af(q(x - x_0));$$
$y_0, A, q$, and $x_0$ are later derived empirically.

\begin{align*}
  \text{Fit}(\zeta^*(n)) &= 1 \\
  \text{Fit}(1-(1-c^{1-k})^{\frac{n^2-n}{2(k-1)}-\frac{k}{2}}) &= 1 \\
  \text{let } \beta &= q(n-x_0) \\
  y_0 + A \left(  1-(1-c^{1-k})^{\frac{\beta^2 - \beta}{2(k-1)}-\frac{k}{2}}  \right) &= 1 \\
  (1-c^{1-k})^{\frac{\beta^2 - \beta}{2(k-1)}-\frac{k}{2}} &= 1 - \frac{1-y_0}{A} \\
  \frac{\beta^2 - \beta}{2(k-1)} - \frac{k}{2} = log_{1-c^{1-k}}\left( 1-\frac{1-y_0}{A} \right) \\
  \text{let } \chi &= \left( 2(k-1) \right) \left( \log_{1-c^{1-k}} \left( 1 - \frac{1-y_0}{A} \right) \right) \\
  \beta^2 - \beta = \chi
  \frac{\beta^2 - \beta}{2(k-1)} - \frac{k}{2} &= \chi \\
\end{align*}
which is true if $\beta^2 - \beta - \chi = 0$; this is satisfied by
\begin{align*}
  \beta &= \frac{-(-1) \pm \sqrt{(-1)^2 - 4(1)(-\chi)}}{2} \\
  &= (1/2)(1+\sqrt{1+4\chi})
\end{align*}
thus
\begin{align*}
  \beta &= (1/2)(1+\sqrt{1+4\chi}) \\
  q(n-x_0) &= (1/2)(1+\sqrt{1+4\chi}) \\
  n &= x_0 + \frac{1 + \sqrt{1+4\chi}}{2q}
\end{align*}

Thus,
$$ \phantom{.} W(c,k) \approx x_0 + \frac{1 + \sqrt{1 + 4    \left( 2(k-1) \right) \left( \log_{1-c^{1-k}} \left( 1 - \frac{1-y_0}{A} \right) \right)    }}{2q} . $$

\section{Materials and Methods}

The program generated different $\zeta_a(c,n,k)$ approximations and was roughly the following:

\begin{algorithm}[H]
\begin{algorithmic}

\Function{generate-success-count}{$c$, $n$, $k$, $a$} \Comment{Approximates $a\cdot\zeta_a(c,n,k)$}
  \State $successes \gets 0$
  \Loop{ $a$ \textbf{times}}
    \State $coloring \gets \Call{make-random-coloring}{c, n}$
    \If{$coloring$ contains a MAS($k$)}
      \State $successes \gets successes + 1$
    \EndIf
  \EndLoop
  \State \Return $successes$
\EndFunction

\State

\Function{trials}{}
  \For{$c$ \textbf{in} $[2]$} \Comment{Only concerned with $c=2$}
    \For{$n$ \textbf{in} $[1, 2, ...]$} \Comment{Unboundedly increment $n$}
      \For{$a$ \textbf{in} $[5000, 10000, 15000, ..., 500000]$}
        \For{$k$ \textbf{in} $[1, 2, ..., k]$}
          \State $successes \gets \Call{generate-success-count}{c, n, k, a}$
          \State \Call{record-data}{$c$, $n$, $k$, $a$, $successes$}
          \If{$successes = 0$} \Comment{$\zeta_a(c,n,k)=0$ so $\forall k'>k(\zeta_a(c,n,k')=0)$}
            \State \textbf{break} \Comment{So no need to test any $k'>k$.}
          \EndIf
        \EndFor
      \EndFor
		\EndFor
  \EndFor
\EndFunction

\end{algorithmic}
\end{algorithm}

In reality, the program is somewhat more complicated handling more IO and running on multiple threads. However, this simplified version is sufficient to understand the paper.

\section{Results}

""")

def fig_latex(latex):
  return r"""\begin{figure}[H] %s \end{figure}""" % latex

As = list(map(itemgetter(0), db.execute("SELECT DISTINCT attempts FROM data ORDER BY attempts")))
ns = list(map(itemgetter(0), db.execute("SELECT DISTINCT n FROM data ORDER BY n")))
ks = list(map(itemgetter(0), db.execute("SELECT DISTINCT k FROM data ORDER BY k")))

echo("\subsection{$k$ vs $V$}")
xs, ys = unzip(map(lambda r: (r[0], r[1]), db.execute("SELECT k, MIN(n) FROM data WHERE attempts=successes GROUP BY k, attempts")))
filename = graph(xs, ys, "k", "V", title="k vs V", filename="k-v.png")
echo(fig_latex(img_latex(filename)))

echo("\subsection{$k$ vs $\zeta$ for given $n$}")
params_xs = []
params_ys = []
for n in ns:
  plt.suptitle(f"k vs zeta for n={n}")
  plt.xlabel("k")
  plt.ylabel("zeta")
  filename = f"n={n}.png"
  fileloc = os.path.join(target_dir, filename)

  xs, ys = None, None  # Leak this variable from the next loop
  for a in As:
    xs, ys = unzip(list(map(lambda r: (r[K_i], zeta(r)), db.execute("SELECT * FROM data WHERE n=? AND attempts=? AND successes <> 0 AND successes <> attempts", (n, a))))) or ([], [])
    colors = [(1, 0, 1-(a/max(As)))] * len(xs)
    plt.scatter(xs, ys, c=colors, s=50)

  # Now the xs and ys are those for the most confident a
  xs1, ys1 = unzip([(x, y) for x, y in zip(xs, ys) if y != 1]) or ([], [])
  # Tried: exponenial, arctan, tanh, reciprocal, logistic
  if len(xs1) >= 4:
    fitting = get_fitting_curve(n=n)
    params = fit(xs1, ys1, fitting, [1, 1, 1, 1], linewidth=3)

    params_xs.append(n)
    params_ys.append(params)

  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  plt.clf()

  echo(fig_latex(img_latex(fileloc)))

for i, param_name in enumerate(["x0", "A", "q", "y0"]):
  xs = params_xs
  ys = list(map(lambda t: t[i], params_ys))

  plt.suptitle(f"n vs {param_name}")
  plt.xlabel("n")
  plt.ylabel(param_name)
  filename = f"n-fitting-{param_name}.png"
  fileloc = os.path.join(target_dir, filename)

  plt.scatter(xs, ys)

  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  plt.clf()

  echo(fig_latex(img_latex(fileloc)))

echo(r"""
\subsection{$n$ vs $\zeta$ for given $k$}
""")
params_xs = []
params_ys = []
for k in ks[:25]:  # After k=25, they're all just flat lines
  plt.suptitle(f"n vs zeta for k={k}")
  plt.xlabel("n")
  plt.ylabel("zeta")
  filename = f"k={k}.png"
  fileloc = os.path.join(target_dir, filename)

  xs, ys = None, None
  for a in As:
    xs, ys = unzip(list(map(lambda r: (r[N_i], zeta(r)), db.execute("SELECT * FROM data WHERE k=? AND attempts=?", (k, a)))))
    colors = [(1, 0, 1-(a/max(As)))] * len(xs)
    plt.scatter(xs, ys, c=colors, s=50)

  if len(xs) >= 4:
    fitting = get_fitting_curve(k=k)
    params = fit(xs, ys, fitting, [1, 1, 1, 1], linewidth=3)

    params_xs.append(k)
    params_ys.append(params)

  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  plt.clf()

  echo(fig_latex(img_latex(fileloc)))

for i, param_name in enumerate(["x0", "A", "q", "y0"]):
  xs = params_xs
  ys = list(map(lambda t: t[i], params_ys))

  plt.suptitle(f"k vs {param_name}")
  plt.xlabel("k")
  plt.ylabel(param_name)
  filename = f"n-fitting-{param_name}.png"
  fileloc = os.path.join(target_dir, filename)

  plt.scatter(xs, ys)

  print(f"Generated {fileloc}.")
  plt.savefig(fileloc)
  plt.clf()

  echo(fig_latex(img_latex(fileloc)))

echo(r"""
\newpage
\bibliographystyle{apa}
\bibliography{references}

\end{document}
""")

with open(paper_fileloc, 'w') as f:
  f.write("\n".join(output_parts))
print(f"{paper_fileloc} generated.")
