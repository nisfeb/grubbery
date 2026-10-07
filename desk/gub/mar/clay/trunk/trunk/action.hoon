::  mar/clay/trunk/trunk-action: typed marc so grubbery fibers can poke
::  %trunk with %trunk-action. It carries only the %push-notice variant
::  (trunk wire 12, gwbtc/trunk#2): calendar reminders and orrery's
::  time-to-leave go to the owner's phones through the ship's own %trunk,
::  not only grubbery web push, which never reaches Talon on an iPhone.
::  TYPED, since %trunk's on-poke does a typed extract and a passthrough
::  marc's untyped vase nest-fails it into a nack. The shape is
::  sur/trunk.hoon's [%push-notice tag=@t title=@t body=@t open=json].
::  Deploys to /gub/mar/clay/trunk/trunk/action/hoon AND
::  /gub/mar/clay/trunk/trunk-action/hoon (both segment forms).
::
|_  a=[%push-notice tag=@t title=@t body=@t open=json]
++  grad  %noun
++  grow
  |%
  ++  noun  a
  --
++  grab
  |%
  ++  noun  ,[%push-notice tag=@t title=@t body=@t open=json]
  --
--
