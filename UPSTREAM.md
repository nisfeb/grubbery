# dist/lattice-only and the path back to upstream

This branch is the desk that `|install ~ricsul-bilwyt %grubbery` delivers:
gwbtc/grubbery `develop` plus a short stack of commits (the lattice overlay
vendored into `gub/`, the docket, a state downgrade, a marc fix, and the trim
below). It keeps upstream's desk name, agent names, marks and agent state
versions on purpose, so a ship on it can move to the official desk at any
time and nothing it holds is stranded.

## Moving a ship to upstream

```
|unsync %grubbery ~ricsul-bilwyt %grubbery
|install <upstream-publisher> %grubbery
```

Kiln replaces the desk contents with upstream's, gall reloads the agents
with their existing state (versions 0 and 1 are upstream's own; 2 and 3 are
handled by `lib/migrations.hoon` for ships that ran the perf lineage), and
every file this branch removed comes back with the rest of upstream. Grubs
in the ball keep their marks because this branch never removes a mark.

## The trim

`tools/trim-lattice-only.sh` deletes the upstream libraries, nexuses and
tests that nothing on a lattice-only desk references. The list is computed
by reachability from the agents, `lib/root.hoon`, the lattice, mcp and port
nexuses, every mark, every sur and every MCP tool, following the ford runes
and the ball's own `/<` imports and `[/dir %name]` marc references. The
script explains why and how to re-check the list.

Invariants the trim must keep, in order of importance:

1. Every mark stays (`gub/mar`, `mar`), with everything a mark imports.
2. Both agents and their state versions are byte-identical to upstream
   apart from the added downgrade cases.
3. `desk.bill` and `sys.kelvin` are upstream's.
4. Nothing under `gub/nex/lattice` or `gub/nex/mcp` imports a removed file
   (the script's list is regenerated after every upstream merge).

## After merging upstream

```
git fetch origin develop
git merge origin/develop        # resolve a listed file's conflict by deleting it
tools/trim-lattice-only.sh
git commit
```

Then rehearse on the fake ship before the publisher. The publisher's clay
never learns deletions from its mount; deletions go in as
`|pass [%c %info %grubbery %.y ~[[/a/b/c/hoon [%del ~]] ...]]` lines pasted
into its dojo, naming only files its clay actually holds (a single missing
path fails the whole commit), a few dozen per line.
