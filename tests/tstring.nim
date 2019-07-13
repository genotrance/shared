import os

import shared/string

# Single threaded basic tests

proc test() =
  var
    a = newSharedString()
    b = newSharedString("abc")
    c = newSharedString("def".cstring)
    d: SharedString
    e = newSharedString('c')
    f = newSharedString(b)

  doAssert a == ""
  doAssert $b == "abc"
  doAssert c == "def"

  doAssert b & 'c' == "abcc"
  doAssert $(b & "d") == "abcd"
  doAssert $(b & "e".cstring) == "abce"
  doAssert $(b & c) == "abcdef"

  b &= 'c'
  doAssert b == "abcc"

  c.set("ghi")
  doAssert $c == "ghi"

  try:
    c = b
    doAssert false, "Should not assign"
  except ValueError:
    discard

  d = b
  doAssert $d == "abcc"

  a.free()
  a = b
  doAssert $a == "abcc"

  c.clear()
  doAssert $c == ""

  doAssert b[0] == 'a'
  try:
    echo b[5]
    doAssert false, "Out of bounds"
  except IndexError:
    discard

  b[1] = 'B'
  doAssert b == "aBcc"

  # Multi-threaded copying

  type
    SharedStuff = object
      ss1: SharedString
      ss2: SharedString

  proc testThread(ssObj: ptr SharedStuff) {.thread.} =
    ssObj[].ss2.set(ssObj.ss1)

    var
      p = newSharedString("Abc")

  var
    ssObj: SharedStuff
    thread: Thread[ptr SharedStuff]

  for i in 0 .. 10:
    ssObj.ss1.set($i)
    createThread(thread, testThread, addr ssObj)
    thread.joinThread()

    doAssert $ssObj.ss2 == $ssObj.ss1, "Failed copy: " & $i

  # Multi-threaded parallel modify

  proc testThread2(ssObj: ptr SharedStuff) {.thread.} =
    sleep(10)
    ssObj.ss1 &= $getThreadId() & ", "

  var
    threads: array[11, Thread[ptr SharedStuff]]

  ssObj.ss1.set($getThreadId() & ", ")

  for i in 0 .. 10:
    createThread(threads[i], testThread2, addr ssObj)

  threads.joinThreads()

  doAssert ssObj.ss1.len > 10

  # Direct share

  proc testThread3(ss: ptr SharedString) {.thread.} =
    ss[].set("bye")

  var
    ss = newSharedString("hello")
    thread3: Thread[ptr SharedString]

  createThread(thread3, testThread3, addr ss)
  thread3.joinThread()
  doAssert ss == "bye"

when isMainModule:
  test()