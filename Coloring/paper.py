"""
Usage:
  paper [--ex] [--min] [--nofun]

Options:
  -h --help    Show help
  --ex         Use existing files
  --min        Do not generate graphs
  --nofun      Remove iffy stuff (for Regeneron STS)
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
from functools import partial
import sqlite3 as s3

clargs = docopt(__doc__)

def unzip(n, l):
  return tuple(map(list, zip(*l))) or tuple([] for _ in range(n))

# Make matplotlib faster
matplotlib.use('TkAgg')

conn = s3.connect("data.db")
db = conn.cursor()

db.execute("CREATE INDEX IF NOT EXISTS ka_index ON data (k, attempts)")
db.execute("CREATE INDEX IF NOT EXISTS na_index ON data (n, attempts)")

if clargs["--ex"] or clargs["--min"]:
  # Make breaking changes such that DB execution almost always returns
  # trash, and file saving is a noop

  class PlotDummy():
    def __getattr__(self, *args, **kwargs):
      return lambda *args, **kwargs: (None, None)
  plt = PlotDummy()

  actual_db = db
  class DBDummy():
    def execute(self, sql, *args, **kwargs):
      # Still need to be able to get these lists
      if not clargs["--min"] and sql.startswith("SELECT DISTINCT"):
        return actual_db.execute(sql, *args, **kwargs)
      else:
        return actual_db.execute("SELECT * FROM data WHERE 1=0")
  db = DBDummy()

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
def linear(x, y_0, A):
  return y_0 + A * x
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
  c = 2.0
  p_AS_is_MAS = c ** (1-k)
  n_COL = c ** n
  epsilon = 0
  #epsilon = (k-2)/(k-1) * (n-k+1)
  n_AS_per_COL = (n**2 - n) / (2*(k-1)) + (2-k)/2 - epsilon
  v = 1.0 - (1.0 - p_AS_is_MAS) ** (n_COL * n_AS_per_COL)
  return v

def appx_zeta_adj(n, k, attempts):
  """ round the zeta appx'n to be able to hit 1 and 0, "within one coloring" """
  #return np.round(appx_zeta(n, k) * attempts) / attempts
  return appx_zeta(n, k)

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
  bounds = bounds or (min(xs), max(xs))
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
  param_names = inspect.getargspec(f)[0][1:]

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

\title{A Lower Bound and an Approximation for The Van der Waerden Number function $W(c,k)$}
""")

if not clargs["--nofun"]:
  echo(r"\author{Eli Maynard\thanks{With help from Noah Gleason and Ryan Tse of Montgomery Blair High School}\\{\small Advised by William Gasarch of the University of Maryland}")
else:
  echo(r"\author{Eli Maynard}")

echo(r"""
\date{November 2018}

\usepackage{natbib}
\usepackage{graphicx}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage{algorithm}
\usepackage[noend]{algpseudocode}
\usepackage{bm}
\usepackage{subcaption}
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
We deductively derived two lower bounds and empirically derived an approximation of the Van der Waerden number function $W(c,k)$ at $c=2$. $W(c,k)$ gives the lowest $n\in\mathbb{N} \mid \forall c$\-coloring $C$ of size $n$, $\exists$ some monochromatic arithmetic subsequence of size $k$ in $C$. To arrive at the approxmiation, we programmatically generated and then analyzed approximations of probabilities that some arbitrary $2$-coloring of size $n$ contains a monochromatic arithmetic subset of size $k$. We iteratively found the lowest $n$ for each $k$ to produce a 100\% probability; approximating this $n$ for a given $k$ is approximating $W(2, k)$.
\end{abstract}

\newpage

\section{Introduction}

\subsection{$c$-Colorings}

A \textit{c-coloring} of size $n$ is a sequence of $n$ elements, where each element is one of $c$ distinct items, or ``colors''. For instance, a 3-coloring of size $4$ may be ``$\text{Red Red Blue Purple}$''. In this paper, $c$ will never exceed $9$, so $c$-colorings will be represented as a number in which each digit corresponds to one color. The previous coloring would be written as just ``$0012$''; $0$ for $\text{Red}$, $1$ for $\text{Blue}$, and $2$ for $\text{Purple}$.

\subsection{Monochromatism and Monochromatic Arithmetic Subsequences}

