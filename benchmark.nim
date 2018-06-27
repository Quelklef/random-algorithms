
import times

template benchmark*(timeVar, code: untyped): untyped =
    let t0 = cpuTime()
    code
    let elapsed  = cpuTime() - t0
    timeVar = elapsed

