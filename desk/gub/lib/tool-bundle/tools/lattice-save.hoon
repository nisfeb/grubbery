/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
::  lattice-save: write one memory, with where it came from.
::
::  Provenance goes in the body's front matter (+front:lk): author, source,
::  created, verified. The body an agent passes is prose; any front matter in
::  it is replaced, so an agent edits facts and the tool keeps the record.
::
::  Three refusals keep the store honest. expected_updated is a version
::  check: another agent's save since you read the entry fails the save
::  instead of being overwritten. A new key whose body shares +dup-at:lk of
::  its terms with an existing entry is refused as a likely duplicate unless
::  force_new; update that entry instead. And an empty body is refused.
::
::  ponytail: the version check reads, then pokes; a save landing between
::  the two can still win. The window is one event, against the minutes
::  between an agent's read and its write that the check is for.
^-  tool:tools
|%
++  name  'lattice-save'
++  description  'Create or update a memory. One fact per entry. Search or recall first and update an existing entry rather than adding a near-copy: a new key that largely repeats an existing entry is refused unless force_new. When editing, pass the updated value you read as expected_updated so a concurrent change is not overwritten. Say who you are (author) and whether the user said it (source "user") or you inferred it (source "agent").'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['key' [%string 'Entry key, e.g. "feedback/no-ai-attribution"']]
      ['body' [%string 'Entry text (markdown). Front matter is managed by the tool.']]
      ['author' [%string 'Who is writing: your session or agent name, or "user"']]
      ['source' [%string '"user" if the user said it, "agent" if you observed or inferred it']]
      ['expected_updated' [%string 'The updated value from your read; the save fails if the entry changed since']]
      ['force_new' [%boolean 'Create even though a near-duplicate exists (default false)']]
  ==
++  required  ~['key' 'body']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  ra=(unit @t)  (arg:lm args.st /key)
  =/  rb=(unit @t)  (arg:lm args.st /body)
  ?.  &(?=(^ ra) ?=(^ rb))
    (pure:m [%error 'missing or invalid arguments (key, body)'])
  =/  kp=(unit path)  (parse-key:lm u.ra)
  ?~  kp  (pure:m [%error 'invalid key'])
  =/  prose=@t  rest:(front:lk u.rb)
  ?:  =('' prose)  (pure:m [%error 'empty body'])
  =/  author=@t  (opt:lm args.st /author)
  =/  source=@t  (opt:lm args.st /source)
  ?.  |(=('' source) =('user' source) =('agent' source))
    (pure:m [%error 'source must be "user" or "agent"'])
  =/  expect=@t  (opt:lm args.st /expected-updated)
  =?  expect  =('' expect)  (opt:lm args.st /'expected_updated')
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  old=(unit know-entry:lk)  (~(get by es) u.kp)
  ?:  &(!=('' expect) |(?=(~ old) !=(expect (scot %da updated.u.old))))
    %-  pure:m
    :-  %error
    %-  crip
    ?~  old  "conflict: {(trip u.ra)} does not exist, so it cannot be at {(trip expect)}"
    "conflict: {(trip u.ra)} changed since you read it (now {(scow %da updated.u.old)}); read it again and merge"
  ::  a new key: the duplicate check, the term cache ruling most entries out
  ;<  tc=term-cache:lk  bind:m  read-cache:lm
  =/  near=(list [o=@ud k=path])  ?^(old ~ (near:lk ~(tap by es) tc prose))
  ?:  &(?=(^ near) (gte o.i.near dup-at:lk) !(flag:lm args.st /'force_new'))
    %-  pure:m
    :-  %error
    %-  crip
    "likely duplicate of {(spud k.i.near)} ({(a-co:co o.i.near)}% of terms shared). Update that entry instead (read it, then save to its key), or pass force_new if this is a different fact."
  ;<  now=@da  bind:m  get-time:io
  =/  meta=(list [k=@t v=@t])  ?~(old ~ meta:(front:lk body.u.old))
  =?  meta  =(~ (meta-get:lk meta 'created'))  (meta-put:lk meta 'created' (iso-day:lk ?~(old now updated.u.old)))
  =?  meta  !=('' author)  (meta-put:lk meta 'author' author)
  =?  meta  !=('' source)  (meta-put:lk meta 'source' source)
  =.  meta  (meta-put:lk meta 'verified' (iso-day:lk now))
  =?  meta  !=('' author)  (meta-put:lk meta 'verified-by' author)
  ;<  ~  bind:m  (poke-writer:lm [%save (spat u.kp) (with-front:lk meta prose)])
  =/  also=tape
    =/  sim=(list [o=@ud k=path])  (scag 3 near)
    ?~  sim  ""
    =/  ks=(list tape)  (turn sim |=([o=@ud k=path] "{(spud k)} ({(a-co:co o)}%)"))
    "; similar entries, check they do not say the same thing: {(zing (join ", " ks))}"
  (pure:m [%text (crip "{?~(old "created" "updated")} {(spud u.kp)}{also}")])
--
