/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
::  lattice-supersede: a fact changed, or two entries say the same thing.
::  The old entry stays (history and links keep working) but search and
::  recall leave it out, and reading it points at the new one. Better than
::  deleting, which loses the record, or overwriting, which loses what was
::  true before.
^-  tool:tools
|%
++  name  'lattice-supersede'
++  description  'Mark a memory as replaced by another: the old entry stays readable but search and recall leave it out and point to the new one. Use when a fact changed (save the new fact first) or when two entries duplicate each other. Pass by "" to undo.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['key' [%string 'The entry being replaced']]
      ['by' [%string 'The entry that replaces it ("" to undo)']]
  ==
++  required  ~['key' 'by']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  raw=(unit @t)  (arg:lm args.st /key)
  ?~  raw  (pure:m [%error 'missing or invalid: key'])
  =/  kp=(unit path)  (parse-key:lm u.raw)
  ?~  kp  (pure:m [%error 'invalid key'])
  =/  braw=@t  (opt:lm args.st /by)
  =/  bp=(unit path)  (parse-key:lm braw)
  ?:  &(!=('' braw) ?=(~ bp))  (pure:m [%error 'invalid by'])
  ?:  =(bp kp)  (pure:m [%error 'an entry cannot replace itself'])
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  e=(unit know-entry:lk)  (~(get by es) u.kp)
  ?~  e  (pure:m [%error 'not found'])
  ?:  &(?=(^ bp) !(~(has by es) u.bp))  (pure:m [%error 'the replacing entry does not exist; save it first'])
  =/  f  (front:lk body.u.e)
  =/  meta  (meta-put:lk meta.f 'superseded-by' ?~(bp '' (spat u.bp)))
  ;<  ~  bind:m  (poke-writer:lm [%save (spat u.kp) (with-front:lk meta rest.f)])
  %-  pure:m
  :-  %text
  (crip ?~(bp "{(spud u.kp)} is live again" "{(spud u.kp)} is now superseded by {(spud u.bp)}"))
--
