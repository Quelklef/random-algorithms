nim c -r -d:release -d:benchmark --hints:off                tests
echo "# -- Provisional -- #"
nim c -r -d:release -d:benchmark --hints:off -d:provisional tests
