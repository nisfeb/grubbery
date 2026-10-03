/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
^-  tool:tools
|%
++  name  'lattice-search'
++  description  'Ranked memory search (BM25 over keys, tags and bodies), best first, each with a snippet. Plain words match any of them; a "quoted phrase" must appear verbatim. Superseded entries are left out unless superseded is true. weak: true means nothing matched well, so probably nothing is stored about this.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['query' [%string 'Words to search for, or a "quoted phrase"']]
      ['limit' [%number 'How many results (default 10)']]
      ['superseded' [%boolean 'Also return entries a newer one replaced (default false)']]
  ==
++  required  ~['query']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  raw=(unit @t)  (arg:lm args.st /query)
  ?~  raw  (pure:m [%error 'missing or invalid: query'])
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  k=@ud  (num:lm args.st /limit 10)
  ;<  tc=term-cache:lk  bind:m  read-cache:lm
  =/  hs=(list hit:lk)  (search:lk ~(tap by es) tc u.raw (flag:lm args.st /superseded))
  (pure:m [%text (en:json:html (hits-json:lk es hs u.raw k))])
--
