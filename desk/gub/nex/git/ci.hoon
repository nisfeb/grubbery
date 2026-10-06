::  git/ci: Forge CI. Watched GitHub repos, the job queue, and the
::  external runners that build what the ship cannot. Forge mounts it at
::  /ci, so Forge's weir is its sandbox. The plan is
::  .grubbery/docs/forge-ci-plan.md in the grubbery repo.
::
::  /main.sig                  HTTP at /grubbery/forge/ci: the owner's page
::                             and API (cookie), the runner API (Bearer key)
::  /requests/<id>             one grub per HTTP request
::  /watched/<name>.json       a watched repo {repo, branches, minutes};
::                             its fiber is that repo's poller
::  /seen/<name>.json          last tip seen per branch, written by the poller
::  /runners/<id>.json         owner settings: name, repos, enabled, salt, hash
::  /status/<id>.json          what the runner last said: labels, os, seen
::  /queue/<run>-<job>.json    a runner job waiting to be claimed
::  /runs/<run>/run.json       repo, branch, commit, workflow, trigger
::  /runs/<run>/<job>.json     job state. Its fiber is the only writer;
::                             routes change a job by poking it.
::  /logs/<run>/<job>/<seq>    log chunks, never rewritten
::
::  Nothing here is gained, so every write is %temp and no history piles up.
::
/<  ci            /lib/ci.hoon
/<  nw            /lib/nexus-web.hoon
/<  git-transport  /lib/git/transport.hoon
/&  ci-html       ci/index.html
/&  ci-js         ci/app.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /watched empty-dir:loader]
          [%fall %| /seen empty-dir:loader]
          [%fall %| /runners empty-dir:loader]
          [%fall %| /status empty-dir:loader]
          [%fall %| /queue empty-dir:loader]
          [%fall %| /runs empty-dir:loader]
          [%fall %| /logs empty-dir:loader]
          [%over %& [/ %'index.html'] [[/ %mime] ci-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ci-js]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%ci main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/forge/ci])
        (http-dispatch:io %ci)
      ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%ci request: failed")
        (serve rail)
      ::
          [[%watched ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%ci poller: failed")
        (poller rail)
      ::
          [[%runs @ ~] @]
        ?:  =(%'run.json' name.rail)  stay:m
        (job-fiber rail prod)
      ==
    --
|%
++  protocol  1
++  poll-seconds  60
::  +live: how long a running job may go without a log chunk
::
++  live  ~m5
::  +keep-runs: runs kept per repo; older ones and their logs are culled
::
++  keep-runs  50
::  +chunk-max, +chunk-count: one log chunk and how many a job keeps
::  (2 MB in all)
::
++  chunk-max  16.384
++  chunk-count  128
::
++  web  ~(. web:nw [%| 1 %& ~ %'main.sig'])
++  jget  jget:nw
++  jnum  jnum:nw
++  ms
  |=  now=@da
  ^-  @ud
  (div (sub now ~1970.1.1) (div ~s1 1.000))
++  jlist
  |=  [jon=json k=@t]
  ^-  (list @t)
  ?.  ?=([%o *] jon)  ~
  =/  v=(unit json)  (~(get by p.jon) k)
  ?~  v  ~
  (fall (strings:ci u.v) ~)
++  jput
  |=  [jon=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] jon)  jon
  [%o (~(put by p.jon) k v)]
++  jputs
  |=  [jon=json l=(list [@t json])]
  ^-  json
  ?.  ?=([%o *] jon)  jon
  [%o (~(gas by p.jon) l)]
++  jsa  |=(l=(list @t) `json`[%a (turn l |=(t=@t s+t))])
++  nums  |=(n=@ud (numb:enjs:format n))
::  +view-json: a file view as json, or ~
::
++  view-json
  |=  =view:nexus
  ^-  (unit json)
  ?.  ?=([%file *] view)  ~
  (mole |.(;;(json (sang-noun:tarball sang.view))))
::  +ball-jsons: the json files directly in a ball, by name
::
++  ball-jsons
  |=  =ball:tarball
  ^-  (list [@ta json])
  ?~  fil.ball  ~
  %+  murn  ~(tap by contents.u.fil.ball)
  |=  [nam=@ta ent=[=sang:tarball *]]
  =/  j=(unit json)  (mole |.(;;(json (sang-noun:tarball sang.ent))))
  ?~(j ~ `[nam u.j])
++  peek-json
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  has=?  bind:m  (peek-exists:io road)
  ?.  has  (pure:m ~)
  ;<  v=view:nexus  bind:m  (peek:io road ~)
  (pure:m (view-json v))
++  peek-ball
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,ball:tarball)
  ^-  form:m
  ;<  has=?  bind:m  (peek-exists:io road)
  ?.  has  (pure:m *ball:tarball)
  ;<  v=view:nexus  bind:m  (peek:io road ~)
  (pure:m ?.(?=([%ball *] v) *ball:tarball ball.v))
::  +put-json: make or overwrite a json file
::
++  put-json
  |=  [=road:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  has=?  bind:m  (peek-exists:io road)
  ?:  has  (over:io road [[/ %json] jon])
  (make:io road |+[[[/ %json] jon] ~])
::
::  =====  github, through the proxy  =====
::
::  +gh-root: the github proxy, found by name through /sys/link
::
++  gh-root
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  gh=(unit lane:tarball)  bind:m  (resolve-link:io '@github')
  ?.  ?=([~ %| *] gh)  (pure:m ~)
  (pure:m `p.u.gh)
++  gh-id
  =/  m  (fiber:fiber:nexus ,@ta)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  (pure:m (crip ((x-co:co 16) (end 6 eny))))
::  +gh-wait: keep a lifecycle grub, poke, and take its terminal state
::  or give up after `lull`. The caller culls.
::
++  gh-wait
  |=  [grub=road:tarball lull=@dr done=$-(view:nexus ?)]
  =/  m  (fiber:fiber:nexus ,(unit view:nexus))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /gh-deadline (add now lull))
  |-
  ;<  res=news-or-wake:io  bind:m  (take-news-or-wake-on:io /gh /gh-deadline)
  ?:  ?=(%wake -.res)
    ;<  ~  bind:m  (drop:io /gh grub)
    (pure:m ~)
  ;<  v=view:nexus  bind:m  (peek:io grub ~)
  ?.  (done v)  $
  ;<  ~  bind:m  (cancel-timer:io /gh-deadline)
  ;<  ~  bind:m  (drop:io /gh grub)
  (pure:m `v)
::  +gh-tips: every branch's tip, by git's ref advertisement (ls-remote).
::  No objects cross.
::
++  gh-tips
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,(each (map @t @t) @t))
  ^-  form:m
  ;<  root=(unit path)  bind:m  gh-root
  ?~  root  (pure:m [%| 'no github proxy in /sys/link'])
  ;<  id=@ta  bind:m  gh-id
  =/  grub=road:tarball  [%& %& (weld u.root /xfer) id]
  ;<  *  bind:m  (keep:io /gh grub ~)
  ;<  ~  bind:m
    (poke:io [%& %& u.root %'main.sig'] [[/ %noun] [%xfer id [%discovery '' repo]]])
  =/  done
    |=  v=view:nexus
    ?.  ?=([%file *] v)  %.n
    =/  l  (mole |.(;;($%([%pending *] [%done *] [%fail *]) (sang-noun:tarball sang.v))))
    &(?=(^ l) !?=(%pending -.u.l))
  ;<  got=(unit view:nexus)  bind:m  (gh-wait grub ~m2 done)
  ;<  *  bind:m  (cull-soft:io grub)
  ?~  got  (pure:m [%| 'github did not answer within 2 minutes'])
  ?.  ?=([%file *] u.got)  (pure:m [%| 'github answer vanished'])
  =/  life  (mole |.(;;($%([%done =octs] [%fail =tang]) (sang-noun:tarball sang.u.got))))
  ?~  life  (pure:m [%| 'github answer did not parse'])
  ?:  ?=(%fail -.u.life)
    (pure:m [%| (crip ~(ram re (fall (bind (snag-unit 0 tang.u.life) same) leaf+"fetch failed")))])
  =/  disc  (mule |.((parse-discovery:git-transport octs.u.life)))
  ?:  ?=(%| -.disc)  (pure:m [%| 'not a git ref advertisement'])
  %-  pure:m
  :-  %&
  %-  malt
  %+  murn  refs.p.disc
  |=  r=git-ref:git-transport
  ?.  ?=([%refs %heads *] refname.r)  ~
  =/  branch=@t  (crip (join:git-transport '/' (turn t.t.refname.r trip)))
  `[branch (crip (print-hash-sha-1:git-transport hash.r))]
++  snag-unit
  |*  [i=@ud l=(list)]
  ?:  (gte i (lent l))  ~
  `(snag i l)
::  +gh-rest: one GET on the GitHub REST API: [code body] or why not
::
++  gh-rest
  |=  pax=@t
  =/  m  (fiber:fiber:nexus ,(each [code=@ud body=json] @t))
  ^-  form:m
  ;<  root=(unit path)  bind:m  gh-root
  ?~  root  (pure:m [%| 'no github proxy in /sys/link'])
  ;<  id=@ta  bind:m  gh-id
  =/  grub=road:tarball  [%& %& (weld u.root /calls) (cat 3 id '.json')]
  ;<  *  bind:m  (keep:io /gh grub ~)
  =/  req=json
    %-  pairs:enjs:format
    :~  ['id' s+id]
        ['req' (pairs:enjs:format ~[['method' s+'GET'] ['path' s+pax]])]
    ==
  ;<  ~  bind:m  (poke:io [%& %& u.root %'main.sig'] [[/ %json] req])
  =/  done
    |=  v=view:nexus
    =('done' (jget (fall (view-json v) ~) 'status'))
  ;<  got=(unit view:nexus)  bind:m  (gh-wait grub ~m2 done)
  ;<  *  bind:m  (cull-soft:io grub)
  ?~  got  (pure:m [%| 'github did not answer within 2 minutes'])
  =/  jon=json  (fall (view-json u.got) ~)
  =/  body=json  ?.(?=([%o *] jon) ~ (fall (~(get by p.jon) 'body') ~))
  (pure:m [%& (jnum jon 'code' 0) body])
::  +gh-workflows: the workflow files at a commit, each parsed or with
::  the reason it is not a workflow. ~ when the repo has none.
::
++  gh-workflows
  |=  [repo=@t sha=@t]
  =/  m  (fiber:fiber:nexus ,(each (list [@t (each workflow:ci tape)]) @t))
  ^-  form:m
  ;<  dir=(each [code=@ud body=json] @t)  bind:m
    (gh-rest (rap 3 '/repos/' repo '/contents/.grubbery/workflows?ref=' sha ~))
  ?:  ?=(%| -.dir)  (pure:m [%| p.dir])
  ?:  =(404 code.p.dir)  (pure:m [%& ~])
  ?.  =(200 code.p.dir)
    (pure:m [%| (crip "listing workflows: GitHub answered {<code.p.dir>}")])
  =/  names=(list [name=@t pax=@t])
    ?.  ?=([%a *] body.p.dir)  ~
    %+  murn  p.body.p.dir
    |=  e=json
    =/  nam=@t  (jget e 'name')
    ?.  =('file' (jget e 'type'))  ~
    ?.  =(".json" (slag (sub (max 5 (met 3 nam)) 5) (trip nam)))  ~
    `[nam (jget e 'path')]
  =|  acc=(list [@t (each workflow:ci tape)])
  |-
  ?~  names  (pure:m [%& (flop acc)])
  ;<  got=(each [code=@ud body=json] @t)  bind:m
    (gh-rest (rap 3 '/repos/' repo '/contents/' pax.i.names '?ref=' sha ~))
  =/  wf=(each workflow:ci tape)
    ?:  ?=(%| -.got)  [%| (trip p.got)]
    ?.  =(200 code.p.got)  [%| "GitHub answered {<code.p.got>}"]
    =/  text=(unit @t)  (b64-text:ci (jget body.p.got 'content'))
    ?~  text  [%| "the file did not decode"]
    =/  jon=(unit json)  (de:json:html u.text)
    ?~  jon  [%| "not valid JSON"]
    (parse-workflow:ci u.jon)
  =/  base=@t  (crip (scag (sub (met 3 name.i.names) 5) (trip name.i.names)))
  $(names t.names, acc [[base wf] acc])
::
::  =====  runs and jobs  =====
::
::  +start-runs: one run per workflow that watches the branch, each job
::  queued. A workflow that does not parse makes a run whose single job
::  failed with the reason, so a broken file is seen, not silent.
::
++  start-runs
  |=  $:  =rail:tarball
          repo=@t
          branch=@t
          sha=@t
          trigger=@t
          default=(list @t)
      ==
  =/  m  (fiber:fiber:nexus ,(each @ud @t))
  ^-  form:m
  ;<  wfs=(each (list [@t (each workflow:ci tape)]) @t)  bind:m
    (gh-workflows repo sha)
  ?:  ?=(%| -.wfs)  (pure:m [%| p.wfs])
  =/  todo=(list [name=@t wf=(each workflow:ci tape)])
    %+  skim  p.wfs
    |=  [name=@t wf=(each workflow:ci tape)]
    ?:  ?=(%| -.wf)  %.y
    (watches:ci branches.p.wf default branch)
  =/  made=@ud  0
  |-
  ?~  todo
    ;<  ~  bind:m  (prune-runs rail repo)
    (pure:m [%& made])
  ;<  now=@da  bind:m  get-time:io
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  run=@ta  `@ta`(crip "{(a-co:co (ms now))}-{((x-co:co 4) (end 4 eny))}")
  =/  head=json
    %-  pairs:enjs:format
    :~  ['run' s+run]
        ['repo' s+repo]
        ['branch' s+branch]
        ['sha' s+sha]
        ['workflow' s+name.i.todo]
        ['trigger' s+trigger]
        ['made' (nums (ms now))]
    ==
  =/  jobs=(list [@ta json])
    ?:  ?=(%| -.wf.i.todo)
      :~  :-  %workflow
          (job-json head %workflow ~ 0 ~ 'failed' (crip p.wf.i.todo))
      ==
    %+  turn  jobs.p.wf.i.todo
    |=  j=job-spec:ci
    :-  name.j
    ?:  =(~['ship'] runs-on.j)
      %:  job-json  head  name.j  runs-on.j  timeout.j  steps.j
        'failed'  'ship jobs need a mirrored repo, and this one is watched'
      ==
    (job-json head name.j runs-on.j timeout.j steps.j 'queued' '')
  =/  run-json=json
    (jput head 'jobs' (jsa (turn jobs |=([n=@ta *] `@t`n))))
  =/  files=(map @ta [bask:tarball ?])
    (malt `(list [@ta [bask:tarball ?]])`~[['run.json' [[/ %json] run-json] %.n]])
  =/  log-dirs=(map @ta bole:tarball)
    (malt (turn jobs |=([nam=@ta *] [nam `bole:tarball`empty-dir:loader])))
  ;<  ~  bind:m
    (make:io (nex-road:io rail [%| /logs/[`@ta`run]]) &+`bole:tarball`[`[~ ~ %.n ~] log-dirs])
  ;<  ~  bind:m
    (make:io (nex-road:io rail [%| /runs/[`@ta`run]]) &+`bole:tarball`[`[~ ~ %.n files] ~])
  ::  each job is its own make: a file that arrives inside a directory
  ::  make gets no fiber until the nexus next reloads
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    |-  ^-  form:m
    ?~  jobs  (pure:m ~)
    ;<  ~  bind:m  (make:io (job-road rail run -.i.jobs) |+[[[/ %json] +.i.jobs] ~])
    $(jobs t.jobs)
  $(todo t.todo, made +(made))
::  +job-json: a job's state as first written
::
++  job-json
  |=  $:  head=json
          name=@ta
          runs-on=(list @t)
          timeout=@ud
          steps=json
          state=@t
          error=@t
      ==
  ^-  json
  =/  base=(map @t json)  ?.(?=([%o *] head) ~ p.head)
  :-  %o
  %-  ~(gas by base)
  :~  ['job' s+name]
      ['runs_on' (jsa runs-on)]
      ['timeout' (nums timeout)]
      ['steps' steps]
      ['state' s+state]
      ['error' s+error]
      ['runner' s+'']
      ['lease' s+'']
      ['cancel' b+%.n]
      ['started' ~]
      ['ended' ?:(=('queued' state) ~ (fall (~(get by base) 'made') ~))]
      ['source' s+'github']
  ==
::  +prune-runs: keep a repo's newest runs, cull the rest with their logs
::
++  prune-runs
  |=  [=rail:tarball repo=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  runs=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /runs]))
  =/  mine=(list @ta)
    %+  sort
      %+  murn  ~(tap by dir.runs)
      |=  [nam=@ta b=ball:tarball]
      =/  r  (skim (ball-jsons b) |=([n=@ta *] =(%'run.json' n)))
      ?~  r  ~
      ?.(=(repo (jget +.i.r 'repo')) ~ `nam)
    |=([a=@ta b=@ta] (aor b a))
  =/  old=(list @ta)  (slag keep-runs mine)
  |-
  ?~  old  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%| /runs/[i.old]]))
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%| /logs/[i.old]]))
  $(old t.old)
::
::  +job-fiber: a job's life. Queued, it keeps a marker in /queue and
::  waits for a claim or a cancel. Running, it waits for the runner's
::  result, resetting its liveness deadline on every log chunk. Ended,
::  it stays. A crash closes the job as failed with the crash text.
::
++  job-fiber
  |=  [=rail:tarball =prod:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  st=json  bind:m  (get-state-as:io ,json)
  ?^  prod
    ?.  (live-state (jget st 'state'))  stay:m
    (finish rail st 'failed' (crip "crashed: {(trip (render-tang:build u.prod))}"))
  |-
  ;<  st=json  bind:m  (get-state-as:io ,json)
  =/  state=@t  (jget st 'state')
  ?:  =('queued' state)
    ;<  ~  bind:m  (put-json (marker-road rail st) (marker-json st))
    ;<  =sage:tarball  bind:m  take-poke:io
    =/  cmd=json  (fall (mole |.(!<(json q.sage))) ~)
    =/  verb=@t  (jget cmd 'cmd')
    ?:  =('cancel' verb)
      ;<  *  bind:m  (cull-soft:io (marker-road rail st))
      (finish rail st 'cancelled' '')
    ?.  =('claim' verb)  $
    ;<  now=@da  bind:m  get-time:io
    =/  new=json
      %+  jputs  st
      :~  ['state' s+'running']
          ['runner' s+(jget cmd 'runner')]
          ['lease' s+(jget cmd 'lease')]
          ['started' (nums (ms now))]
      ==
    ;<  ~  bind:m  (replace:io new)
    ;<  *  bind:m  (cull-soft:io (marker-road rail st))
    $
  ?.  =('running' state)  stay:m
  (running rail st)
::  +running: a claimed job. Every log chunk resets the liveness
::  deadline; the job's timeout bounds the whole. The runner ends it with
::  `done`; a cancel is passed to the runner on its next log answer.
::
++  running
  |=  [=rail:tarball st=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  log=road:tarball  (log-road rail st)
  ;<  *  bind:m  (keep:io /log log ~)
  ;<  ~  bind:m  (set-timer:io /live (add now live))
  =/  limit=@da
    %+  add  ~1970.1.1
    %+  mul  (div ~s1 1.000)
    (add (jnum st 'started' (ms now)) (mul 60.000 (jnum st 'timeout' 60)))
  ;<  ~  bind:m  (set-timer:io /limit ?:((gth limit now) limit now))
  |-
  ;<  ev=job-event  bind:m  take-job-event
  ;<  st=json  bind:m  (get-state-as:io ,json)
  ?-    -.ev
      %news
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (set-timer:io /live (add now live))
    $
  ::
      %live
    ?:  =(b+%.y (fall (bind (find-key st 'cancel') same) b+%.n))
      (end-running rail st log 'cancelled' 'cancelled; the runner stopped answering')
    (end-running rail st log 'failed' 'runner lost: no log for 5 minutes')
  ::
      %limit
    %:  end-running  rail  st  log  'failed'
      (crip "timed out after {(a-co:co (jnum st 'timeout' 60))} minutes")
    ==
  ::
      %poke
    =/  verb=@t  (jget cmd.ev 'cmd')
    ?:  =('cancel' verb)
      ;<  ~  bind:m  (replace:io (jput st 'cancel' b+%.y))
      $
    ?.  =('done' verb)  $
    ?.  =((jget st 'lease') (jget cmd.ev 'lease'))  $
    =/  status=@t  (jget cmd.ev 'status')
    ?.  ?=(?(%'succeeded' %'failed' %'cancelled') status)  $
    =/  arts=json
      ?.  ?=([%o *] cmd.ev)  [%a ~]
      (fall (~(get by p.cmd.ev) 'artifacts') [%a ~])
    (end-running rail (jput st 'artifacts' arts) log status (jget cmd.ev 'error'))
  ==
++  find-key
  |=  [jon=json k=@t]
  ^-  (unit json)
  ?.  ?=([%o *] jon)  ~
  (~(get by p.jon) k)
::  +$  job-event: what a running job waits for
::
+$  job-event
  $%  [%news ~]
      [%live ~]
      [%limit ~]
      [%poke cmd=json]
  ==
++  take-job-event
  =/  m  (fiber:fiber:nexus ,job-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.  =(/log wire.u.in)  [%skip ~]
    [%done %news ~]
      [~ %poke * *]
    ?:  =([/ %timer-wake] p.sage.u.in)
      =/  w=path  (fall (mole |.(!<(path q.sage.u.in))) /)
      ?:  =(/live w)  [%done %live ~]
      ?:  =(/limit w)  [%done %limit ~]
      [%skip ~]
    ?.  =([/ %json] p.sage.u.in)  [%skip ~]
    [%done %poke (fall (mole |.(!<(json q.sage.u.in))) ~)]
  ==
++  end-running
  |=  [=rail:tarball st=json log=road:tarball state=@t error=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (cancel-timer:io /live)
  ;<  ~  bind:m  (cancel-timer:io /limit)
  ;<  ~  bind:m  (drop:io /log log)
  (finish rail st state error)
++  finish
  |=  [=rail:tarball st=json state=@t error=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m
    (replace:io (jputs st ~[['state' s+state] ['error' s+error] ['ended' (nums (ms now))]]))
  stay:m
++  live-state
  |=  state=@t
  ?=(?(%'queued' %'running') state)
::  +job-key: <run>-<job>, the job's name in /queue
::
++  job-key
  |=  st=json
  ^-  @ta
  (rap 3 (jget st 'run') '-' (jget st 'job') ~)
++  marker-road
  |=  [=rail:tarball st=json]
  ^-  road:tarball
  (nex-road:io rail [%& /queue (cat 3 (job-key st) '.json')])
++  marker-json
  |=  st=json
  ^-  json
  %-  pairs:enjs:format
  :~  ['run' s+(jget st 'run')]
      ['job' s+(jget st 'job')]
      ['repo' s+(jget st 'repo')]
      ['labels' (jsa (jlist st 'runs_on'))]
  ==
++  log-road
  |=  [=rail:tarball st=json]
  ^-  road:tarball
  (nex-road:io rail [%| (log-dir st)])
++  job-road
  |=  [=rail:tarball run=@t job=@t]
  ^-  road:tarball
  (nex-road:io rail [%& /runs/[`@ta`run] `@ta`(cat 3 job '.json')])
++  log-dir
  |=  st=json
  ^-  path
  /logs/[`@ta`(jget st 'run')]/[`@ta`(jget st 'job')]
::
::  =====  watched repos  =====
::
::  +poller: a watched repo's fiber. Checks the repo's branch tips now
::  and every `minutes` after, and wakes early when its settings change.
::
++  poller
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  self=road:tarball  (nex-road:io rail [%& /watched name.rail])
  ;<  *  bind:m  (keep:io /self self `[/ %json])
  |-
  ;<  cfg=json  bind:m  (get-state-as:io ,json)
  ;<  err=(unit @t)  bind:m  (check-watched rail cfg)
  ;<  ~  bind:m
    ?~  err  (pure:(fiber:fiber:nexus ,~) ~)
    %-  (slog leaf+"%ci {(trip name.rail)}: {(trip u.err)}" ~)
    (pure:(fiber:fiber:nexus ,~) ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /poll (add now (mul ~m1 (max 1 (jnum cfg 'minutes' 5)))))
  ;<  *  bind:m  (take-news-or-wake-on:io /self /poll)
  $
