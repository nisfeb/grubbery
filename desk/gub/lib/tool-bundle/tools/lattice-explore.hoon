/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
^-  tool:tools
|%
++  name  'lattice-explore'
++  description  'Filter entries by tag and/or substring. Returns keys with their tags. A category (user, feedback, project, reference) matches the key prefix as well as the tag.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['tag' [%string 'Tag to filter by (optional)']]
      ['query' [%string 'Substring across keys and bodies (optional)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  tag=(unit @t)  (~(deg jo:json-utils [%o args.st]) /tag so:dejs:format)
  =/  query=(unit @t)  (~(deg jo:json-utils [%o args.st]) /query so:dejs:format)
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  =/  hits=(map path know-entry:lk)
    %-  ~(gas by *(map path know-entry:lk))
    %+  skim  ~(tap by es)
    |=  [kp=path e=know-entry:lk]
    =/  tag-ok=?
      ?~  tag  &
      =/  lt=@t  (low:lm u.tag)
      ::  a category is the key's first segment, tagged or not
      ?|  (lien ~(tap in tags.e) |=(t=@t =((low:lm t) lt)))
          &(?=(^ kp) =((low:lm i.kp) lt))
      ==
    =/  query-ok=?
      ?~  query  &
      |((has-sub:lm u.query (spat kp)) (has-sub:lm u.query body.e))
    &(tag-ok query-ok)
  (pure:m [%text (en:json:html (list-json:lm hits))])
--
