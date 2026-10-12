#!/usr/bin/env bash
# ship-sync.sh: put this worktree's desk/ on a fleet ship's %grubbery
# and commit it, with no dojo, so the ship runs the code under test.
# The commit rebuilds the ball (minutes); HTTP does not answer meanwhile.
#
#   scripts/ship-sync.sh <pier>      e.g. ~/fleet/piers/mun
#
# Only a pier under ~/fleet/piers whose %grubbery is mounted; never a
# real ship. Uses the kit's khan-over-conn.sock framing; VERE defaults
# to the newest ~/software/vere-*-linux-x86_64.
set -euo pipefail
cd "$(dirname "$0")/.."
pier=$(cd "${1:?usage: ship-sync.sh <pier>}" && pwd)
[[ $pier == "$HOME/fleet/piers/"* ]] || { echo "refusing $pier: not a fleet pier" >&2; exit 2; }
[[ -f $pier/grubbery/sys.kelvin ]] || { echo "%grubbery is not mounted at $pier/grubbery" >&2; exit 2; }
sock=$pier/.urb/conn.sock
[[ -S $sock ]] || { echo "$pier is not running (no conn.sock)" >&2; exit 4; }
VERE=${VERE:-$(ls -1d ~/software/vere-*-linux-x86_64 | sort -V | tail -1)}
ted() { # one-line hoon strand -> its product, as vere prints it
  printf '%s\n' "[0 %fyrd [%base %khan-eval %noun [%ted-eval '$1']]]" |
    "$VERE" eval --jam -n 2>/dev/null |
    socat -T 120 -,ignoreeof UNIX-CONNECT:"$sock" 2>/dev/null |
    "$VERE" eval --cue -n 2>/dev/null | tail -1
}
hash() { ted '=/  m  (strand ,vase)  ;<  h=@uvI  bind:m  (scry @uvI /cz/grubbery)  (pure:m !>(h))'; }
# a name clay cannot hold (gub/nex/sys/WEBSOCKET.md: upper case) never
# reaches the mount, so it is left out (and a directory left empty by
# that) or every sync would see it as new; only file changes count
changed=$(rsync -rcim --delete --exclude='*[A-Z]*' desk/ "$pier/grubbery/" | grep -v '^cd' || true)
[[ -n $changed ]] || { echo "%grubbery already matches desk/"; exit 0; }
echo "$changed"
before=$(hash)
ted '=/  m  (strand ,vase)  ;<  =bowl  bind:m  get-bowl  ;<  ~  bind:m  (poke [our.bowl %hood] kiln-commit+!>([%grubbery |]))  (pure:m !>(%ok))' >/dev/null
for _ in $(seq 120); do [[ $(hash) != "$before" ]] && { echo "committed %grubbery; the ball rebuilds now"; exit 0; }; sleep 1; done
echo "the commit did not land in 120 s; see the ship's terminal" >&2; exit 1
