# Package

version       = "0.1.0"
author        = "genotrance"
description   = "Nim library for shared types"
license       = "MIT"

skipDirs = @["tests"]

import strformat

const htmldocsDir = "build/htmldocs"

when (NimMajor, NimMinor, NimPatch) >= (0, 19, 9):
  import os
  proc getNimRootDir(): string =
    fmt"{currentSourcePath}".parentDir.parentDir.parentDir

proc runNimDoc() =
  exec &"nim doc --path:. -o:{htmldocsDir} --project --index:on shared/seq.nim"
  exec &"nim doc --path:. -o:{htmldocsDir} --project --index:on shared/string.nim"
  exec &"nim buildIndex -o:{htmldocsDir}/theindex.html {htmldocsDir}"
  when declared(getNimRootDir):
    exec &"nim js -o:{htmldocsDir}/dochack.js {getNimRootDir()}/tools/dochack/dochack.nim"

task docs, "Generate docs":
  runNimDoc()

task docsPublish, "Generate and publish docs":
  # Uses: pip install ghp-import
  runNimDoc()
  exec &"ghp-import --no-jekyll -fp {htmldocsDir}"