::  +seen-road: where a watched repo's poller keeps the tips it has seen
::
++  seen-road
  |=  [=rail:tarball name=@ta]
  ^-  road:tarball
  (nex-road:io rail [%& /seen name])
::  +check-watched: new tips on watched branches start runs. The first
::  look at a repo only records its tips, so turning CI on builds no
::  history. Runs are made before the tip is recorded: a crash between
::  costs a duplicate run, never a skipped commit.
::
++  check-watched
  |=  [=rail:tarball cfg=json]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  repo=@t  (jget cfg 'repo')
  =/  branches=(list @t)  (jlist cfg 'branches')
  ;<  tips=(each (map @t @t) @t)  bind:m  (gh-tips repo)
  ?:  ?=(%| -.tips)  (pure:m `p.tips)
  =/  road=road:tarball  (seen-road rail name.rail)
  ;<  old=(unit json)  bind:m  (peek-json road)
  =/  seen=(map @t json)  ?.(?=([~ %o *] old) ~ p.u.old)
  =/  now-tips=(list [@t @t])
    (murn branches |=(b=@t (bind (~(get by p.tips) b) |=(h=@t [b h]))))
  ?~  old
    ;<  ~  bind:m  (put-json road [%o (malt (turn now-tips |=([b=@t h=@t] [b s+h])))])
    (pure:m ~)
  =/  moved=(list [@t @t])
    (skim now-tips |=([b=@t h=@t] !=(`s+h (~(get by seen) b))))
  =|  err=(unit @t)
  |-
  ?~  moved  (pure:m err)
  =/  [b=@t h=@t]  i.moved
  ;<  res=(each @ud @t)  bind:m  (start-runs rail repo b h 'push' branches)
  ?:  ?=(%| -.res)  (pure:m `p.res)
  ;<  cur=(unit json)  bind:m  (peek-json road)
  =/  now-seen=(map @t json)  ?.(?=([~ %o *] cur) ~ p.u.cur)
  ;<  ~  bind:m  (put-json road [%o (~(put by now-seen) b s+h)])
  $(moved t.moved)
::
::  =====  HTTP  =====
::
++  serve
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  eyre-id=@ta  name.rail
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path
    (skip (slag (lent `path`/grubbery/forge/ci) site) |=(s=@ta =('' s)))
  =/  body=json  (fall (post-json:nw req) ~)
  ?:  ?=([%runner *] suffix)
    (runner-api rail eyre-id req t.suffix body)
  ?.  authenticated.req  (reply:web eyre-id 403 'forbidden')
  (owner-api rail eyre-id req suffix args body)
++  send-code
  |=  [eyre-id=@ta code=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  send-simple:srv:web  eyre-id
  :_  `(as-octs:mimes:html (en:json:html jon))
  [code ['content-type' 'application/json'] ~]
++  send-err
  |=  [eyre-id=@ta code=@ud msg=@t]
  (send-code eyre-id code (pairs:enjs:format ~[['error' s+msg]]))
++  quay-get
  |=  [args=quay:eyre k=@t]
  ^-  @t
  =/  l  (skim args |=([p=@t q=@t] =(p k)))
  ?~(l '' q.i.l)
::
::  +runner-api: requests carrying a runner's key. Keys are checked
::  here, not by eyre; the owner's cookie is not a runner key.
::
++  runner-api
  |=  [=rail:tarball eyre-id=@ta req=inbound-request:eyre suffix=path body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  auth=(unit @t)  (get-header:http 'authorization' header-list.request.req)
  =/  tok=(unit [id=@t secret=@t])  ?~(auth ~ (parse-bearer:ci u.auth))
  ?~  tok  (send-err eyre-id 401 'missing or malformed runner key')
  ?.  (name-ok:ci id.u.tok)  (send-err eyre-id 401 'invalid or revoked key')
  =/  rid=@ta  id.u.tok
  ;<  cfg=(unit json)  bind:m  (peek-json (nex-road:io rail [%& /runners (cat 3 rid '.json')]))
  ?~  cfg  (send-err eyre-id 401 'invalid or revoked key')
  ?.  =((jget u.cfg 'hash') (hash-token:ci (jget u.cfg 'salt') secret.u.tok))
    (send-err eyre-id 401 'invalid or revoked key')
  ?.  =('POST' method.request.req)  (send-err eyre-id 405 'POST only')
  =/  stat-road=road:tarball  (nex-road:io rail [%& /status (cat 3 rid '.json')])
  ;<  now=@da  bind:m  get-time:io
  ;<  old=(unit json)  bind:m  (peek-json stat-road)
  =/  stat=json  (jput (fall old (pairs:enjs:format ~)) 'seen' (nums (ms now)))
  ?+    suffix  (send-err eyre-id 404 'no such runner route')
      [%hello ~]
    ?.  =(protocol (jnum body 'protocol' 0))
      (send-err eyre-id 426 (crip "this Forge speaks runner protocol {(a-co:co protocol)}"))
    =/  new=json
      %+  jputs  stat
      :~  ['labels' (jsa (jlist body 'labels'))]
          ['os' s+(jget body 'os')]
          ['arch' s+(jget body 'arch')]
          ['version' s+(jget body 'version')]
          ['job' s+'']
      ==
    ;<  ~  bind:m  (put-json stat-road new)
    (send-code eyre-id 200 (pairs:enjs:format ~[['poll' (nums poll-seconds)]]))
  ::
      [%poll ~]
    ;<  ~  bind:m  (put-json stat-road stat)
    ?:  =(b+%.n (fall (find-key u.cfg 'enabled') b+%.y))
      (send-code eyre-id 204 ~)
    ;<  job=(unit json)  bind:m  (claim-next rail rid u.cfg stat)
    ?~  job  (send-code eyre-id 204 ~)
    ;<  ~  bind:m  (put-json stat-road (jput stat 'job' s+(job-key u.job)))
    (send-code eyre-id 200 (job-for-runner u.job))
  ::
      [%log ~]
    ;<  st=(each json @t)  bind:m  (held-job rail rid body)
    ?:  ?=(%| -.st)  (send-err eyre-id 409 p.st)
    =/  seq=@ud  (jnum body 'seq' 0)
    =/  text=@t  (jget body 'text')
    =/  text=@t  ?:((gth (met 3 text) chunk-max) (end [3 chunk-max] text) text)
    =/  log=road:tarball  (log-road rail p.st)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m
      ::  an empty chunk is a heartbeat: one rewritten grub, so it keeps the
      ::  job alive without spending one of its chunks
      ?:  =('' text)
        %+  put-json  (nex-road:io rail [%& (log-dir p.st) %'beat.json'])
        (pairs:enjs:format ~[['at' (nums (ms now))]])
      ?:  (gte seq chunk-count)
        %+  put-json  (nex-road:io rail [%& (log-dir p.st) %'overflow.json'])
        (pairs:enjs:format ~[['dropped' (nums seq)]])
      =/  name=@ta  (crip "{(pad-seq seq)}.txt")
      =/  road=road:tarball
        (nex-road:io rail [%& (log-dir p.st) name])
      ;<  has=?  bind:(fiber:fiber:nexus ,~)  (peek-exists:io road)
      ?:  has  (pure:(fiber:fiber:nexus ,~) ~)
      (make:io road |+[[[/ %mime] [/text/plain (as-octs:mimes:html text)]] ~])
    =/  cancel=json  (fall (find-key p.st 'cancel') b+%.n)
    (send-code eyre-id 200 (pairs:enjs:format ~[['cancel' cancel]]))
  ::
      [%done ~]
    ;<  st=(each json @t)  bind:m  (held-job rail rid body)
    ?:  ?=(%| -.st)  (send-err eyre-id 409 p.st)
    ;<  err=(unit tang)  bind:m
      %+  poke-soft:io  (job-road rail (jget p.st 'run') (jget p.st 'job'))
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['cmd' s+'done']
          ['lease' s+(jget body 'lease')]
          ['status' s+(jget body 'status')]
          ['error' s+(jget body 'error')]
          ['artifacts' (fall (find-key body 'artifacts') [%a ~])]
      ==
    ;<  ~  bind:m  (put-json stat-road (jput stat 'job' s+''))
    (send-code eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y]]))
  ::
      [%source ~]  (send-err eyre-id 501 'runner/source comes with mirrored repos (phase 4)')
      [%upload ~]  (send-err eyre-id 501 'artifact storage comes in phase 2')
  ==
