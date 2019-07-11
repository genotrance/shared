import locks

import shared/private/common
import shared/string

type
  SharedSeq*[T] = object
    ssptr*: ptr SharedObj
    typ*: T

# Seq specific

proc newSharedSeq*[T](): SharedSeq[T] =
  withLock aLock:
    result.ssptr = newShared()

proc freeSharedSeqData[T](ss: var SharedSeq[T]) =
  if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
      (ss.ssptr.len != 0):
    var
      sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

    for i in 0 .. ss.ssptr.len-1:
      decSeqDataCount()
      sss[i].deallocShared()

proc setSharedSeqData[T](ss: var SharedSeq[T], s: seq[T]) =
  ss.freeSharedSeqData()
  ss.ssptr = initShared(ss.ssptr)

  if s.len != 0:
    ss.ssptr.initSharedData(s.len, sizeof(pointer))

    var
      sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)
    ss.ssptr.size = sizeof(T)

    for i in 0 .. s.len-1:
      incSeqDataCount()
      sss[i] = allocShared0(sizeof(T))
      copyMem(sss[i], cast[pointer](unsafeAddr s[i]), sizeof(T))

proc newSharedSeq*[T](s: seq[T]): SharedSeq[T] =
  withLock aLock:
    result.ssptr = newShared()
    result.setSharedSeqData(s)

proc `=destroy`*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.ssptr.freeShared()
    ss.ssptr = nil

proc clear*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.ssptr.freeSharedData()

proc free*[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.ssptr.freeShared()
    ss.ssptr = nil

proc toSeqImpl[T](ss: SharedSeq[T]): seq[T] =
  if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
      (ss.ssptr.len != 0):
    var
      sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

    for i in 0 .. ss.ssptr.len-1:
      result.add cast[ptr T](sss[i])[]

proc toSeq*[T](ss: SharedSeq[T]): seq[T] =
  withLock aLock:
    result = ss.toSeqImpl()

proc set*[T](ss: var SharedSeq[T], c: seq[T]) =
  withLock aLock:
    ss.setSharedSeqData(c)

proc set*[T](ss: var SharedSeq[T], c: SharedSeq[T]) =
  withLock aLock:
    ss.setSharedSeqData(c.toSeqImpl())

proc len*[T](ss: SharedSeq[T]): Natural =
  withLock aLock:
    if not ss.ssptr.isNil:
      result = ss.ssptr.len

template withSharedSeq*(ss, body: untyped) {.dirty.} =
  withLock aLock:
    var
      ssSeq = ss.toSeqImpl()
    body

template setSharedSeq*(ss, body: untyped) {.dirty.} =
  withLock aLock:
    var
      ssSeq = ss.toSeqImpl()
    body
    ss.setSharedSeqData(ssSeq)

proc add*[T](c: var seq[T], ss: SharedSeq[T]) =
  withSharedSeq(ss):
    c.add(ssSeq)

proc add*[T](ss: var SharedSeq[T], c: T|SharedSeq[T]) =
  setSharedSeq(ss):
    when c is T:
      ssSeq.add(c)
    else:
      ssSeq.add(c.toSeqImpl())

proc delete*[T](ss: var SharedSeq[T], i: Natural) =
  setSharedSeq(ss):
    ssSeq.delete(i)

proc del*[T](ss: var SharedSeq[T], i: Natural) =
  ss.delete(i)

proc insert*[T](ss: var SharedSeq[T], item: T, i = 0.Natural) =
  setSharedSeq(ss):
    ssSeq.insert(item, i)

proc pop*[T](ss: var SharedSeq[T]): T =
  setSharedSeq(ss):
    result = ssSeq.pop()

proc `$`*[T](ss: SharedSeq[T]): string =
  result = $ss.toSeq()

proc `&`*[T](ss: SharedSeq[T], c: T|SharedSeq[T]): SharedSeq[T] =
  var
    ssSeq = ss.toSeq()
  ssSeq.add c
  result = newSharedSeq(ssSeq)

proc `&`*[T](c: T, ss: SharedSeq[T]): SharedSeq[T] =
  var
    ssSeq = ss.toSeq()
  ssSeq.insert(c, 0)
  result = newSharedSeq(ssSeq)

proc `&=`*[T](ss: var SharedSeq[T], c: T|SharedSeq[T]) =
  ss.add(c)

# Broken on 0.20.0 - https://github.com/nim-lang/Nim/issues/11553
proc `=`*[T](ss: var SharedSeq[T], sn: SharedSeq[T]) =
  let
    snSeq = sn.toSeq()
  withLock aLock:
    if not ss.ssptr.isNil:
      raise newException(ValueError, "Assignment not allowed, use set()")
    else:
      ss.setSharedSeqData(snSeq)

proc `[]`*[T](ss: var SharedSeq[T], i: Natural): T =
  withSharedSeq(ss):
    result = ssSeq[i]

proc `[]=`*[T](ss: var SharedSeq[T], i: Natural, value: T) =
  setSharedSeq(ss):
    ssSeq[i] = value

proc `==`*[T](ss: SharedSeq[T], c: string|cstring|SharedString): bool =
  result = $ss == $c

proc `==`*[T](ss: SharedSeq[T], c: (seq[T]|SharedSeq[T])): bool =
  withLock aLock:
    let
      ssSeq = ss.toSeqImpl()
    when c is SharedSeq[T]:
      let
        cSeq = c.toSeqImpl()
      result = ssSeq == cSeq
    else:
      result = ssSeq == c
