::  lib/ci: pure helpers for Forge CI. Workflow files, branch matching
::  and runner keys. No fibers here, so /lib/tests/ci.hoon covers all of
::  it at build time.
::
|%
::  +$  job-spec: one job of a workflow. runs-on is ~['ship'] for a ship
::  job, else the labels a runner must hold. steps stay json: the runner
::  reads them.
::
+$  job-spec
  $:  name=@ta
      runs-on=(list @t)
      timeout=@ud
      steps=json
  ==
::  +$  workflow: on.branches (~ when absent) and the jobs, by name
::
+$  workflow
  $:  branches=(unit (list @t))
      jobs=(list job-spec)
  ==
::  +parse-workflow: a workflow file's json, or why it is wrong
::
++  parse-workflow
  |=  jon=json
  ^-  (each workflow tape)
  ?.  ?=([%o *] jon)  [%| "a workflow must be a JSON object"]
  =/  branches=(each (unit (list @t)) tape)
    =/  on=(unit json)  (~(get by p.jon) 'on')
    ?~  on  [%& ~]
    ?.  ?=([%o *] u.on)  [%| "on must be an object"]
    =/  b=(unit json)  (~(get by p.u.on) 'branches')
    ?~  b  [%& ~]
    =/  names=(unit (list @t))  (strings u.b)
    ?~  names  [%| "on.branches must be a list of strings"]
    [%& names]
  ?:  ?=(%| -.branches)  [%| p.branches]
  =/  jobs=(unit json)  (~(get by p.jon) 'jobs')
  ?.  ?=([~ %o *] jobs)  [%| "jobs must be an object"]
  ?:  =(~ p.u.jobs)  [%| "jobs is empty"]
  =/  pairs=(list [@t json])
    (sort ~(tap by p.u.jobs) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
  =|  acc=(list job-spec)
  |-
  ?~  pairs  [%& p.branches (flop acc)]
  =/  one=(each job-spec tape)  (parse-job i.pairs)
  ?:  ?=(%| -.one)  [%| p.one]
  $(pairs t.pairs, acc [p.one acc])
::  +parse-job: one entry of jobs. A name becomes a path segment, so it
::  is held to lowercase letters, digits and dashes.
::
++  parse-job
  |=  [name=@t jon=json]
  ^-  (each job-spec tape)
  =/  say  |=(why=tape `tape`"job {(trip name)}: {why}")
  ?.  (name-ok name)
    [%| (say "a job name holds only lowercase letters, digits and -")]
  ?.  ?=([%o *] jon)  [%| (say "must be an object")]
  =/  runs-on=(unit (list @t))
    =/  ro=(unit json)  (~(get by p.jon) 'runs-on')
    ?~  ro  ~
    ?:  ?=([%s *] u.ro)  ?:(=('ship' p.u.ro) `~['ship'] ~)
    =/  l=(unit (list @t))  (strings u.ro)
    ?:  |(?=(~ l) ?=(~ u.l))  ~
    l
  ?~  runs-on
    [%| (say "runs-on must be \"ship\" or a non-empty list of labels")]
  =/  timeout=(unit @ud)
    =/  to=(unit json)  (~(get by p.jon) 'timeout')
    ?~  to  `60
    ?.  ?=([%n *] u.to)  ~
    =/  n=(unit @ud)  (rush p.u.to dem)
    ?:  |(?=(~ n) =(0 u.n))  ~
    n
  ?~  timeout  [%| (say "timeout must be a whole number of minutes")]
  =/  steps=(unit json)  (~(get by p.jon) 'steps')
  ?.  ?=([~ %a ^] steps)  [%| (say "steps must be a non-empty list")]
  =/  bad=(unit tape)
    ?:  =(~['ship'] u.runs-on)  (ship-steps-bad p.u.steps)
    (runner-steps-bad p.u.steps)
  ?^  bad  [%| (say u.bad)]
  [%& `@ta`name u.runs-on u.timeout u.steps]
::  +runner-steps-bad: each step is {run} or {upload}, with an optional
::  shell of bash or pwsh
::
++  runner-steps-bad
  |=  steps=(list json)
  ^-  (unit tape)
  |-
  ?~  steps  ~
  ?.  ?=([%o *] i.steps)  `"each step must be an object"
  =/  m  p.i.steps
  =/  run=?  ?=([~ %s *] (~(get by m) 'run'))
  =/  up=?   ?=([~ %s *] (~(get by m) 'upload'))
  ?.  =(1 (add ?:(run 1 0) ?:(up 1 0)))
    `"each step needs exactly one of run or upload"
  =/  sh=(unit json)  (~(get by m) 'shell')
  ?.  ?|  ?=(~ sh)
          ?=([~ %s %bash] sh)
          ?=([~ %s %pwsh] sh)
      ==
    `"shell must be bash or pwsh"
  $(steps t.steps)
::  +ship-steps-bad: each step names a tool
::
++  ship-steps-bad
  |=  steps=(list json)
  ^-  (unit tape)
  ?:  %+  levy  steps
      |=(j=json ?&(?=([%o *] j) ?=([~ %s *] (~(get by p.j) 'tool'))))
    ~
  `"each ship step must name a tool"
::  +watches: does a workflow run for this branch? An absent
::  on.branches means the repo's own branches; "*" means all.
::
++  watches
  |=  [want=(unit (list @t)) default=(list @t) branch=@t]
  ^-  ?
  =/  names=(list @t)  (fall want default)
  ?|  ?=(^ (find ~['*'] names))
      ?=(^ (find ~[branch] names))
  ==
::  +name-ok: non-empty, lowercase letters, digits and dashes
::
++  name-ok
  |=  name=@t
  ^-  ?
  =/  t=tape  (trip name)
  ?&  !=(~ t)
      %+  levy  t
      |=  c=@t
      ?|  &((gte c 'a') (lte c 'z'))
          &((gte c '0') (lte c '9'))
          =('-' c)
      ==
  ==
::  +strings: a json list of strings, or ~
::
++  strings
  |=  jon=json
  ^-  (unit (list @t))
  ?.  ?=([%a *] jon)  ~
  =/  l=(list @t)  (murn p.jon |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  ?.(=((lent l) (lent p.jon)) ~ `l)
::  +labels-hold: does a runner holding `have` satisfy `want`?
::
++  labels-hold
  |=  [have=(list @t) want=(list @t)]
  ^-  ?
  (levy want |=(w=@t ?=(^ (find ~[w] have))))
::  runner keys, on orrery's design (orrery docs/keys.md): the owner sees
::  <id>.<secret> once, the ship keeps a salted sha-256, and requests
::  carry it as `Authorization: Bearer <id>.<secret>`.
::
::  +hash-token: a salted sha-256 as text
::
++  hash-token
  |=  [salt=@t secret=@t]
  ^-  @t
  (scot %ux (shax (rap 3 salt ':' secret ~)))
::  +parse-bearer: "Bearer <id>.<secret>" to the pair, or ~. The scheme
::  is case-insensitive; the id ends at the first dot.
::
++  parse-bearer
  |=  h=@t
  ^-  (unit [id=@t secret=@t])
  =/  t=tape  (trip h)
  ?.  (gte (lent t) 8)  ~
  ?.  =("bearer " (cass (scag 7 t)))  ~
  =/  tok=tape
    =/  raw=tape  (slag 7 t)
    |-  ?:(?=([%' ' *] raw) $(raw t.raw) raw)
  =/  at=(unit @ud)  (find "." tok)
  ?~  at  ~
  =/  id=tape  (scag u.at tok)
  =/  secret=tape  (slag +(u.at) tok)
  ?:  |(=(0 (lent id)) =(0 (lent secret)))  ~
  `[(crip id) (crip secret)]
::  +secret-of, +id-of: base-32 text from disjoint slices of entropy
::
++  secret-of
  |=  eny=@
  ^-  @t
  (pad-left (skip (slag 2 (trip (scot %uv (end [3 15] eny)))) |=(c=@t =('.' c))) 20)
++  id-of
  |=  eny=@
  ^-  @t
  (pad-left (skip (slag 2 (trip (scot %uv (end [3 5] (rsh [3 16] eny))))) |=(c=@t =('.' c))) 6)
::  +pad-left: zeros in front, up to a floor
::
++  pad-left
  |=  [t=tape n=@ud]
  ^-  @t
  =/  len=@ud  (lent t)
  ?:  (gte len n)  (crip t)
  (crip (weld (reap (sub n len) '0') t))
::  +b64-text: GitHub's contents API base64, line breaks and all, to
::  text. ~ when it does not decode.
::
++  b64-text
  |=  b64=@t
  ^-  (unit @t)
  =/  clean=@t  (crip (skip (trip b64) |=(c=@t |(=(10 c) =(13 c)))))
  =/  got=(unit octs)  (de:base64:mimes:html clean)
  ?~  got  ~
  `q.u.got
--
