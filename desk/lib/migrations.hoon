::  migrations: agent state versions
::
::  Mostly empty of migration machinery. The runtime's core data
::  structures are still moving too fast for migrations to be worth
::  their weight — on a breaking change to the nexus types, nuke the
::  agent and start fresh. Additive agent-state changes (new fields)
::  ride a version bump with a migration gate below (see ratchet.md).
::
/+  nexus, tarball
|%
::  state-0: pre-1 — uses live nexus types
::
+$  state-0
  $:  %0
      =born:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      =remo:nexus
      =upki:nexus
      last=[now=@da eny=@uvJ]
  ==
::  state-1: current — three additive fields.
::
::  marcs: memoized !<(marc:tarball ...) extractions keyed by the
::  compiled mark's ckey, so the nest check is paid once per built
::  mark instead of once per grub read per event.
::
::  nexi: nexus cores extracted from /nex artifacts, cached by ckey
::  so +build-nexus skips the !< nest on every fiber spawn.
::
::  server-state: the eyre binding registry plus live conns. conns
::  are per-connection bookkeeping; recording them through the
::  versioned store cost two full write pipelines per HTTP request.
::  The grub at /sys/eyre/main.server-state stays the recorded
::  binding registry, with conns cleared there.
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
::  0 -> 1: both caches start empty — marcs repopulates lazily via
::  +record/+bootstrap-marcs, nexi is warmed by cold-start. The
::  server-state is bunted here and seeded from the existing grub in
::  +on-load, which is where the store is readable.
::
++  state-0-to-1
  |=  old=state-0
  ^-  state-1
  :*  %1
      born.old
      silo.old
      subs.old
      pool.old
      code.old
      bins.old
      vale.old
      ~
      ~
      remo.old
      upki.old
      *server-state:nexus
      last.old
  ==
--
