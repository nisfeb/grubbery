::  mar/clay/groups/chat/dm/action-2: typed marc so grubbery fibers can
::  poke Tlon's %chat with %chat-dm-action-2 (orrery's executor sends an
::  approved message as a DM). It carries only the %add of a text essay,
::  TYPED, since %chat's on-poke does a typed extract and a passthrough
::  marc's untyped vase nest-fails it into a silent nack. The shape is
::  tlon-apps desk/sur/chat-7.hoon: (pair ship (pair id delta)), the id
::  [author @da], the delta [%add essay time=(unit)], the essay
::  [[story author sent] kind meta blob], a story of inline verses.
::  Deploys to /gub/mar/clay/groups/chat/dm/action-2/hoon AND
::  /gub/mar/clay/groups/chat-dm-action-2/hoon (both segment forms).
::
|_  a=[p=@p q=[[@p @da] [%add [[(list [%inline (list @t)]) @p @da] [%chat ~] ~ ~] ~]]]
++  grad  %noun
++  grow
  |%
  ++  noun  a
  --
++  grab
  |%
  ++  noun  ,[p=@p q=[[@p @da] [%add [[(list [%inline (list @t)]) @p @da] [%chat ~] ~ ~] ~]]]
  --
--
