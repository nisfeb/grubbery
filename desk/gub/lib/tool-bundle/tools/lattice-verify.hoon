/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
^-  tool:tools
|%
++  name  'lattice-verify'
++  description  'Record that a memory was checked and still holds: stamps verified (today) and verified-by. Use after confirming a remembered file, function, flag or fact still exists, so the entry stops looking stale.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['key' [%string 'Entry key']]
      ['author' [%string 'Who checked: your session or agent name']]
  ==
++  required  ~['key']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  raw=(unit @t)  (arg:lm args.st /key)
  ?~  raw  (pure:m [%error 'missing or invalid: key'])
  =/  kp=(unit path)  (parse-key:lm u.raw)
  ?~  kp  (pure:m [%error 'invalid key'])
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  e=(unit know-entry:lk)  (~(get by es) u.kp)
  ?~  e  (pure:m [%error 'not found'])
  ;<  now=@da  bind:m  get-time:io
  =/  f  (front:lk body.u.e)
  =/  meta  (meta-put:lk meta.f 'verified' (iso-day:lk now))
  =/  by=@t  (opt:lm args.st /author)
  =?  meta  !=('' by)  (meta-put:lk meta 'verified-by' by)
  ;<  ~  bind:m  (poke-writer:lm [%save (spat u.kp) (with-front:lk meta rest.f)])
  (pure:m [%text (crip "verified {(spud u.kp)} on {(trip (iso-day:lk now))}")])
--
