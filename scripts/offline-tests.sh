#!/usr/bin/env bash
# offline-tests.sh: run grubbery's Hoon suites (desk/tests/*.hoon) with
# no ship, through vere eval (scripts/hoon-test-kit/offline-test.py),
# all at once; about 30 s. The ship run (TESTING.md) stays the verdict.
# desk/tests/lib/quiz.hoon is not run: it imports lattice-quiz, which
# this desk does not ship.
#
#   scripts/offline-tests.sh              every suite
#   scripts/offline-tests.sh NAME ...     by file name, no .hoon
set -uo pipefail
cd "$(dirname "$0")/.."
if (($#)); then names=("$@"); else
  names=()
  for f in desk/tests/*.hoon; do n=${f#desk/tests/}; names+=("${n%.hoon}"); done
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pids=()
for n in "${names[@]}"; do
  python3 scripts/hoon-test-kit/offline-test.py "desk/tests/$n.hoon" \
    > "$tmp/$n" 2>&1 &
  pids+=($!)
done
fail=0
for i in "${!names[@]}"; do
  n=${names[i]}; wait "${pids[i]}"; rc=$?
  printf '%-10s %s\n' "$n" "$(tail -1 "$tmp/$n")"
  ((rc == 0)) || { fail=1; sed -n '1,40p' "$tmp/$n"; }
done
exit $fail
