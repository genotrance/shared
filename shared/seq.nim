import locks

import shared/private/common

export SharedSeq

# Seq specific

proc newSharedSeq*[T](): SharedSeq[T] =
  withLock aLock:
    result.newShared()

proc freeSharedSeqData(ss: var SharedSeq) =
  if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
      (ss.ssptr.len != 0):
    var
      sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

    for i in 0 .. ss.ssptr.len-1:
      decSeqDataCount()
      sss[i].deallocShared()

proc setSharedSeqData[T](ss: var SharedSeq, s: seq[T]) =
  ss.freeSharedSeqData()
  ss.initShared()

  if s.len != 0:
    ss.initSharedData(s.len, sizeof(pointer))

    var
      sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)
    ss.ssptr.size = sizeof(T)

    for i in 0 .. s.len-1:
      incSeqDataCount()
      sss[i] = allocShared0(sizeof(T))
      copyMem(sss[i], cast[pointer](unsafeAddr s[i]), sizeof(T))

proc newSharedSeq*[T](s: seq[T]): SharedSeq[T] =
  withLock aLock:
    result.newShared()
    result.setSharedSeqData(s)

proc `=destroy`*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.freeShared()

proc clear*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.freeSharedData()

proc free*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.freeShared()

proc toSeq*[T](ss: SharedSeq[T]): seq[T] =
  withLock aLock:
    if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
        (ss.ssptr.len != 0):
      var
        sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

      for i in 0 .. ss.ssptr.len-1:
        result.add cast[ptr T](sss[i])[]

proc set*[T](ss: var SharedSeq[T], c: seq[T]) =
  withLock aLock:
    ss.setSharedSeqData(c)

proc set*[T](ss: var SharedSeq[T], c: SharedSeq[T]) =
  let
    cSeq = c.toSeq()
  withLock aLock:
    ss.setSharedSeqData(cSeq)

proc len*[T](ss: SharedSeq[T]): Natural =
  withLock aLock:
    if not ss.ssptr.isNil:
      result = ss.ssptr.len

proc `$`*[T](ss: SharedSeq[T]): string =
  result = $ss.toSeq()

#proc `&`*[T](ss: SharedSeq[T], c: T): SharedSeq[T] =
#  $ss & $c

#proc `&=`*(ss: var SharedString, c: char|string|cstring|SharedString) =
#  withLock aLock:
#    ss.setSharedStringData(ss & c)

proc `==`*[T](ss: SharedSeq[T]; c: char|string|cstring|SharedString): bool =
  result = $ss == $c
