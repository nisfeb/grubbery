::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
::  /apps is the trusted system tier: every instance defaults to ~ (no
::  weir, unrestricted). The weir apparatus exists for the untrusted
::  userspace tier — desk-installed apps default closed ([~ ~ ~]) and
::  earn each road through weir.json + shell approval. Built-ins,
::  including the shell (the capability broker that sands everyone
::  else), just run open here.
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
    :~  (manifest:loader 0)
        [%load %| / / same-fold:loader]
        [%fall %| /apps [`[~ ~ %.n ~] ~]]
        [%fall %| /docs [`[~ ~ %.n ~] ~]]
        ::  /port: authenticated typed-message ingress. Each /port/<name>
        ::  is a [/port %cargo] grub that handles its own pokes — poke it a
        ::  mime and it stamps the sender and stores it. Open weir: any ship.
        [%fall %| /port [`[`[/ %port] ~ %.n ~] ~]]
        ::  /sys/eyre: HTTP server state + request fibers
        ::
        [%fall %| /sys/eyre [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/eyre %'main.server-state'] [[/ %server-state] *server-state:nexus]]
        [%fall %| /sys/eyre/requests [`[~ ~ %.n ~] ~]]
        ::  /sys/behn: timer service
        ::
        [%fall %| /sys/behn [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/behn %'main.behn-state'] [[/ %behn-state] *behn-state:nexus]]
        ::  /sys/iris: HTTP client service
        ::
        [%fall %| /sys/iris [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/iris %'main.iris-state'] [[/ %iris-state] *iris-state:nexus]]
        ::  /sys/clay: desk sync service (state + desks/ subdir)
        ::
        [%fall %& [/sys/clay %'main.clay-state'] [[/ %clay-state] *clay-state:nexus]]
        [%fall %| /sys/clay/desks [`[~ ~ %.n ~] ~]]
        ::  /sys/scry: scry service
        ::
        [%fall %| /sys/scry [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/scry %'main.sig'] [[/ %sig] ~]]
        [%fall %& [/sys/scry %'main.scry-state'] [[/ %scry-state] *scry-state:nexus]]
        ::  child nexuses
        ::
        ::  This is the lattice distribution. Grubbery's default app tier is
        ::  deliberately absent: a ship built from this branch boots with
        ::  lattice and nothing else, because lattice IS the product here
        ::  rather than one tile among many. The nexus sources for the
        ::  removed apps are gone from the desk too, so a cold build does
        ::  not pay for code no instance will ever use.
        ::
        ::  Everything lattice needs is core rather than app tier. Its
        ::  permissions live in /sys/ames/usergroups, its routes bind
        ::  through eyre directly, and its only reference to another app
        ::  was a tile.json for the launcher, which is cosmetic.
        ::
        [%fall %| /apps/'lattice.lattice_app' [`[`[/lattice %app] ~ %.n ~] ~]]
        ::
        ::  mcp is the ONE survivor of the app tier, and it is not an
        ::  exception made lightly. Lattice ships its tool surface as
        ::  lib/mcp/lattice-*.hoon and serves no /mcp route of its own, so
        ::  the mcp nexus is what hosts lattice-list, lattice-read,
        ::  lattice-save and the rest. Removing it would leave the memory
        ::  store reachable only over HTTP, which is the feature most of
        ::  this distribution's users are here for.
        ::
        [%fall %| /apps/'mcp.mcp' [`[`[/ %mcp] ~ %.n ~] ~]]
    ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  /sys/eyre/requests/*: ball API request fibers
      ::
      [[%sys %eyre %requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%eyre /requests: failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    (dispatch:ball-api eyre-id src req site args)
  ==
--
