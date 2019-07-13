import locks

import shared/private/common

type
  SharedString* = object
    ssptr*: ptr SharedObj

# String specific

proc newSharedString*(): SharedString =
  withLock aLock:
    result.ssptr = newShared()

proc setSharedStringData(ss: var SharedString, s: cstring) =
  ss.ssptr = initShared(ss.ssptr)

  if s.len != 0:
    ss.ssptr.initSharedData(s.len + 1, sizeof(char))

    var
      ssc = cast[cstring](ss.ssptr.sptr)
    for i in 0 .. s.len:
      ssc[i] = s[i]

proc toStringImpl(ss: SharedString): string =
  if not ss.ssptr.isNil:
    result = $(cast[cstring](ss.ssptr.sptr))

proc newSharedString*(c: char|cstring|string|SharedString): SharedString =
  withLock aLock:
    result.ssptr = newShared()
    when c is SharedString:
      result.setSharedStringData(c.toStringImpl())
    else:
      result.setSharedStringData($c)

proc `=destroy`(ss: var SharedString) =
  withLock aLock:
    ss.ssptr.freeShared()
    ss.ssptr = nil

proc clear*(ss: var SharedString) =
  withLock aLock:
    ss.ssptr.freeSharedData()

proc free*(ss: var SharedString) =
  withLock aLock:
    ss.ssptr.freeShared()
    ss.ssptr = nil

proc set*(ss: var SharedString, c: char|string|cstring|SharedString) =
  withLock aLock:
    let
      cStr = when c is SharedString: c.toStringImpl() else: $c
    ss.setSharedStringData(cStr)

proc len*(ss: SharedString): Natural =
  withLock aLock:
    if not ss.ssptr.isNil:
      result = ss.ssptr.len

proc `$`*(ss: SharedString): string =
  withLock aLock:
    result = ss.toStringImpl()

proc `&`*(ss: SharedString, c: char|string|cstring|SharedString): string =
  withLock aLock:
    let
      cStr = when c is SharedString: c.toStringImpl() else: $c
    result = ss.toStringImpl() & cStr

proc `&=`*(ss: var SharedString, c: char|string|cstring|SharedString) =
  withLock aLock:
    let
      cStr = when c is SharedString: c.toStringImpl() else: $c
    ss.setSharedStringData(ss.toStringImpl() & cStr)

# Broken on 0.20.0 - https://github.com/nim-lang/Nim/issues/11553
proc `=`*(ss: var SharedString, sn: SharedString) =
  withLock aLock:
    if not ss.ssptr.isNil:
      raise newException(ValueError, "Assignment not allowed, use set()")
    else:
      ss.setSharedStringData(sn.toStringImpl())

proc `[]`*(ss: var SharedString, i: Natural): char =
  result = ($ss)[i]

proc `[]=`*(ss: var SharedString, i: Natural, value: char) =
  withLock aLock:
    var
      ssStr = ss.toStringImpl()
    ssStr[i] = value
    ss.setSharedStringData(ssStr)

proc `==`*(ss: SharedString, c: char|string|cstring|SharedString): bool =
  withLock aLock:
    let
      cStr = when c is SharedString: c.toStringImpl() else: $c
    result = ss.toStringImpl() == cStr
