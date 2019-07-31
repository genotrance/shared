import locks

import shared/private/common
import shared/string

type
  SharedSeq*[T] = object
    ssptr*: ptr SharedObj
    typ*: T

# Seq specific

template eType(T: untyped) =
  when T is bool or T is char or T is SomeNumber:
    var eType {.inject.}: T
  elif T is cstring or T is system.string:
    var eType {.inject.}: pointer
  else:
    var eType {.inject.}: void
  doAssert eType isnot void, "Unsupported SharedSeq data type"

proc newSharedSeq*[T](): SharedSeq[T] =
  ## Create a new SharedSeq of type `T`
  ##
  ## The SharedSeq object itself is allocated in thread local memory and
  ## managed by the GC so that it can be garbage collected like any other
  ## stdlib data type. This means there is no need to explicitly call any
  ## dealloc or free function since it will happen automatically.
  ##
  ## The contents, however, are allocated in shared memory so that they
  ## can be used across threads safely.
  ##
  ## Care should be taken to make sure that once a SharedSeq object is
  ## shared with another thread, its address does not change. If it does,
  ## other threads will be accessing invalid memory.
  ##
  ## All SharedSeq operations ensure that any changes are localized within
  ## shared memory and not thread local memory.
  ##
  ## .. code-block:: Nim
  ##   var
  ##     ss1: SharedSeq[int]
  ##     ss2 = newSharedSeq[string]()
  ##
  ##   ss1 = newSharedSeq()
  withLock aLock:
    result.ssptr = newShared()

proc freeSharedSeqData[T](ss: var SharedSeq[T]) =
  if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
      (ss.ssptr.len != 0):
    eType(T)

    when eType is pointer:
      var
        sss = cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

      for i in 0 .. ss.ssptr.len-1:
        if not sss[i].isNil:
          decSeqDataCount()
          sss[i].deallocShared()

proc setSharedSeqData[T](ss: var SharedSeq[T], s: seq[T]) =
  ss.freeSharedSeqData()
  ss.ssptr = initShared(ss.ssptr)

  if s.len != 0:
    eType(T)

    ss.ssptr.size =
      when eType is T:
        sizeof(T)
      else:
        sizeof(pointer)

    ss.ssptr.initSharedData(s.len, ss.ssptr.size)

    var
      sss =
        when eType is T:
          cast[ptr UncheckedArray[T]](ss.ssptr.sptr)
        else:
          cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

    for i in 0 .. s.len-1:
      when eType is T:
        deepCopy(sss[i], s[i])
      else:
        if s[i].len != 0:
          incSeqDataCount()

          sss[i] = allocShared0(s[i].len()+1)

          copyMem(sss[i], s[i].cstring, s[i].len)

proc toSeqImpl[T](ss: SharedSeq[T]): seq[T] =
  if (not ss.ssptr.isNil) and (not ss.ssptr.sptr.isNil) and
      (ss.ssptr.len != 0):
    eType(T)

    var
      sss =
        when eType is T:
          cast[ptr UncheckedArray[T]](ss.ssptr.sptr)
        else:
          cast[ptr UncheckedArray[pointer]](ss.ssptr.sptr)

    for i in 0 .. ss.ssptr.len-1:
      when eType is T:
        result.add sss[i]
      else:
        var val: cstring = ""
        if not sss[i].isNil:
          let
            ssss = cast[cstring](sss[i])
          if not ssss.isNil:
            val = ssss
        when T is cstring:
          result.add val
        else:
          result.add $val

proc newSharedSeq*[T](s: seq[T]|SharedSeq[T]): SharedSeq[T] =
  ## Create a new SharedSeq of type `T` and populate with the elements
  ## of provided seq or SharedSeq.
  ##
  ## Each element of the resulting SharedSeq copied from the source and
  ## maintained in shared memory.
  ##
  ## .. code-block:: Nim
  ##   var
  ##     ss1 = newSharedSeq(@[1, 2, 3])
  withLock aLock:
    result.ssptr = newShared()
    when s is SharedSeq[T]:
      result.setSharedSeqData(s.toSeqImpl())
    else:
      result.setSharedSeqData(s)

proc `=destroy`[T](ss: var SharedSeq[T]) =
  withLock aLock:
    ss.freeSharedSeqData()
    ss.ssptr.freeShared()
    ss.ssptr = nil

proc clear*[T](ss: var SharedSeq[T]) =
  ## Clear the contents of the SharedSeq
  withLock aLock:
    ss.freeSharedSeqData()
    ss.ssptr.freeSharedData()

proc free*[T](ss: var SharedSeq[T]) =
  ## Free all memory associated with the SharedSeq
  ##
  ## This is not required unless memory needs to be recovered before
  ## the SharedSeq goes out of scope.
  ss.`=destroy`()

proc toSequence*[T](ss: SharedSeq[T]): seq[T] =
  ## Convert a SharedSeq into an stdlib seq
  ##
  ## Resulting seq is a thread local copy
  withLock aLock:
    result = ss.toSeqImpl()