A \textit{monochromatic arithmetic subsequence} of size $k$, or \textit{MAS(k)}\footnote{Also known as a \textit{size-}$k$ \textit{arithmetic progression}}, is a selection of items from a $c$-coloring such that all items are the same distance apart and the same color. For instance:
\begin{align*}
    \text{Coloring: }& 230112320103231133 \\
    \text{MAS($4$): }& \text{\phantom{2}3\phantom{0110}3\phantom{0010}3\phantom{0010}3}
\end{align*}
This paper will use 1-indexing. So, the indicies of the $3$s are $2, 7, 12, \text{and } 17,$ respectively. Since there is a fixed distance between each item, i.e., $17 - 12 = 12 - 7 = 7 - 2 = 5$, the subsequence is arithmetic; since each item is the same color, i.e., $3 = 3 = 3 = 3$, it is monochromatic; therefore, it is a MAS; since it has 4 items, it is a MAS(4).

\subsection{Van der Waerden's Theorem}

Van der Waerden's Theorem states that
$$\phantom{.}\forall k,c \in \mathbb{N}, \exists n \in \mathbb{N} \mid \forall c\text{-coloring } C\text{ of size } n, C \text{ has some MAS} (k) .
$$
\noindent
The smallest satisfactory $n$ for a given $c, k$ is denoted $W(c, k)$; this function is the ``Van der Waerden number function''.

That is, given a number of colorings $c$ and subsequence size $k$, there exists some $W(c, k)$; any $c$-coloring of the size $W(c, k)$ has a monochromatic arithmetic subsequence of size $k$. Furthermore, this property doesn't hold for any Natural number less than $W(c, k)$.
""")

t = "Consider an example. %s Then consider the natural numbers $\mathbb{N}$ in which we classify each number as either a prime or a composite. This is two categories, so $c=2$. Van der Waerden's theorem guarantees that we can always find $k=10$ numbers evenly spaced which are either all prime or all composite in any subsequence of $\mathbb{N}$ of size $\geq W(2,10)$."
if not clargs["--nofun"]:
  echo(t % "Choose a number... Unfortunately, since this is a paper, I cannot know the number you chose. I'll assume it's 10. So let $k=10$.")
else:
  echo(t % "Take $k=10$.")

echo(r"""
Note that, as well as colorings smaller than $W(c,k)$ \textit{not} being guaranteed a MAS($k$) (due to $W(c,k)$ being the minimal value), all colorings greater than $W(c,k)$ \textit{are} guaranteed a MAS($k$). This is because all colorings larger than $W(c,k)$ contain a coloring of the size $W(c,k)$, which has a guaranteed MAS($k$).\footnote{As a sidenote, this means that, $W(c,k)$ ``splits'' $\mathbb{N}$ into two contiguous sections: numbers for which $c$-colorings of that size are not guaranteed a MAS($k$), and numbers for which $c$-colorings of that size are guaranteed to have a MAS($k$).}

\subsection{Motivation for Research}

Information about $W(c,k)$ does not immediately lend itself into any particular application. It is, however, part of Ramsey Theory, which continues to find applications, both in the theoretical: ``Logic [...] Concrete Complexity [...] Complexity Classes [...]  Parallelism [...] Algorithms [... and] Computational Geometry'' \citep{TheoreticalApplications}, and the concrete: ``communications, information retrieval, [...] and decisionmaking'' \citep{ConcreteApplications}. Due to the continued application of Ramsey Theory as a whole, we have faith that Van der Waerden's theorem will eventually find practical use.

% Why do we care about approximating $W(c,k)$? According to William Gasarch of the University of Maryland, ``There are NO applications of [Van der Waerden's] theorem.''
""")

if not clargs["--nofun"]:
  echo(r"\subsection{Some Facts}")
else:
  echo(r"\subsection{Relevant Facts}")

echo(r"""
The number of colorings for some given $c, n, k$ is
$$ \text{\#col} = c^n $$
since each of $n$ positions in the coloring may be colored one of $c$ ways.

The probability that a given arbitrary arithmetic subseqence of some arbitrary coloring is monochromatic is
$$ \text{\% AS is MAS} = \frac{c}{c^k} = c^{1-k} $$
since of $c^k$ ways that the subsequence may have been colored, only $c$ of them are monochromatic: one for each color.

The number of arithmetic subsequences in a $c$-coloring of size $n$ is
$$ \text{\#AS}/\text{col} = \frac{n^2-n}{2(k-1)} + \frac{2-k}{2} - \epsilon \text{ for } \epsilon := \sum_{p_0 = 1}^{n-k+1}{\frac{mod(n-p_0,k-1)}{k-1}} $$
This may be understood by discussing the process of choosing an arithmetic subsequence from a given coloring. One way to do this is with two steps, as follows:
\begin{align*}
  & \text{1. Choose the starting point $p_0$ of the subsequence} \\
  & \text{2. Choose the distance between each item of the subseqnce}
\end{align*}
Step (1.) has $n-k+1$ options, from position $1$ to position $n-k+1$. Step (2.), for a given $p_0$, has $\floor{n-p_0 \over k-1}$ options. As such, the total number of arithmetic subsequences in a $c$-coloring of size $n$ is
$$ \sum_{p_0=1}^{n-k+1}{\floor{n-p_0 \over k-1}} $$
And since
$$ \floor{a \over b} = \frac{a - mod(a,b)}{b} $$
then we may replace the sum with
$$ \sum_{p_0=1}^{n-k+1}{\frac{n-p_0}{k-1}} - \sum_{p_0 = 1}^{n-k+1}{\frac{mod(n-p_0,k-1)}{k-1}} $$
Calling the second sum $\epsilon$, Wolfram$\mid$Alpha tells us that this is equal to
$$ \phantom{.} \frac{n^2-n}{2(k-1)} + \frac{2-k}{2} - \epsilon . $$

Note that since
$$ 0 \leq mod(n-p_0, k-1) \leq k-2 $$
then
$$ \phantom{.} 0 \leq \epsilon \leq {k-2 \over k-1}(n-k+1) \phantom{.} $$


\subsection{A Lower Bound on $W(c,k)$}

Take
\begin{gather*}
  \begin{aligned}
    n &< \frac{1}{2} \left( 1 + \sqrt{8(k-1)c^{k-1} + (3-2k)^2} \right) \\
    n &< \frac{1}{2} \left( 1 + \sqrt{1 - 12k + 4k^2 + 8(k-1)c^{k-1} + 8} \right) \\
    n &< \frac{1}{2} \left( 1 + \sqrt{1-4(3k - k^2 - 2(k-1)c^{k-1} - 2)} \right) \\
    n &< \frac{1}{2} \left( 1 + \sqrt{1 - 4(2k - k^2 - 2kc^{k-1} - 2 + k + 2c^{k-1})} \right) \\
    n &< \frac{1}{2} \left(  -(-1) + \sqrt{ (-1)^2 - 4(1)(k-1)(2-k-2c^{k-1}) }  \right) \\
    0 \leq n &< \frac{1}{2} \left(  -(-1) + \sqrt{ (-1)^2 - 4(1)(k-1)(2-k-2c^{k-1}) }  \right) \text{ since } n \in \mathbb{N}^{+}
  \end{aligned} \\
  \begin{aligned}
    n^2 - n + (k-1)(2-k-2c^{k-1}) &< 0 \text{ by the quadratic formula} \\
    (2-k)(k-1)+n^2-n &< 2c^{k-1}(k-1) \\
    (2-k)(k-1) + n^2 - n &< 2c^{k-1}(k-1) \\
    \frac{2-k}{2} + \frac{n^2 - n}{2(k-1)} &< c^{k-1} \\
    \left( \frac{2-k}{2} + \frac{n^2 - n}{2(k-1)} \right) c^{1-k} &< 1 \\
    \left( \frac{2-k}{2} + \frac{n^2 - n}{2(k-1)} - \epsilon \right) c^{1-k} &< 1 \text{ since $\epsilon \geq 0$}
  \end{aligned} \\
  (\text{\#AS/col})(\text{\% AS is MAS}) < 1 \\
  (\text{\#AS/col})(\text{\% AS is MAS})(\text{\#col}) < \text{\#col} \\
  \text{\#MAS} < \text{\#col} \\
  \text{Some coloring has no MAS} \\
  n < W(c,k)
\end{gather*}

Thus
$$ L(c,k) = \frac{1}{2} \left( 1 + \sqrt{8(k-1)c^{k-1} + (3-2k)^2} \right) $$
is a lower bound of $W(c,k)$.\footnote{Motivation for the steps of the proof may be seen by reading the proof backwards.}

\subsubsection{Comparison to Existing Bounds}

The first \citep{ThatErdosWasFirst} lower bound on $W(c,k)$, presented by \cite{FirstLowerBound}, was $\sqrt{2(k-1)c^{k-1}}$. Our bound, though stronger, asymptotically approaches Erd{\"o}s' and Rado's bound as $k\to\infty$.

There are certainly better bounds. Called the ``best known (asymptotic) lower bound'' by \cite{BestKnownAsymQuote}, \cite{BestBound} presents that $\forall \epsilon > 0,\ \forall \text{ large enough } k,\ W(2,k) \geq \frac{2^k}{k^{-\epsilon}}$. \cite{PrimeBound} presents that for prime $k$, $W(2,k) > (k-1)2^{k-1}$. \cite{GenBerkBound} presents ``the best known bound for a large interval of'' c that for prime $k$ and $2 \leq c \leq k \leq k$, $W(2,k) > (k-1)^{c-1}$.

Though of these bounds are stronger than our bound, they have constraints, respectively that $k$ is large enough, that $k$ is prime, and that $p$ is prime and $2 \leq c \leq p \leq k$. Since our bound has no such constraints then though it is weaker, it applies more generally and with more ease.

\subsection{The $\zeta$ and $\zeta_a$ Functions}

We define the $\zeta$ function to be
$$ \phantom{.} \zeta(c, n, k) := \text{The probability of a random $c$-coloring of size $n$ to have a MAS($k$)} . $$

We may approximate $\zeta$ by generating some number $a$ (`a' for `attempts') of $c$-colorings; the ratio between the number of generated colorings with a MAS($k$) and the number of generated colorings is an approximation of $\zeta(c, n, k)$. We call this approximation $\zeta_a(c, n, k)$.

Note that $\zeta(c, n, k) = 1 \longrightarrow \zeta(c, n + 1, k) = 1$. We generalized this to $\zeta_a(c, n, k) = 1 \longrightarrow \zeta_a(c, n + 1, k)$. \textbf{This is wrong}. It is possible that $\zeta_a(c, n, k) = 1$ ``by coincidence'', i.e., despite that $\zeta(c, n, k) \neq 1$. In this case, we know nothing about $\zeta(c,n+1,k)$ and therefore nothing about $\zeta_a(c,n+1,k)$. We adopted this assumption anyway in order to speed up the program. This makes the generated data a somewhat worse approximation.\footnote{Some measures are taken against this issue and will be acknowledged in the Discussion section.}

\subsection{The Shape of $\zeta$}
""")

if not clargs["--nofun"]:
  echo(r"{ \scriptsize \ldots The thrilling mathematical sequel to the 2017 movie \textit{The Shape of Water}. }")

echo(r"""

It is reasonable to express $\zeta$ as ``the probability that it is \textit{not} the case that \textit{every} arithmetic subsequence of the given coloring is \textit{not} monochromatic''\footnote{i.e., $\neg\forall AS,\ \neg mono(AS) \longleftrightarrow \exists AS\mid mono(AS)$}. It is then \textit{tempting} to express this as
\begin{align*}
  \zeta &= 1 - (1 - \text{\% AS is MAS})^{\text{\#AS/col}} \\
        &= 1 - (1 - c^{1-k})^{\frac{n^2-n}{2(k-1)} + \frac{2-k}{2} - \epsilon}
\end{align*}

However, this is not quite correct. This expression uses the probabalistic multiplicaiton rule, which may be applied to two \textit{independent} events. However, one AS being monochromatic is \textit{not} independent from another AS being monochromatic. We can also see that this is incorrect because though 1 is in $\zeta$'s range, it is not in the range of this expression.

Despite this, this expression gives us some insight. It leads us to suspect that $\zeta$ looks somewhat like this expression in some capacity\footnote{And, though we no longer have the graphs to support so, we'll state that this is in fact a good approximation.}. Specifically, it will be important to consider the shape of $\zeta$ with respect to $n$. Observe that as $n \to \infty$, this expression $\to 1$ in an asymptotic manner. Note that since $\zeta$ reaches 1 eventually, $\zeta$ is not \textit{actually} asymptotic, so we call it \``textit{near}-asymptotic''.

\subsection{Approximating $W(c,k)$}

If we generate $\zeta_a(c, n, k)$ approximations iterating over $n$, then we may approximate $W(c, k)$ as the first $n$ for which $\zeta_a(c, n, k) = 1$. We call this result $V$. Note that this is not a ``mathematical variable'' but rather the result of an algorithm which may change each time the algorithm is run.

\section{Materials and Methods}

The program was roughly the following:

\begin{algorithm}%[H]
\begin{algorithmic}[1]

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
    \For{$k$ \textbf{in} $[1, 2, ...]$} \Comment{Unboundedly increment $k$}
      \For{$a$ \textbf{in} $[5\text{k}, 10\text{k}, 15\text{k}, ..., 500\text{k}]$} \Comment{`k' denoting ``thousand''}
        \For{$n$ \textbf{in} $[k, k+1, k+2, ...]$} \Comment{Unboundedly increment $n$}
          \State $successes \gets \Call{generate-success-count}{c, n, k, a}$
          \If{$successes = a$} \Comment{If 100\% success rate}
            \State \Call{record-data}{$c$, $k$, $a$, $n$} \Comment{Record $V=n$ for $c, k, a$}
            \State \textbf{skip to next $a$} \Comment{$\zeta_a(c,n,k)=1$ so know $\forall n'>n\ ,\zeta_a(c,n',k)=1$ so skip all $n'$}
          \EndIf
        \EndFor
      \EndFor
		\EndFor
  \EndFor
\EndFunction

\end{algorithmic}
\end{algorithm}

The actual source code is available online at \url{https://github.com/Quelklef/random-algorithms/tree/ec25769af7980f9cedd7eb9a9be596bde6e4d642/Coloring}.

\section{Results}

The following are graphs of $k$ vs $V$ from the trial data. Each graph was approximated with an exponential curve
$$ E(k) := y_0 + A \cdot e^{q \cdot (k - x_0)} $$

""")

def fig_latex(latex, caption=""):
  if caption:
    return r"\begin{figure}[H] %s \caption{" + caption + "} \end{figure}" % latex
  else:
    return r"\begin{figure}[H] %s \end{figure}" % latex

def take_while(pred, seq):
  i = 0
  while i < len(seq) and pred(seq[i]):
    i += 1

  result = seq[:i]
  del seq[:i]
  return result

As = list(map(itemgetter(0), db.execute("SELECT DISTINCT attempts FROM data ORDER BY attempts")))

png_locs = []
paramss = []
for a in As:
  xs, ys = unzip(2, db.execute("SELECT k, n FROM data WHERE attempts=?", (a,)))

  plt.suptitle(f"k vs V (a={a})")
  plt.xlabel("k")
  plt.ylabel("V")
  plt.scatter(xs, ys)
  params = fit(xs, ys, exponential, p0=[0, 1, .5, 0])
  paramss.append(params)

  filename = f"k-v-{a}.png"
  fileloc = os.path.join(target_dir, filename)
  plt.savefig(fileloc)
  print(f"{fileloc} generated.")
  png_locs.append(fileloc)

  plt.clf()

echo(r"\begin{figure}[H] \centering")
for i, loc in enumerate(png_locs):
  if i % 2 == 0:
    echo(r"\end{figure} \begin{figure}[H] \centering")
  echo(img_latex(loc))
echo(r"\caption{$k$ vs $V$ curves for fixed values of $a$, with an exponential fit.} \label{fig:v} \end{figure}")

echo(r"""
The found values of $y_0$, $A$, $q$, and $x_0$ versus $a$ are shown below.
""")

begin_latex = r"\begin{figure}[H] \centering"
end_latex = r"\end{figure}"

parameter_point_estimates = {}

echo(begin_latex)
for i, param in enumerate(["y_0", "A", "q", "x_0"]):
  if i != 0 and i % 2 == 0:
    echo(end_latex)
    echo(begin_latex)

  plt.suptitle(f"a vs {param}")
  plt.xlabel("a")
  plt.ylabel(param)

  filename = f"params-{param}.png"
  fileloc = os.path.join(target_dir, filename)

  xs = As
  ys = list(map(itemgetter(i), paramss))
  parameter_point_estimates[param] = mean(ys)
  plt.scatter(xs, ys)

  #params = fit(xs, ys, linear, [1, 1])

  echo(img_latex(fileloc))
  #echo(r"\\")
  #echo(params_latex(exponential, params))

  print(f"{fileloc} generated.")
  plt.savefig(fileloc)
  plt.clf()
echo(r"\caption{$a$ versus parameter values for the previous exponential fittings.} \label{fig:fit} " + end_latex)

echo(r"""

\section{Discussion}
\label{sec:discussion}

We expect $V$ to only be a mediocre approximation of $W(c,k)$. This is because of $\zeta$'s near-asymptotic behavior. Since a $\zeta$ value \textit{close to} $1$ may result in a $\zeta_a$ value \textit{of} $1$, and since $\zeta$ is near-asymptotic, and therefore has many consecutive values close to 1 before actually reaching 1, then a $\zeta_a$ value may be $1$ long before $\zeta$ is 1.

This issue is further exacerbated by our assumption that $\zeta_a(c, n, k) = 1 \longrightarrow \zeta_a(c, n+1, k) = 1$; if we did not assume this, then we may, after finding an $n \mid \zeta_a = 1$, find an $n' > n \mid \zeta_a \neq 1$, thus showing that $n < W(c,k)$ since certainly $n' < W(c,k)$. Using this method, these lower ``false positive'' $n$s for which $\zeta_a = 1$ could be detected.\footnote{A notable downside to this method is that it does not give a condition for stopping iteration over $n$.}

The hope was that the generation of trials for several $a$ values could fix this issue. Note that $a$ can be seen as a kind of ``confidence value''. As $a$ increases, we'd expect the ``correctness'' of the results to increase as well, since there are more trials and therefore random variance should lessen. We hoped that, though \textit{each} $a$ would have the issues mentioned above, we could see a pattern emerging over the iteration of \textit{many} $a$s, and this pattern would reveal the true curve of $V$.

However, this did not happen. The graphs of $a$ against the four parameters $y_0$, $A$, $q$, and $x_0$ do not have a strong enough shape to justify any extrapolation. This is possibly due simply to not having enough trials; however, it could also be because an exponential fit is inappropriate. This would not be surprising as fitting exponentially was a total guess; a more informed fit would require knowing the shape of $W(c,k)$, which we don't know: if we did, then we wouldn't have had to do this research.\footnote{One may object that an approximation is nearly useless without \textit{already} knowing the shape of the curve. This is valid and a major pitfall of this paper.}

The second-best options are to approximate these parameters either with the value given by the highest $a$, or an average over all $a$s. We approximate them with an average because the graphs seem to indicate that different $a$s actually have a minimal effect on the ``correctness'' of the values, so we may as well use them all.

""")

echo(r"\begin{figure}[H] \caption{Point estimates of parameters to exponential fits of $V$} \centering \begin{tabular}{c|l}")
echo(" \\\\\n".join(
  "$" + str(param) + "$ & $" + str(round(est, 3)) + "$" for param, est in parameter_point_estimates.items()
))
echo(r"\end{tabular} \label{fig:est} \end{figure}")

globals().update(**parameter_point_estimates)
def W_est(k):
  return y_0 + A * np.exp(q * (k - x_0))

echo(r"""

Thus, an approximation of $W$ is:
$$ W(2,k) \approx [[y_0:.3f]] + [[A:.3f]] e^{[[q:.3f]] \cdot (k - [[x_0:.3f]])} $$

We may compare this to known W(2,k) numbers
\begin{figure}[H] \centering
\caption{Comparison of known $W(2,k)$ values to estimated values.}
\[ \begin{array}{c|c|c|c}
$k$ & \text{Known value} & \text{Approximation} & \lvert \text{Difference} \rvert \\
\hline
3 & 9    & [[W_est(3):.2f]] & [[abs(W_est(3)-9   ):.2f]] \\
4 & 35   & [[W_est(4):.2f]] & [[abs(W_est(4)-35  ):.2f]] \\
5 & 178  & [[W_est(5):.2f]] & [[abs(W_est(5)-178 ):.2f]] \\
6 & 1132 & [[W_est(6):.2f]] & [[abs(W_est(6)-1132):.2f]]
\end{array} \]
\end{figure}
\ldots and see that the approximation is not very good. Since it overestimates at first and underestimates lower on, the shape of the approximation seems to be too shallow. The error should only increase for higher $k$s, which is unfortunate because higher $k$s are of more significance\footnote{Due to $W$ being easier to find for lower $k$s}. We view this result as evidence that the actual shape of $W$ is not exponential despite the $k$ vs $V$ graphs fitting seductively well to exponential curves.
\newpage
\bibliographystyle{apa}
\bibliography{references}

\end{document}
""")

with open(paper_fileloc, 'w') as f:
  f.write("\n".join(output_parts))
print(f"{paper_fileloc} generated.")
