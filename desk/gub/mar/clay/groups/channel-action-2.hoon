::  mar/clay/groups/channel/action-2: typed marc so grubbery fibers can
::  poke Tlon's %channels with %channel-action-2 (orrery's executor
::  posts an approved message in a group channel). It carries only a
::  post's %add of a text essay, TYPED, since %channels does a typed
::  extract and a passthrough marc's untyped vase nest-fails it into a
::  silent nack. The shape is tlon-apps desk/sur/channels.hoon
::  (a-channels: [%channel nest a-channel], a-channel [%post a-post],
::  a-post [%add essay], the essay [[story author sent] kind meta blob]).
::  Deploys to /gub/mar/clay/groups/channel/action-2/hoon AND
::  /gub/mar/clay/groups/channel-action-2/hoon (both segment forms).
::
|_  a=[%channel [?(%chat %diary %heap) @p @tas] [%post [%add [[(list [%inline (list @t)]) @p @da] [%chat ~] ~ ~]]]]
++  grad  %noun
++  grow
  |%
  ++  noun  a
  --
++  grab
  |%
  ++  noun  ,[%channel [?(%chat %diary %heap) @p @tas] [%post [%add [[(list [%inline (list @t)]) @p @da] [%chat ~] ~ ~]]]]
  --
--
