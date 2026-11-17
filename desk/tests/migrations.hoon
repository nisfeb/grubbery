/+  *test, nexus, migrations
::  +sweep-hist rebuilds a history whose tree is damaged instead of
::  crashing: a %7 ship's root fold history held a node with an atom
::  tail, and every load from %7 failed in +tap on it.
::
=>
|%
++  hon  hon-12:migrations
+$  hist  hist-12:migrations
++  entry
  |=  n=@ud
  ^-  [cass:clay entry-12:migrations]
  [[n (add ~2026.1.1 (mul n ~s1))] [[%firm [~ `@uvI`n]] ~]]
++  five  (gas:hon *hist (turn (gulf 1 5) entry))
::  the same tree with the root's left child cut down to [n 0], a node
::  whose tail is an atom
++  damaged
  ^-  hist
  =/  raw=*  five
  ?>  ?=([* [* * *] *] raw)
  =/  bad=*  [-.raw [[-.+<.raw 0] +>.raw]]
  !<(hist [-:!>(*hist) bad])
--
|%
++  test-tap-crashes-on-the-damaged-tree
  (expect-fail |.((tap:hon damaged)))
::
++  test-sweep-hist-keeps-a-healthy-history
  %+  expect-eq
    !>((tap:hon five))
  !>((tap:hon (sweep-hist:migrations / five)))
::
++  test-sweep-hist-rebuilds-a-damaged-history
  =/  out=hist  (sweep-hist:migrations / damaged)
  =/  keys=(list @ud)  (turn (tap:hon out) |=([k=cass:clay *] ud.k))
  ;:  weld
    ::  the result walks
    (expect-eq !>(%.y) !>(?=(^ keys)))
    ::  the top version survives, and nothing is invented
    (expect-eq !>(5) !>((rear keys)))
    (expect-eq !>(%.y) !>((levy keys |=(k=@ud &((gte k 1) (lte k 5))))))
    ::  only what hung below the damaged node is lost
    (expect-eq !>(%.y) !>((gth (lent keys) 1)))
  ==
--
