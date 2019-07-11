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

  # Multi-threaded copying

  type
    SharedSeqStuff = object
      ss1: SharedSeq[int]
      ss2: SharedSeq[int]

  proc testThread3(ssObj: ptr SharedSeqStuff) {.thread.} =
    ssObj[].ss2.set(ssObj.ss1)

    var
      p = newSharedSeq(@["Abc"])

  var
    ssQObj: SharedSeqStuff
    threadSeq: Thread[ptr SharedSeqStuff]

  for i in 0 .. 10:
    ssQObj.ss1.set(@[i])
    createThread(threadSeq, testThread3, addr ssQObj)
    threadSeq.joinThread()

    doAssert $ssQObj.ss2 == $ssQObj.ss1, "Failed copy: " & $i

when isMainModule:
  test()