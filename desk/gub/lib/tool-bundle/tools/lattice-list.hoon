/<  tools  /lib/tools.hoon
/<  lm  /lib/lattice-mcp.hoon
/<  lk  /lib/lattice-know.hoon
!:
^-  tool:tools
|%
++  name  'lattice-list'
++  description  'List all knowledge entries with tags and metadata, no bodies. Large on a big store: prefer lattice-index at session start and lattice-recall for a task.'
++  parameters  ^-  (map @t parameter-def:tools)  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  es=(map path know-entry:lk)  bind:m  read-vault:lm
  (pure:m [%text (en:json:html (list-json:lm es))])
--
