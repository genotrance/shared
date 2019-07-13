shared is a [Nim](https://nim-lang.org/) library for shared types

Nim has a great string and seq implementation but sharing them across thread boundaries is problematic due to the thread local GC. This package attempts to provide basic shared types that can be used across threads.

The API attempts to be the same but not as extensive as the standard API. E.g. $ and & work as expected, but not every capability is being duplicated. Further, the implementation aims for safety and performance may not be the priority until later on. Every assignment results in realloc and copy to keep things simple.

__Installation__

shared can be installed via [Nimble](https://github.com/nim-lang/nimble):

```
> nimble install shared
```

This will download and install shared in the standard Nimble package location, typically ~/.nimble. Once installed, it can be imported into any Nim program.

__Usage__

Detailed documentation [here](https://genotrance.github.io/shared/theindex.html).

```nim
import shared/string

var
  ss1 = newSharedString("abc")

echo ss1
ss1 = "def"
echo ss1
```

```nim
import shared/seq

var
  sq1 = newSharedSeq(@[1, 2, 3])
  sq2 = newSharedSeq(@["a", "b", "c"])
  sq3: SharedSeq[string]

echo sq1
echo sq2
sq2.set(@["d", "e", "f"])
sq3 = sq2
```

__Feedback__

shared is a work in progress and any feedback or suggestions are welcome. It is hosted on [GitHub](https://github.com/genotrance/shared) with an MIT license so issues, forks and PRs are most appreciated.
