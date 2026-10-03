/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
::  lattice-lint: the tidy report, the same one the review page at
::  /apps/lattice/know?lint=1 shows (+lint-run:lk). It proposes; fixing is
::  the caller's job, one small edit at a time.
^-  tool:tools
|%
++  name  'lattice-lint'
++  description  'What a memory tidy would fix: duplicate entries, links to missing entries, supersede links to nothing, untagged and oversized entries, entries that name code and have not been verified in 30 days, and orphans. Proposals only. Fix with small edits (lattice-supersede, lattice-verify, lattice-save, lattice-tag), never by rewriting many entries at once.'
++  parameters  ^-  (map @t parameter-def:tools)  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  ;<  now=@da  bind:m  get-time:io
  (pure:m [%text (en:json:html (lint-json:lk (lint-run:lk ~(tap by es) now)))])
--
