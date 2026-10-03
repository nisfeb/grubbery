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
  ::  bytes of core text at most; past it, core keys are listed only. Here,
  ::  not an arm: a tool's core has exactly the five arms of tool:tools.
  =/  core-cap=@ud  14.000
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  live=(list [k=path e=know-entry:lk])
    (skim ~(tap by es) |=([* e=know-entry:lk] =(~ (superseded:lk e))))
  ::  an area is the first segment, or the first two for a key three deep
  =/  area
    |=  k=path
    ^-  [path path]
    ::  cast first: scag and slag are wet, and fail on a narrowed list
    =/  p=path  k
    ?:  ?=([@ @ @ *] k)  [(scag 2 p) (slag 2 p)]
    [(scag 1 p) (slag 1 p)]
  =/  groups=(map path (list path))
    %+  roll  live
    |=  [[k=path *] g=(map path (list path))]
    =/  [a=path r=path]  (area k)
    (~(put by g) a [r (~(gut by g) a ~)])
  =/  lines=(list tape)
    %+  turn  (sort ~(tap by groups) |=([a=[p=path *] b=[p=path *]] (aor p.a p.b)))
    |=  [a=path rs=(list path)]
    =/  names=(list tape)  (turn (sort rs aor) |=(r=path (slag 1 (spud r))))
    =/  joined=tape  (zing (join ", " names))
    =/  head=tape  (slag 1 (spud a))
    =/  n=tape  (a-co:co (lent rs))
    :(weld head " (" n "): " joined)
  =/  core=(list [k=path e=know-entry:lk])
    (sort (skim live |=([* e=know-entry:lk] (~(has in tags.e) 'core'))) |=([a=[k=path *] b=[k=path *]] (aor k.a k.b)))
  =/  core-text=tape
    =|  [out=tape used=@ud]
    |-  ^-  tape
    ?~  core  out
    =/  body=tape  (trip rest:(front:lk body.e.i.core))
    =/  key=tape  (spud k.i.core)
    ?:  (gth (add used (lent body)) core-cap)
      $(core t.core, out :(weld out "## " key " (over the cap: read it)\0a\0a"))
    $(core t.core, out :(weld out "## " key "\0a" body "\0a\0a"), used (add used (lent body)))
  =/  total=tape  (a-co:co (lent live))
  =/  index=tape  (zing (join "\0a" lines))
  =/  core-head=tape  ?~(core "" "\0a\0aCore (applies to every task):\0a\0a")
  %-  pure:m
  :-  %text
  %-  crip
  ;:  weld
    total  " memories. Find by task with lattice-recall, read one with lattice-read.\0a\0a"
    index
    core-head
    core-text
  ==
--
