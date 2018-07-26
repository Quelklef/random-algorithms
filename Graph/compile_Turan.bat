del Turan.exe
sleep 1
nim c --threads:on -d:release Turan
for /l %%x in (10,10,100) do (
  Turan.exe %%x .05 50000
)
pause
