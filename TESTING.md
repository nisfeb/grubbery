# Testing grubbery on the fleet

grubbery is tested on one fake ship of the `grubbery` fleet set, built
from the hoon-development dev platform
(`~/software/personal/hoon-development`). Unlike every app's set, this one
runs grubbery **from this worktree's `desk/`** (the code under test), on a
stock ship, not the platform's pinned grubbery. Nothing here touches a
real ship: the scripts refuse any pier outside `~/fleet/piers`.

| | |
|---|---|
| set | `grubbery` (`grubbery  stock  8135  mun` in hoon-development `fleet/sets.conf`) |
| ship | `~mun`, HTTP 8135, pier `~/fleet/piers/mun`, dojo in tmux session `fleet`, window `mun` |
| grubbery | this worktree's `desk/` at eed73a6 (nisfeb/grubbery dist/single-release), installed by `GRUBBERY_SRC=... platform/build.sh`; `%unix` beside it |
| test desk | `%grubbery-test`, mounted and set up |
| snapshots | `bare`, `golden` (desk/ at eed73a6 + `%unix`), `compiled` (golden + `%grubbery-test` set up) |

```sh
F=~/software/personal/hoon-development/fleet/fleet
U=~/software/personal/hoon-development/bridge/u
```

## Reset, start, stop

```sh
$F reset grubbery compiled   # back to the set as built: ~6 s
$F up grubbery               # start ~mun as it was
$F down grubbery             # stop it (do this when done)
```

To rebuild the set from a different desk (another branch checked out
here), archive the pier and the snapshots and build again:

```sh
$F archive ~/fleet/piers/mun && rm -r ~/fleet/snaps/grubbery
cd ~/software/personal/hoon-development
GRUBBERY_SRC=~/software/groundwire/grubbery-dev-platform \
  PLATFORM_SET=grubbery platform/build.sh            # ~15 min
```

build.sh fails unless grubbery reports the expected number of files under
/code that do not compile (4 at eed73a6; `GRUBBERY_BAD=<n>` when a desk
changes that count, see hoon-development `platform/README.md`).

## The dev loop: put desk/ on the ship

```sh
scripts/ship-sync.sh ~/fleet/piers/mun
```

rsyncs `desk/` onto `~mun`'s mounted `%grubbery` and commits it over
`conn.sock` (no dojo). It prints the changed files and returns once the
commit lands; a one-file lib change took ~100 s. A change under `gub/`
rebuilds the ball, and HTTP does not answer until that is done. Names
clay cannot hold (`gub/nex/sys/WEBSOCKET.md`, `gub/nex/git/forge/CLAY.md`)
are left out. `$F reset grubbery compiled` undoes a sync.

## Offline tests (no ship)

```sh
scripts/offline-tests.sh            # 8 suites, 426 tests, ~25 s
scripts/offline-tests.sh tarball    # one suite (file name, no .hoon)
```

They run `desk/tests/*.hoon` through `vere eval`
(`scripts/hoon-test-kit/offline-test.py`), resolving `/+` imports under
`desk/lib` (`CODE=desk` in `hoon-test.conf`). `desk/tests/lib/quiz.hoon`
is not run: it imports `lattice-quiz`, which this desk does not ship.

## Ship tests

```sh
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/mun           # 426 tests, ~11 s
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/mun build     # one suite
```

The kit copies the libs the suites import (`LIBS` in `hoon-test.conf`)
and `desk/tests/*.hoon` onto `%grubbery-test` and runs every `test-` arm
there. On a rebuilt pier, make the desk in `~mun`'s dojo
(`|new-desk %grubbery-test`, `|mount %grubbery-test`) and run
`hoon-test.sh ~/fleet/piers/mun setup` first. These suites test the libs
as they are in `desk/`, so they need no ship-sync; the installed
`%grubbery` matters for the HTTP checks below.

Known failures at eed73a6 (the same files as gwbtc/grubbery develop, so
they fail there too), offline and on the ship alike:

- `build/test-build-all-no-key-for-failed-build` and
  `build/test-build-all-key-appears-after-fix`: `build-all` now gives a
  file that fails to compile a key; the tests expect none.
- `tarball/test-dap-exists-after-delete`: the expected lump literal
  predates the `gain` and `bang` fields.

## Checks on the desk itself

```sh
python3 tools/imports-resolve.py desk   # every /< import resolves; bar 0
python3 tools/desk-reach.py desk        # what nothing reaches
```

At eed73a6 `imports-resolve.py` reports 6 unresolved: the two calendar
marks' `/lib/calendar.hoon` (also in the compile report) and four
`gub/lib/docs-bundle/tools/*` importing `/lib/docs-mirror.hoon`.

## Looking inside

```sh
$U grubbery 'our'
$U grubbery kids /code/mar
$U grubbery tree /code/man
$U grubbery file /code/man/explorer/readme.md
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/mun http://localhost:8135 /tmp/mun.jar
curl -b /tmp/mun.jar 'http://localhost:8135/grubbery/ball/code/mar?list=1'   # build status per file
```

A raw `.^` that misses crashes spider on the ship; check a path with
`%cu`, `%gu` or `kids` first (hoon-development `bridge/README.md`).
