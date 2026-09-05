#!/usr/bin/env bash
# Trim the lattice-only distribution desk down to what lattice needs.
#
# WHY: a fresh install compiles every hoon file in the ball in one event.
# Upstream develop carries the wallet, git, obelisk, calendar and assistant
# libraries and their tests; lattice imports none of them, yet every
# installer paid to compile them (about 1,300 results, ~6 minutes and over
# 2 GB of loom on a small machine, which is where one install died).
#
# SCOPE: the ball (gub/) only. That is what every install compiles; desk-level
# lib/ and tests/ are clay's, built only when something asks (a -test run),
# and the lattice test suites there are wanted on any ship that carries this.
#
# WHAT STAYS, always: both agents, lib/root.hoon, the lattice, mcp and port
# nexuses, EVERY mark under gub/mar and mar (a ship that ran upstream may
# hold grubs of those marks in its ball; a mark that no longer compiles
# strands that data), every sur, every MCP tool, and everything any of
# those import. The list below is exactly the files unreachable from that
# root set (tools/desk-reach.py: follows /- /+ /= /* and the ball's /< /& /*
# imports and [/dir %name] marc references, with ford's rule that a /+ name
# may spell a nested path with '-' for '/', e.g. wasm-lia = lib/wasm/lia).
# Clay is the backstop: a commit that deletes a file a kept file imports is
# refused with 'no files match' or %file-not-found, and nothing changes.
#
# SAFE PATH BACK TO UPSTREAM: this is a pure deletion of files nothing on the
# lattice-only desk references. The agent name, desk name, marks and agent
# state versions are unchanged, so a ship on this desk moves to the official
# desk with
#     |unsync %grubbery ~ricsul-bilwyt %grubbery
#     |install <upstream-ship> %grubbery
# and kiln brings every trimmed file back with the rest of upstream.
#
# HOW TO KEEP IT: after `git merge origin/develop` on dist/lattice-only,
# resolve any conflict on a listed file by deleting it, then run this script
# and commit. Re-check the list when upstream adds imports to something we
# keep (a mark or an MCP tool gaining a new /lib dependency), because that
# dependency must come back.
#
# The publisher's clay does not learn deletions from its mount. To apply a
# trim on ~ricsul-bilwyt, generate `|pass [%c %info %grubbery %.y ~[[/path [%del ~]] ...]]`
# lines from this list (mount a/b/c.ext -> clay /a/b/c/ext) and paste them
# into its dojo; installers then pick the deletions up through kiln sync.
set -euo pipefail
cd "$(dirname "$0")/../desk"
removed=0
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in \#*) continue;; esac
  if [ -e "$p" ]; then git rm -q "$p"; removed=$((removed + 1)); fi
done <<'LIST'
gub/lib/assistants/morning-brief.hoon
gub/lib/assistants/weekly-outlook.hoon
gub/lib/bech32.hoon
gub/lib/bip39-english.hoon
gub/lib/bip39.hoon
gub/lib/cron.hoon
gub/lib/der.hoon
gub/lib/feather-icons.hoon
gub/lib/feather.hoon
gub/lib/git/bundle.hoon
gub/lib/git/hash.hoon
gub/lib/git/object.hoon
gub/lib/git/pack.hoon
gub/lib/git/refs.hoon
gub/lib/git/refspec.hoon
gub/lib/git/repository.hoon
gub/lib/git/transport.hoon
gub/lib/ics.hoon
gub/lib/lattice-fuzz.hoon
gub/lib/lattice-quiz.hoon
gub/lib/math.hoon
gub/lib/mip.hoon
gub/lib/nex/assistant.hoon
gub/lib/nex/obelisk-db.hoon
gub/lib/obelisk-types.hoon
gub/lib/obelisk.hoon
gub/lib/obelisk/crud.hoon
gub/lib/obelisk/ddl.hoon
gub/lib/obelisk/main.hoon
gub/lib/obelisk/parse.hoon
gub/lib/obelisk/predicate.hoon
gub/lib/obelisk/scalars.hoon
gub/lib/obelisk/selections.hoon
gub/lib/obelisk/sys-views.hoon
gub/lib/obelisk/utils.hoon
gub/lib/oneshot.hoon
gub/lib/rules/cron.hoon
gub/lib/rules/daily.hoon
gub/lib/rules/every.hoon
gub/lib/rules/monthly-nth.hoon
gub/lib/rules/monthly.hoon
gub/lib/rules/once.hoon
gub/lib/rules/weekly.hoon
gub/lib/rules/yearly.hoon
gub/lib/seed-phrases.hoon
gub/lib/server.hoon
gub/lib/shell.hoon
gub/lib/sur/asn1.hoon
gub/lib/sur/transactions.hoon
gub/lib/taproot.hoon
gub/lib/test-obelisk.hoon
gub/lib/test.hoon
gub/lib/tests/git-cmd.hoon
gub/lib/tests/git-object.hoon
gub/lib/tests/git-transport.hoon
gub/lib/tests/goals.hoon
gub/lib/tests/obelisk.hoon
gub/lib/tests/rules.hoon
gub/lib/tx/auth.hoon
gub/lib/tx/build.hoon
gub/lib/tx/draft.hoon
gub/lib/tx/encode.hoon
gub/lib/tx/fees.hoon
gub/lib/tx/select.hoon
gub/lib/tx/sighash.hoon
gub/lib/tx/signer.hoon
gub/nex/oneshot.hoon
gub/nex/openrouter.hoon
gub/nex/openrouter/app.js
gub/nex/openrouter/icon.svg
gub/nex/openrouter/index.html
gub/nex/openrouter/style.css
gub/nex/rhizome.hoon
gub/nex/s3.hoon
gub/nex/s3/bridge.hoon
gub/nex/telegram-bot.hoon
gub/nex/telegram.hoon
LIST
echo "trim-lattice-only: removed $removed files"