proc set*[T](ss: var SharedSeq[T], c: seq[T]|SharedSeq[T]) =
  ## Repopulate SharedSeq data with contents of provided seq or SharedSeq
  ##
  ## Old contents are released if present.
  withLock aLock:
    when c is SharedSeq[T]:
      ss.setSharedSeqData(c.toSeqImpl())
    else:
      ss.setSharedSeqData(c)

proc len*[T](ss: SharedSeq[T]): Natural =
  ## Return the number of elements in the SharedSeq
  withLock aLock:
    if not ss.ssptr.isNil:
      result = ss.ssptr.len

template withSharedSeq(ss, body: untyped) {.dirty.} =
  withLock aLock:
    var
      ssSeq = ss.toSeqImpl()
    body

template setSharedSeq(ss, body: untyped) {.dirty.} =
  withLock aLock:
    var
      ssSeq = ss.toSeqImpl()
    body
    ss.setSharedSeqData(ssSeq)

proc add*[T](c: var seq[T], ss: SharedSeq[T]) =
  ## Append the contents of a SharedSeq into a stdlib seq
  withSharedSeq(ss):
    c.add(ssSeq)

proc add*[T](ss: var SharedSeq[T], c: T|seq[T]|SharedSeq[T]) =
  ## Append the element or all elements of seq or SharedSeq into
  ## a SharedSeq
  setSharedSeq(ss):
    when c is SharedSeq[T]:
      ssSeq.add(c.toSeqImpl())
    else:
      ssSeq.add(c)

proc delete*[T](ss: var SharedSeq[T], i: Natural) =
  ## Delete the i'th element from the SharedSeq
  setSharedSeq(ss):
    ssSeq.delete(i)

proc del*[T](ss: var SharedSeq[T], i: Natural) =
  ## Delete the i'th element from the SharedSeq
  ##
  ## This is *not* an optimized version like in the stdlib.
  ss.delete(i)

proc remove*[T](ss: var SharedSeq[T], s: T) =
  ## Remove the first matching element from the SharedSeq
  withSharedSeq(ss):
    let
      i = ssSeq.find(s)
    if i != -1:
      ssSeq.delete(i)

proc insert*[T](ss: var SharedSeq[T], item: T, i = 0.Natural) =
  ## Insert element in the i'th position in the SharedSeq
  setSharedSeq(ss):
    ssSeq.insert(item, i)

proc pop*[T](ss: var SharedSeq[T]): T =
  ## Pop and return the last element of the SharedSeq
  setSharedSeq(ss):
    result = ssSeq.pop()

proc contains*[T](ss: SharedSeq[T], s: T): bool =
  ## Search sequence and find element
  withSharedSeq(ss):
    result = ssSeq.contains(s)

proc `$`*[T](ss: SharedSeq[T]): string =
  ## Convert the SharedSeq into its string representation
  result = $ss.toSequence()

proc `&`*[T](ss: SharedSeq[T], c: T|seq[T]|SharedSeq[T]): SharedSeq[T] =
  ## Append SharedSeq with element or elements of seq or SharedSeq and
  ## return in a new SharedSeq
  withSharedSeq(ss):
    ssSeq.add c
    result.ssptr = newShared()
    result.setSharedSeqData(ssSeq)

proc `&`*[T](c: T|seq[T], ss: SharedSeq[T]): SharedSeq[T] =
  ## Return a new SharedSeq with element or elements of seq appended with
  ## contents of SharedSeq
  withSharedSeq(ss):
    when c is T:
      ssSeq.insert(c, 0)
    else:
      ssSeq = c & ssSeq
    result.ssptr = newShared()
    result.setSharedSeqData(ssSeq)

proc `&=`*[T](ss: var SharedSeq[T], c: T|seq[T]|SharedSeq[T]) =
  ## Append element or elements of seq or SharedSeq to the SharedSeq
  ss.add(c)

# Broken on 0.20.0 - https://github.com/nim-lang/Nim/issues/11553
proc `=`*[T](ss: var SharedSeq[T], sn: SharedSeq[T]) =
  withLock aLock:
    if not ss.ssptr.isNil:
      raise newException(ValueError, "Assignment not allowed, use set()")
    else:
      ss.setSharedSeqData(sn.toSeqImpl())

proc `[]`*[T](ss: var SharedSeq[T], i: Natural): T =
  ## Access the i'th element in SharedSeq
  withSharedSeq(ss):
    result = ssSeq[i]

proc `[]=`*[T](ss: var SharedSeq[T], i: Natural, value: T) =
  ## Set the i'th element in SharedSeq to value
  setSharedSeq(ss):
    ssSeq[i] = value

proc `==`*[T](ss: SharedSeq[T], c: string|cstring|SharedString): bool =
  result = $ss == $c

proc `==`*[T](ss: SharedSeq[T], c: (seq[T]|SharedSeq[T])): bool =
  ## Compare SharedSeq contents with another seq or SharedSeq
  withLock aLock:
    let
      ssSeq = ss.toSeqImpl()
    when c is SharedSeq[T]:
      let
        cSeq = c.toSeqImpl()
      result = ssSeq == cSeq
    else:
      result = ssSeq == c
