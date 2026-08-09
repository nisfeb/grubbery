::  migrations: agent state versions
::
::  Deliberately empty of migration machinery. The runtime's core
::  data structures are still moving too fast for migrations to be
::  worth their weight — on a breaking state change, nuke the agent
::  and start fresh at %0. Real migrations begin once the core
::  structures stabilize (see ratchet.md).
::
/+  nexus, tarball
|%
::  state-0: the full state of the grubbery agent.
::
::  Each field is one of three kinds. Truth fields are the namespace
::  itself and cannot be regenerated. Derived fields can be rebuilt
::  from the truth fields. Live fields are runtime state and also
::  cannot be regenerated.
::
+$  state-0
  $:  %0
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      =pool:nexus   ::  live: the running process for each grub
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-1: what a ship that ran the perf/combined branch has.
::
::  That branch bumped the state to carry three additive fields — two
::  caches (marcs, nexi) and the eyre server-state — and never landed
::  here. Any pier that ran it holds %1, and develop could only load
::  %0, so those ships could not come back: gall refused the upgrade
::  with -have.%1 -need.%0 and kept running the old code.
::
::  Defined so the vase can be read. Nothing here produces a %1.
::
+$  state-1
  $:  %1
      =born:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      marcs=(map @uv marc:tarball)
      nexi=(map @uv nexus:nexus)
      =remo:nexus
      =upki:nexus
      =server-state:nexus
      last=[now=@da eny=@uvJ]
  ==
::  1 -> 0: drop the three fields %0 does not have.
::
::  Safe to drop, each for its own reason. marcs and nexi are caches
::  keyed by build hash — %0 simply recomputes what it needs. The
::  server-state is the one worth stating: %1 moved it into agent
::  state for speed, but it left the grub at /sys/eyre/main.server-state
::  in place as the recorded binding registry, and %0 reads bindings
::  from exactly that grub. So the bindings survive; what is lost is
::  the live conns, which are per-connection bookkeeping that does not
::  outlive an upgrade anyway.
::
::  last is identical in both (+$ last:nexus is [now eny]), so it
::  carries across unchanged.
::
++  state-1-to-0
  |=  old=state-1
  ^-  state-0
  :*  %0
      born.old
      silo.old
      subs.old
      pool.old
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
--
