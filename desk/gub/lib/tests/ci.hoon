::  tests/ci: workflow parsing, branch matching and runner keys
::
/<  test  /lib/test.hoon
/<  ci    /lib/ci.hoon
%-  run-tests:test
!>
|%
++  wf
  |=  t=@t
  ^-  (each workflow:ci tape)
  (parse-workflow:ci (need (de:json:html t)))
++  ok  |=(r=(each workflow:ci tape) ?=(%& -.r))
::  +test-parse-full: an app built on three runners
::
++  test-parse-full
  |.  ^-  tang
  =/  r  %-  wf
    '''
    {"on": {"branches": ["main"]},
     "jobs": {
       "linux": {"runs-on": ["linux", "x86_64"],
                 "steps": [{"run": "./build.sh"}, {"upload": "dist/*.tar.gz"}]},
       "windows": {"runs-on": ["windows"], "timeout": 30,
                   "steps": [{"run": "./build.ps1", "shell": "pwsh"}]}}}
    '''
  ?.  ?=(%& -.r)  ~[leaf+p.r]
  ;:  weld
    (expect-eq:test !>(`(unit (list @t))``~['main']) !>(branches.p.r))
    (expect-eq:test !>(~[%linux %windows]) !>((turn jobs.p.r |=(j=job-spec:ci name.j))))
    (expect-eq:test !>(~[60 30]) !>((turn jobs.p.r |=(j=job-spec:ci timeout.j))))
    (expect-eq:test !>(`(list @t)`~['linux' 'x86_64']) !>(runs-on:(snag 0 jobs.p.r)))
  ==
::  +test-parse-ship: "ship" as runs-on, tool steps
::
++  test-parse-ship
  |.  ^-  tang
  =/  r  (wf '{"jobs": {"desk": {"runs-on": "ship", "steps": [{"tool": "ci_build"}]}}}')
  ?.  ?=(%& -.r)  ~[leaf+p.r]
  ;:  weld
    (expect-eq:test !>(`(unit (list @t))`~) !>(branches.p.r))
    (expect-eq:test !>(`(list @t)`~['ship']) !>(runs-on:(snag 0 jobs.p.r)))
  ==
::  +test-parse-bad: each malformed shape is refused, with a reason
::
++  test-parse-bad
  |.  ^-  tang
  =/  bad=(list @t)
    :~  '[]'
        '{"jobs": {}}'
        '{"jobs": {"Linux": {"runs-on": ["linux"], "steps": [{"run": "x"}]}}}'
        '{"jobs": {"a": {"runs-on": [], "steps": [{"run": "x"}]}}}'
        '{"jobs": {"a": {"runs-on": "linux", "steps": [{"run": "x"}]}}}'
        '{"jobs": {"a": {"runs-on": ["linux"], "steps": []}}}'
        '{"jobs": {"a": {"runs-on": ["linux"], "steps": [{"run": "x", "upload": "y"}]}}}'
        '{"jobs": {"a": {"runs-on": ["linux"], "steps": [{"run": "x", "shell": "zsh"}]}}}'
        '{"jobs": {"a": {"runs-on": ["linux"], "timeout": 1.5, "steps": [{"run": "x"}]}}}'
        '{"jobs": {"a": {"runs-on": "ship", "steps": [{"run": "x"}]}}}'
        '{"on": {"branches": "main"}, "jobs": {"a": {"runs-on": ["l"], "steps": [{"run": "x"}]}}}'
    ==
  %+  expect-eq:test  !>(~)
  !>((skim bad |=(t=@t (ok (wf t)))))
::  +test-watches: absent on.branches falls back to the repo's; "*" is all
::
++  test-watches
  |.  ^-  tang
  ;:  weld
    (expect:test !>((watches:ci ~ ~['main'] 'main')))
    (expect:test !>(!(watches:ci ~ ~['main'] 'dev')))
    (expect:test !>((watches:ci `~['dev'] ~['main'] 'dev')))
    (expect:test !>(!(watches:ci `~['dev'] ~['main'] 'main')))
    (expect:test !>((watches:ci `~['*'] ~ 'anything')))
  ==
::  +test-labels: a runner must hold every label a job asks for
::
++  test-labels
  |.  ^-  tang
  ;:  weld
    (expect:test !>((labels-hold:ci ~['linux' 'android' 'x86_64'] ~['linux' 'android'])))
    (expect:test !>(!(labels-hold:ci ~['linux'] ~['linux' 'android'])))
  ==
::  +test-bearer: the scheme is case-insensitive, the id ends at the
::  first dot, and empty halves are refused
::
++  test-bearer
  |.  ^-  tang
  ;:  weld
    (expect-eq:test !>(`(unit [@t @t])``['abc' 'x.y']) !>((parse-bearer:ci 'Bearer abc.x.y')))
    (expect-eq:test !>(`(unit [@t @t])``['abc' 'xy']) !>((parse-bearer:ci 'bearer   abc.xy')))
    (expect-eq:test !>(`(unit [@t @t])`~) !>((parse-bearer:ci 'Basic abc.xy')))
    (expect-eq:test !>(`(unit [@t @t])`~) !>((parse-bearer:ci 'Bearer abcxy')))
    (expect-eq:test !>(`(unit [@t @t])`~) !>((parse-bearer:ci 'Bearer .xy')))
  ==
::  +test-keys: the hash checks the right secret only, and id and
::  secret come from different entropy
::
++  test-keys
  |.  ^-  tang
  =/  h  (hash-token:ci 'salt' 'sekrit')
  ;:  weld
    (expect:test !>(=(h (hash-token:ci 'salt' 'sekrit'))))
    (expect:test !>(!=(h (hash-token:ci 'salt' 'sekrat'))))
    (expect:test !>(!=(h (hash-token:ci 'pepper' 'sekrit'))))
    (expect:test !>((gte (met 3 (secret-of:ci (shax 42))) 20)))
    (expect:test !>(!=((id-of:ci (lsh [3 16] 1)) (id-of:ci (lsh [3 16] 2)))))
  ==
::  +test-b64: GitHub's line-wrapped base64 decodes
::
++  test-b64
  |.  ^-  tang
  (expect-eq:test !>(`(unit @t)``'{"a": 1}') !>((b64-text:ci 'eyJhIjog\0aMX0=')))
--
