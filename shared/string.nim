import locks

import shared/private/common

export SharedString, toHex

# String specific

proc newSharedString*(): SharedString =
  withLock aLock:
    result.newShared()

proc setSharedStringData(ss: var SharedString, s: cstring) =
  ss.initShared()

  if s.len != 0:
    ss.initSharedData(s.len + 1, sizeof(char))

    var
      ssc = cast[cstring](ss.ssptr.sptr)
    for i in 0 .. s.len:
      ssc[i] = s[i]

proc newSharedString*(s: cstring): SharedString =
  withLock aLock:
    result.newShared()
    result.setSharedStringData(s)

proc `=destroy`*(ss: var SharedString) =
  withLock aLock:
    ss.freeShared()

proc clear*(ss: var SharedString) =
  withLock aLock:
    ss.freeSharedData()

proc free*(ss: var SharedString) =
  withLock aLock:
    ss.freeShared()

proc set*(ss: var SharedString, c: char|string|cstring|SharedString) =
  withLock aLock:
    ss.setSharedStringData($c)

proc len*(ss: SharedString): Natural =
  withLock aLock:
    if not ss.ssptr.isNil:
      result = ss.ssptr.len

proc `$`*(ss: SharedString): string =
  withLock aLock:
    if not ss.ssptr.isNil:
      result = $(cast[cstring](ss.ssptr.sptr))

proc `&`*(ss: SharedString, c: char|string|cstring|SharedString): string =
  $ss & $c

proc `&=`*(ss: var SharedString, c: char|string|cstring|SharedString) =
  withLock aLock:
    ss.setSharedStringData(ss & c)

# Broken on 0.20.0 - https://github.com/nim-lang/Nim/issues/11553
proc `=`*(ss: var SharedString, sn: SharedString) =
  withLock aLock:
    if not ss.ssptr.isNil:
      raise newException(ValueError, "Assignment not allowed, use set()")
    else:
      ss.setSharedStringData($sn)

proc `[]`*(ss: var SharedString, i: Natural): char =
  withLock aLock:
    result = ($ss)[i]

proc `[]=`*(ss: var SharedString, i: Natural, value: char) =
  withLock aLock:
    if ss.ssptr.isNil or ss.ssptr.sptr.isNil or ss.ssptr.len == 0:
      raise newException(IndexError, "SharedString not initialized")
    elif ss.ssptr.len <= i:
      raise newException(IndexError, "Index out of bounds")
    var
      s = cast[cstring](ss.ssptr.sptr)
    s[i] = value

proc `==`*(ss: SharedString; c: char|string|cstring|SharedString): bool =
  result = $ss == $c
