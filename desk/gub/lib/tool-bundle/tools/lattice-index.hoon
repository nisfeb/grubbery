/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
::  lattice-index: the session-start call. Every live key, grouped by area
::  and compressed to its last segments (about a quarter of lattice-list's
::  size), then the full text of the entries tagged `core`: the rules that
::  apply to every task, loaded rather than left to a search hitting.
^-  tool:tools
|%
++  name  'lattice-index'
++  description  'Session start: every memory key grouped by area, plus the full text of the core entries (rules that apply to every task). Call once at the start of a session, then use lattice-recall for the task at hand.'
++  parameters  ^-  (map @t parameter-def:tools)  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  (pure:m [%text (index-text:lk es | core-cap:lk)])
--
