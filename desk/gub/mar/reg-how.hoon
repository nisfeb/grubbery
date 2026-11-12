::  reg-how: dist compatibility. An app built for the dist kernel opens
::  its roads into a usergroup with +reg-how:io; the kernel turns that
::  into the app's own groups.json (see +handle-reg-how).
::
|_  rh=[group=path =weir:nexus]
++  grab
  |%
  ++  noun  ,[group=path =weir:nexus]
  --
++  grow
  |%
  ++  noun  rh
  --
--
