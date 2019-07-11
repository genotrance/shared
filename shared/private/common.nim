import locks, segfaults, strutils

type
  SharedObj* = object
    len*: Natural
    size*: Natural
    sptr*: pointer

  SharedString* = object
    ssptr*: ptr SharedObj

  SharedSeq*[T] = object
    ssptr*: ptr SharedObj

var
  aCount = cast[ptr int](allocShared0(sizeof(int)))
  aDataCount = cast[ptr int](allocShared0(sizeof(int)))
  aSeqDataCount = cast[ptr int](allocShared0(sizeof(int)))
  aLock*: Lock

aLock.initLock()

proc toHex*(ss: SharedString|SharedSeq): string =
  result = cast[int](ss.ssptr).toHex() & " " & $getThreadId()

proc checkOnExit() {.noconv.} =
  doAssert aCount[] == 0, "All shared instances not freed: " & $aCount[]
  doAssert aDataCount[] == 0, "All shared data instances not freed: " & $aDataCount[]
  doAssert aSeqDataCount[] == 0, "All shared seq data instances not freed: " & $aSeqDataCount[]

  aCount.deallocShared()
  aDataCount.deallocShared()
  aSeqDataCount.deallocShared()

  aLock.deinitLock()

addQuitProc(checkOnExit)

proc incCount*() =
  doAssert aCount[] >= 0, "aCount is negative"
  aCount[] += 1

proc incDataCount*() =
  doAssert aDataCount[] >= 0, "aDataCount is negative"
  aDataCount[] += 1

proc incSeqDataCount*() =
  doAssert aSeqDataCount[] >= 0, "aSeqDataCount is negative"
  aSeqDataCount[] += 1

proc decCount*() =
  aCount[] -= 1
  doAssert aCount[] >= 0, "aCount is negative"

proc decDataCount*() =
  aDataCount[] -= 1
  doAssert aDataCount[] >= 0, "aDataCount is negative"

proc decSeqDataCount*() =
  aSeqDataCount[] -= 1
  doAssert aSeqDataCount[] >= 0, "aSeqDataCount is negative"

proc freeSharedData*(ss: var (SharedString|SharedSeq)) =
  if not ss.ssptr.isNil:
    if not ss.ssptr.sptr.isNil and ss.ssptr.len != 0:
      ss.ssptr.sptr.deallocShared()
      ss.ssptr.len = 0
      ss.ssptr.sptr = nil
      decDataCount()

proc freeShared*(ss: var (SharedString|SharedSeq)) =
  if not ss.ssptr.isNil:
    ss.freeSharedData()
    ss.ssptr.deallocShared()
    ss.ssptr = nil
    decCount()

proc newShared*(ss: var (SharedString|SharedSeq)) =
  incCount()
  ss.ssptr = cast[ptr SharedObj](allocShared0(sizeof(SharedObj)))

proc initShared*(ss: var (SharedString|SharedSeq)) =
  if ss.ssptr.isNil:
    ss.newShared()

  if not ss.ssptr.sptr.isNil and ss.ssptr.len != 0:
    ss.freeSharedData()

proc initSharedData*(ss: var (SharedString|SharedSeq), len, size: Natural) =
  incDataCount()
  ss.ssptr.len = len
  ss.ssptr.sptr = allocShared0(len * size)
