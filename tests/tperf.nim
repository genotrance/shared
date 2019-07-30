import times, os, strutils

import shared/[seq, string]

#    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
#    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "s"

template benchmark(code: untyped): untyped =
  let t0 = epochTime()
  code
  epochTime() - t0

# Single thread raw comparison

proc sttest[T]() =
  var
    a: T

  for i in 0 .. 1000:
    when T is SharedSeq[SomeNumber] or T is system.seq[SomeNumber]:
      a.add i
    elif T is SharedSeq[cstring] or T is system.seq[cstring]:
      a.add ($i).cstring
    elif T is SharedSeq[system.string] or T is system.seq[system.string]:
      a.add $i

  for i in 0 .. 100:
    discard a.pop()

template stRaw(T: untyped) =
  let stdlib = benchmark:
    for i in 0 .. 999:
      sttest[seq[T]]()

  let sharedseq = benchmark:
    for i in 0 .. 9:
      sttest[SharedSeq[T]]()

  if stdlib != 0.0:
    echo "Relative: " & $(sharedseq / stdlib * 100)

#var
#  a: Channel[seq[string]]

#proc threadProc(chn: ptr Channel[seq[string]]) {.thread.} =
#  var
#    p = @["bye"]

#  chn[].send(p)

#proc test() =
#  var
#    thread: Thread[ptr Channel[seq[string]]]

#  a.open()

#  createThread(thread, threadProc, addr a)
#  thread.joinThread()

#  echo a.recv()

when isMainModule:
  stRaw(int)
  stRaw(cstring)
  stRaw(system.string)
