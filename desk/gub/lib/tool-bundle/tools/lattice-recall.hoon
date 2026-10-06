/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
::  lattice-recall: memory for a task, pulled rather than listed. The task
::  text ranks the store; the entries the best three link to come along,
::  one hop, as `linked`, because a fact often lives one link away from the
::  entry that names the task.
^-  tool:tools
|%
++  name  'lattice-recall'
++  description  'Recall what memory holds for a task: describe the task in a sentence or two and get the most relevant entries with snippets, plus entries they link to. Call at the start of a task and whenever the task changes. weak: true means probably nothing relevant is stored.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['task' [%string 'What you are about to do, in plain words']]
      ['limit' [%number 'How many ranked entries (default 8)']]
  ==
++  required  ~['task']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  raw=(unit @t)  (arg:lm args.st /task)
  ?~  raw  (pure:m [%error 'missing or invalid: task'])
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  k=@ud  (num:lm args.st /limit 8)
  ;<  tc=term-cache:lk  bind:m  read-cache:lm
  (pure:m [%text (en:json:html (recall-json:lk es (search:lk ~(tap by es) tc u.raw |) u.raw k))])
--
