import locks, segfaults, strutils

type
  SharedObj* = object
    len*: Natural
    size*: Natural
    sptr*: pointer

var
  aCount = cast[ptr int](allocShared0(sizeof(int)))
  aDataCount = cast[ptr int](allocShared0(sizeof(int)))
  aSeqDataCount = cast[ptr int](allocShared0(sizeof(int)))
  aLock*: Lock

aLock.initLock()

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

proc freeSharedData*(ssptr: ptr SharedObj) =
  if not ssptr.isNil:
    if not ssptr.sptr.isNil and ssptr.len != 0:
      ssptr.sptr.deallocShared()
      ssptr.len = 0
      ssptr.sptr = nil
      decDataCount()

proc freeShared*(ssptr: ptr SharedObj) =
  if not ssptr.isNil:
    ssptr.freeSharedData()
    ssptr.deallocShared()
    decCount()

proc newShared*(): ptr SharedObj =
  incCount()
  result = cast[ptr SharedObj](allocShared0(sizeof(SharedObj)))

proc initShared*(ssptr: ptr SharedObj): ptr SharedObj =
  if ssptr.isNil:
    result = newShared()
  else:
    result = ssptr

  if not result.sptr.isNil and result.len != 0:
    result.freeSharedData()

proc initSharedData*(ssptr: ptr SharedObj, len, size: Natural) =
  incDataCount()
  ssptr.len = len
  ssptr.sptr = allocShared0(len * size)
