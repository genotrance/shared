import os

import shared/seq

# Seq testing

proc test() =
  var
    p = newSharedSeq[int]()
    q = newSharedSeq[float]()
    r = newSharedSeq[cstring]()
    s = newSharedSeq[string]()

  p.set(@[1, 2, 3])
  q.set(@[1.1, 1.2, 1.3, 1.4])
  r.set(@["hello".cstring, "world".cstring])
  s.set(@["hello", "world"])

  doAssert $p == "@[1, 2, 3]"
  doAssert q == "@[1.1, 1.2, 1.3, 1.4]"
  doAssert r == """@["hello", "world"]"""
  doAssert s == """@["hello", "world"]"""

  doAssert p & 5 == "@[1, 2, 3, 5]"
  p.add(5)
  doAssert p == "@[1, 2, 3, 5]"
  p &= 5
  doAssert p == "@[1, 2, 3, 5, 5]"
  p &= newSharedSeq(@[1, 2])
  doAssert p == "@[1, 2, 3, 5, 5, 1, 2]"
  p.delete(1)
  p.delete(5)
  doAssert p == "@[1, 3, 5, 5, 1]"
  p.insert(2, 2)
  doAssert p == "@[1, 3, 2, 5, 5, 1]"
  doAssert 1 & p == "@[1, 1, 3, 2, 5, 5, 1]"
  doAssert p == p
  doAssert q == @[1.1, 1.2, 1.3, 1.4]
  doAssert q.pop() == 1.4
  doAssert q == @[1.1, 1.2, 1.3]
  doAssert q[1] == 1.2
  q[1] = 1.0
  doAssert q == @[1.1, 1.0, 1.3]
  q.add @[1.4, 1.5]
  doAssert q == @[1.1, 1.0, 1.3, 1.4, 1.5]

  var
    t = newSharedSeq(q)

  doAssert t == q
  q.set(t)
  doAssert t == q
  t.add(q)
  doAssert t.len() == q.len() * 2

  # Multi-threaded copying

  type
    SharedSeqStuff = object
      ss1: SharedSeq[int]
      ss2: SharedSeq[int]

  proc testThread(ssQObj: ptr SharedSeqStuff) {.thread.} =
    ssQObj[].ss2.set(ssQObj.ss1)

    var
      p = newSharedSeq(@["Abc"])

  var
    ssQObj: SharedSeqStuff
    threadSeq: Thread[ptr SharedSeqStuff]

  for i in 0 .. 10:
    ssQObj.ss1.set(@[i])
    createThread(threadSeq, testThread, addr ssQObj)
    threadSeq.joinThread()

    doAssert $ssQObj.ss2 == $ssQObj.ss1, "Failed copy: " & $i

  # Readme example

  var
    sq1 = newSharedSeq(@[1, 2, 3])
    sq2 = newSharedSeq(@["a", "b", "c"])
    sq3: SharedSeq[string]

  doAssert $sq1 == $(@[1, 2, 3])
  doAssert $sq2 == $(@["a", "b", "c"])
  sq2.set(@["d", "e", "f"])
  doAssert $sq2 == $(@["d", "e", "f"])
  sq3 = sq2
  doAssert $sq3 == $(@["d", "e", "f"])

  # Multi-threaded parallel modify

  proc testThread2(ssQObj: ptr SharedSeqStuff) {.thread.} =
    sleep(10)
    ssQObj.ss1 &= getThreadId()
    sleep(10)
    ssQObj.ss2.add(newSharedSeq(@[getThreadId()]))

  var
    threads: array[11, Thread[ptr SharedSeqStuff]]

  ssQObj.ss1.free()
  ssQObj.ss2.free()

  for i in 0 .. 10:
    createThread(threads[i], testThread2, addr ssQObj)

  threads.joinThreads()

  doAssert ssQObj.ss1.len == 11
  doAssert ssQObj.ss2.len == 11

when isMainModule:
  test()