++  pad-seq
  |=  n=@ud
  ^-  tape
  =/  t=tape  (a-co:co n)
  (weld (reap (sub 6 (min 6 (lent t))) '0') t)
::  +held-job: the job a runner names, if that runner holds it by lease
::
++  held-job
  |=  [=rail:tarball rid=@ta body=json]
  =/  m  (fiber:fiber:nexus ,(each json @t))
  ^-  form:m
  =/  [run=@t job=@t]
    =/  key=tape  (trip (jget body 'job'))
    =/  at=(unit @ud)  (find "/" key)
    ?~  at  ['' '']
    [(crip (scag u.at key)) (crip (slag +(u.at) key))]
  ?.  &((name-ok:ci job) !=('' run))  (pure:m [%| 'bad job id'])
  ;<  st=(unit json)  bind:m  (peek-json (job-road rail run job))
  ?~  st  (pure:m [%| 'no such job'])
  ?.  =('running' (jget u.st 'state'))  (pure:m [%| 'the job is not running'])
  ?.  &(=(rid (jget u.st 'runner')) =((jget body 'lease') (jget u.st 'lease')))
    (pure:m [%| 'this runner does not hold that job'])
  (pure:m [%& u.st])
::  +claim-next: the oldest queued job this runner may take, claimed.
::  The job fiber accepts a claim only while queued, so two runners
::  racing for one job cannot both win: each reads the job back.
::
++  claim-next
  |=  [=rail:tarball rid=@ta cfg=json stat=json]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  q=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /queue]))
  =/  have=(list @t)  (jlist stat 'labels')
  =/  repos=(list @t)  (jlist cfg 'repos')
  =/  todo=(list json)
    %+  murn  (sort (ball-jsons q) |=([a=[@ta *] b=[@ta *]] (aor -.a -.b)))
    |=  [@ta mk=json]
    ?.  (labels-hold:ci have (jlist mk 'labels'))  ~
    ?.  |(=(~ repos) ?=(^ (find ~[(jget mk 'repo')] repos)))  ~
    `mk
  |-
  ?~  todo  (pure:m ~)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  lease=@t  (secret-of:ci eny)
  =/  road=road:tarball  (job-road rail (jget i.todo 'run') (jget i.todo 'job'))
  ;<  err=(unit tang)  bind:m
    %+  poke-soft:io  road
    :-  [/ %json]
    (pairs:enjs:format ~[['cmd' s+'claim'] ['runner' s+rid] ['lease' s+lease]])
  ;<  st=(unit json)  bind:m  (peek-json road)
  ?:  ?&  ?=(^ st)
          =(rid (jget u.st 'runner'))
          =(lease (jget u.st 'lease'))
          =('running' (jget u.st 'state'))
      ==
    (pure:m st)
  $(todo t.todo)
::  +job-for-runner: what a runner is told about its job
::
++  job-for-runner
  |=  st=json
  ^-  json
  %-  pairs:enjs:format
  :~  ['job' s+(rap 3 (jget st 'run') '/' (jget st 'job') ~)]
      ['lease' s+(jget st 'lease')]
      ['repo' s+(jget st 'repo')]
      ['sha' s+(jget st 'sha')]
      ['branch' s+(jget st 'branch')]
      ['source' s+(jget st 'source')]
      ['clone_url' s+(rap 3 'https://github.com/' (jget st 'repo') '.git' ~)]
      ['timeout' (nums (jnum st 'timeout' 60))]
      ['steps' (fall (find-key st 'steps') [%a ~])]
  ==
::
::  +owner-api: the page and its JSON, behind the owner's cookie
::
++  owner-api
  |=  $:  =rail:tarball
          eyre-id=@ta
          req=inbound-request:eyre
          suffix=path
          args=quay:eyre
          body=json
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  =('POST' method.request.req)
    ?+    suffix  (send-err eyre-id 404 'not found')
        [%api %watched %add ~]   (add-watched rail eyre-id body)
        [%api %watched %delete ~]
      =/  name=@t  (jget body 'name')
      ?.  (name-ok:ci name)  (send-err eyre-id 400 'bad name')
      ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /watched (cat 3 name '.json')]))
      ;<  *  bind:m  (cull-soft:io (seen-road rail (cat 3 name '.json')))
      (send-code eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y]]))
        [%api %run ~]       (manual-run rail eyre-id body)
        [%api %rerun ~]     (rerun rail eyre-id body)
        [%api %cancel ~]    (cancel-run rail eyre-id body)
        [%api %runners %add ~]     (add-runner rail eyre-id body)
        [%api %runners %set ~]     (set-runner rail eyre-id body)
        [%api %runners %delete ~]
      =/  rid=@t  (jget body 'id')
      ?.  (name-ok:ci rid)  (send-err eyre-id 400 'bad id')
      ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /runners (cat 3 rid '.json')]))
      ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /status (cat 3 rid '.json')]))
      (send-code eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y]]))
    ==
  ?+  suffix  (serve-static:web eyre-id suffix)
    [%api %state ~]  (send-state rail eyre-id)
    [%api %log ~]    (send-log rail eyre-id args)
  ==
::  +add-watched: {repo: owner/name, branches, minutes}. The grub's
::  name is the repo lowercased, with its slash, dots and underscores
::  turned to dashes.
::
++  add-watched
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jget body 'repo')
  =/  parts=(list tape)  (split:git-transport (trip repo) '/')
  ?.  ?=([^ ^ ~] parts)  (send-err eyre-id 400 'repo must be owner/name')
  =/  name=@t
    %-  crip
    %+  turn  (cass "{i.parts}-{i.t.parts}")
    |=(c=@t ?:(|(=('.' c) =('_' c)) '-' c))
  ?.  (name-ok:ci name)
    (send-err eyre-id 400 'owner and name hold only letters, digits, -, . and _')
  =/  branches=(list @t)  (jlist body 'branches')
  =.  branches  ?~(branches ~['main'] branches)
  =/  cfg=json
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['repo' s+repo]
        ['branches' (jsa branches)]
        ['minutes' (nums (max 1 (jnum body 'minutes' 5)))]
    ==
  ;<  ~  bind:m  (put-json (nex-road:io rail [%& /watched (cat 3 name '.json')]) cfg)
  (send-code eyre-id 200 cfg)
::  +manual-run: run a watched repo's branch at its current tip
::
++  manual-run
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (jget body 'name')
  ?.  (name-ok:ci name)  (send-err eyre-id 400 'bad name')
  ;<  cfg=(unit json)  bind:m
    (peek-json (nex-road:io rail [%& /watched (cat 3 name '.json')]))
  ?~  cfg  (send-err eyre-id 404 'no such watched repo')
  =/  repo=@t  (jget u.cfg 'repo')
  =/  branches=(list @t)  (jlist u.cfg 'branches')
  =/  branch=@t  (jget body 'branch')
  =.  branch  ?:(=('' branch) (snag 0 (weld branches ~['main'])) branch)
  ;<  tips=(each (map @t @t) @t)  bind:m  (gh-tips repo)
  ?:  ?=(%| -.tips)  (send-err eyre-id 502 p.tips)
  =/  sha=(unit @t)  (~(get by p.tips) branch)
  ?~  sha  (send-err eyre-id 404 'no such branch on GitHub')
  ;<  res=(each @ud @t)  bind:m  (start-runs rail repo branch u.sha 'manual' ~[branch])
  ?:  ?=(%| -.res)  (send-err eyre-id 502 p.res)
  (send-code eyre-id 200 (pairs:enjs:format ~[['runs' (nums p.res)]]))
::  +rerun: the same commit again, as a manual run
::
++  rerun
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  run=@t  (jget body 'run')
  ;<  head=(unit json)  bind:m  (peek-json (nex-road:io rail [%& /runs/[`@ta`run] %'run.json']))
  ?~  head  (send-err eyre-id 404 'no such run')
  =/  branch=@t  (jget u.head 'branch')
  ;<  res=(each @ud @t)  bind:m
    (start-runs rail (jget u.head 'repo') branch (jget u.head 'sha') 'manual' ~[branch])
  ?:  ?=(%| -.res)  (send-err eyre-id 502 p.res)
  (send-code eyre-id 200 (pairs:enjs:format ~[['runs' (nums p.res)]]))
::  +cancel-run: poke a cancel into each job of a run, or one job
::
++  cancel-run
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  run=@t  (jget body 'run')
  ;<  head=(unit json)  bind:m  (peek-json (nex-road:io rail [%& /runs/[`@ta`run] %'run.json']))
  ?~  head  (send-err eyre-id 404 'no such run')
  =/  one=@t  (jget body 'job')
  =/  jobs=(list @t)  ?:(=('' one) (jlist u.head 'jobs') ~[one])
  |-
  ?~  jobs  (send-code eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y]]))
  ;<  *  bind:m
    %+  poke-soft:io  (job-road rail run i.jobs)
    [[/ %json] (pairs:enjs:format ~[['cmd' s+'cancel']])]
  $(jobs t.jobs)
::  +add-runner: mint a key. The secret is answered once; the ship keeps
::  a salted hash.
::
++  add-runner
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (jget body 'name')
  ?:  =('' name)  (send-err eyre-id 400 'name required')
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rid=@t  (id-of:ci eny)
  =/  secret=@t  (secret-of:ci (shax eny))
  =/  salt=@t  (secret-of:ci (shax (shax eny)))
  ;<  now=@da  bind:m  get-time:io
  =/  cfg=json
    %-  pairs:enjs:format
    :~  ['id' s+rid]
        ['name' s+name]
        ['repos' (jsa (jlist body 'repos'))]
        ['enabled' b+%.y]
        ['salt' s+salt]
        ['hash' s+(hash-token:ci salt secret)]
        ['made' (nums (ms now))]
    ==
  ;<  ~  bind:m  (put-json (nex-road:io rail [%& /runners (cat 3 rid '.json')]) cfg)
  %^  send-code  eyre-id  200
  (pairs:enjs:format ~[['id' s+rid] ['key' s+(rap 3 rid '.' secret ~)]])
::  +set-runner: enabled and repos; the key never changes
::
++  set-runner
  |=  [=rail:tarball eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rid=@t  (jget body 'id')
  ?.  (name-ok:ci rid)  (send-err eyre-id 400 'bad id')
  =/  road=road:tarball  (nex-road:io rail [%& /runners (cat 3 rid '.json')])
  ;<  cfg=(unit json)  bind:m  (peek-json road)
  ?~  cfg  (send-err eyre-id 404 'no such runner')
  =/  new=json  u.cfg
  =?  new  ?=(^ (find-key body 'enabled'))
    (jput new 'enabled' (need (find-key body 'enabled')))
  =?  new  ?=(^ (find-key body 'repos'))
    (jput new 'repos' (jsa (jlist body 'repos')))
  ;<  ~  bind:m  (over:io road [[/ %json] new])
  (send-code eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y]]))
::  +send-state: everything the page shows, in one answer
::
++  send-state
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  watched=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /watched]))
  ;<  seen=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /seen]))
  ;<  runners=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /runners]))
  ;<  status=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /status]))
  ;<  runs=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /runs]))
  ;<  now=@da  bind:m  get-time:io
  =/  seen-map=(map @ta json)  (malt (ball-jsons seen))
  =/  stat-map=(map @ta json)  (malt (ball-jsons status))
  =/  run-list=(list json)
    %+  turn
      (sort ~(tap by dir.runs) |=([a=[@ta *] b=[@ta *]] (aor -.b -.a)))
    |=  [nam=@ta b=ball:tarball]
    =/  files=(map @ta json)  (malt (ball-jsons b))
    =/  head=json  (fall (~(get by files) %'run.json') ~)
    =/  jobs=(list json)
      (murn (jlist head 'jobs') |=(j=@t (~(get by files) (cat 3 j '.json'))))
    (jput head 'job_states' [%a jobs])
  %^  send-code  eyre-id  200
  %-  pairs:enjs:format
  :~  ['now' (nums (ms now))]
      :-  'watched'
      :-  %a
      %+  turn  (ball-jsons watched)
      |=  [nam=@ta cfg=json]
      (jput cfg 'seen' (fall (~(get by seen-map) nam) ~))
      :-  'runners'
      :-  %a
      %+  turn  (ball-jsons runners)
      |=  [nam=@ta cfg=json]
      =/  pub=json
        ?.  ?=([%o *] cfg)  cfg
        [%o (~(del by (~(del by p.cfg) 'salt')) 'hash')]
      (jput pub 'status' (fall (~(get by stat-map) nam) ~))
      ['runs' [%a run-list]]
  ==
::  +send-log: a job's log chunks from a sequence number on
::
++  send-log
  |=  [=rail:tarball eyre-id=@ta args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  run=@t  (quay-get args 'run')
  =/  job=@t  (quay-get args 'job')
  ?.  &((name-ok:ci job) !=('' run))  (send-err eyre-id 400 'run and job required')
  =/  from=@ud  (fall (rush (quay-get args 'from') dem) 0)
  ;<  b=ball:tarball  bind:m  (peek-ball (nex-road:io rail [%| /logs/[`@ta`run]/[`@ta`job]]))
  =/  chunks=(list [@ud @t])
    ?~  fil.b  ~
    %+  sort
      %+  murn  ~(tap by contents.u.fil.b)
      |=  [nam=@ta ent=[=sang:tarball *]]
      =/  n=(unit @ud)  (rush (crip (scag 6 (trip nam))) dem)
      ?~  n  ~
      ?:  (lth u.n from)  ~
      =/  mim=(unit mime)  (mole |.(;;(mime (sang-noun:tarball sang.ent))))
      ?~  mim  ~
      `[u.n `@t`q.q.u.mim]
    |=([a=[@ud *] b=[@ud *]] (lth -.a -.b))
  =/  next=@ud  ?~(chunks from +((rear (turn chunks head))))
  %^  send-code  eyre-id  200
  %-  pairs:enjs:format
  :~  ['text' s+(rap 3 (turn chunks tail))]
      ['next' (nums next)]
  ==
--
