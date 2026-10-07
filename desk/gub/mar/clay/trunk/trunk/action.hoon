::  mar/clay/trunk/trunk-action: typed marc so grubbery fibers can poke
::  %trunk with %trunk-action. It carries the two notice variants:
::  %push-notice (trunk wire 12, gwbtc/trunk#2) and %push-notice-as
::  (wire 14, gwbtc/trunk#6), which names the sending app, so calendar
::  reminders and orrery's time-to-leave reach the owner's phones through
::  the ship's own %trunk under their own names, not as one "grubbery".
::  TYPED, since %trunk's on-poke does a typed extract and a passthrough
::  marc's untyped vase nest-fails it into a nack. The shapes are
::  sur/trunk.hoon's.
::  DEPLOY ONLY ONCE %trunk is wire 14: the vase carries the whole union,
::  and wire 12 or 13's typed extract refuses it, plain notices too.
::  Deploys to /gub/mar/clay/trunk/trunk/action/hoon AND
::  /gub/mar/clay/trunk/trunk-action/hoon (both segment forms).
::
=/  notice
  $%  [%push-notice tag=@t title=@t body=@t open=json]
      [%push-notice-as app=@t tag=@t title=@t body=@t open=json]
  ==
|_  a=notice
++  grad  %noun
++  grow
  |%
  ++  noun  a
  --
++  grab
  |%
  ++  noun  notice
  --
--
