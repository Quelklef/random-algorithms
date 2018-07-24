#/bin/bash

# The -d:provisional flag should be tested for and should implement
# alternative implementations for certain operations.
# This script then benchmarks those optimizations.

echo "# -- Stable -- #"
nim c --stdout --hints:off -d:reckless -d:release                -r benchmark
echo "# -- Provisional -- #"
nim c --stdout --hints:off -d:reckless -d:release -d:provisional -r benchmark
