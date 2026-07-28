# What Reefy adds on top of Swiftfin

Reefy is a tvOS-only fork of [Swiftfin](https://github.com/jellyfin/swiftfin). It tracks
upstream closely and rebases onto it rather than drifting — the current base is
**Swiftfin 1.5** (`7891e273`, Content Groups #2075), adopted 2026-07-26 and shipping as
Reefy 2.0.0.

Everything below is a deliberate divergence from that base. Anything not listed here
behaves the way upstream Swiftfin does.

Two things shape the list:

- **tvOS only.** Upstream splits effort across iOS and tvOS, and the big screen tends to
  come second. Several entries exist because a feature shipped for iOS and never got a
  tvOS entry point.
- **VLC only.** AVKit playback was removed on 2026-01-28. One player path means the
  player fixes below don't have to hold for two backends.

---

## Playback

**Up next card at the end of an episode.** Thirty seconds before the end, a card slides in
with the next episode and counts down into it. Play jumps straight there; Menu dismisses it
and lets the episode finish and exit instead. Upstream advances silently at end of file with
no UI at all.

The countdown drives the advance itself rather than waiting on the player's ended event —
VLC sends that early, and when the reported position never quite reaches runtime it doesn't
arrive at all.

**Skip intro and next episode pills.** A pill in the bottom corner offers a jump, taken with
select or play. During an intro the server has tagged it seeks to the end of that segment;
once the credits roll and something is queued it becomes Next Episode. Segments come from the
server's Media Segments API (Jellyfin 10.10+ with a segments plugin), and with no tagged outro
the credits window falls back to the last two minutes so the pill still works without the
plugin. The up next card suppresses the pill rather than stacking with it — both offer the
same jump. Window logic lives in `VideoPlayerSkipAction.resolve` and is deliberately free of
view state so it can be tested directly.

**Reliable episode transitions.** Upstream's end-of-item handler reads the current item and
the queue's next item *after* it may already have changed, so autoplay could stop instead of
advancing, or advance to the wrong episode. Reefy captures both up front, ignores an ended
event whose item no longer matches what's playing, ignores ended for live streams, and adds
a one-way stopping latch so exiting the player beats a late autoplay.

**Subtitle choice remembered per series.** Turning subs on or off carries to the next episode
and to future viewings, stored per user against the series id and matched by *language* —
stream indexes shift between episodes of the same show, so index matching doesn't survive an
episode change. Gated on the "Remember track selection" toggle that 1.5 added to settings but
never actually read. Preferred language and the server default still apply underneath.

**Menu doesn't drop you out of the app.** When the player overlay hides, every control goes
transparent and nothing in the container wants focus. Focus escapes, the Menu press never
reaches the player's handler, and tvOS treats it as unhandled — suspending the app to the
Home screen. An invisible focus anchor keeps the press inside the player.

**Toolbar edits don't disable autoplay.** Upstream #1888 wires the bar/menu button pickers to
write `enableNextEpisodeAutoPlay` on the Jellyfin account, so removing the AutoPlay button
from the toolbar silently turned autoplay off server-wide and undid the toggle in settings.
The settings toggle is now the only thing that writes that flag.

**Position marker on the transport tick.** Upstream drops the chapter tick entirely while the
slider holds focus, leaving only the fill edge. Reefy keeps it on screen and colors it orange
so there's still a place marker while scrubbing.

**Episode name and year in the overlay title.** The subtitle carries season/episode, episode
name, and year, dropping whichever parts are missing. Movies pick up a year where they had no
subtitle at all.

---

## Home and libraries

**Home rows refresh after playback.** Nothing in upstream's player tells the rest of the app
that playback stopped, so Next Up and Continue Watching keep showing the episode you just
finished. Reefy awaits the stop report, re-reads the item, then posts the user-data change the
refresh machinery is already listening for. The await matters — posting first races the server
and reads back the pre-playback state.

**Filter bar on tvOS.** Upstream gives tvOS a cinematic background where iOS gets the filter
drawer, so there was no way to reach filters on the big screen at all. The filter stack is
already shared; this adds the entry point — a capsule per enabled filter, sitting above the
grid in the page flow.

---

## Interface

**Icon-only tab bar.** Six tabs with text ran most of the screen width. Icons only, with the
title revealed under the focus cursor. The title is passed to the style separately so
VoiceOver still announces the tab.

**Coral accent by default** (`#FF7F50`, sampled off the jellyfish in the app icon), replacing
upstream's purple in all three places it was baked in.

**Reefy identity** — bundle id, display name, `reefy://` URL scheme, app icon, top shelf art,
and logo throughout settings, about, and login.

---

## Correctness

**Per-user device id.** Signing in as a second user invalidated the first user's token, so
everything 401'd after a switch. Reefy generates a device id per sign-in and persists it in
the keychain beside the access token. Quick Connect uses the same client to initiate and
redeem, since the secret is redeemed against the device that started the exchange. Users
stored without one fall back to the legacy derived id. (Reefy #57)

**Release year off by one.** `premiereDateYear` used the format `YYYY` — the ISO *week*-based
year — so anything airing in the days either side of New Year reported the wrong year
everywhere a release year is shown. `yyyy` is the calendar year.

---

## Not yet carried forward

These shipped in the pre-rebase Reefy line (frozen at `reefy-1.4.3-final`) and have not been
ported to the 1.5 base. Listed so they don't get quietly forgotten.

| | Notes |
|---|---|
| Audio output mode setting | System Default / Auto / Stereo / Passthrough. Reefy #19, #55. Still advertised in `CHANGELOG.md`. |
| Pre-play subtitle picker | A captions menu next to Play on the item screen. Reefy #5. The in-player picker still works. |
| Menu at tab roots returns to Home | Separate from the in-player fix above. |
| Menu inside pushed settings screens | Focused menu rows eat the press and the app suspends. |
| Test target | `Swiftfin tvOS Tests/` was deleted by the rebase; roughly 480 lines of player and subtitle tests went with it. Restoring it needs `project.pbxproj` work. |
| Home refresh on foreground | The `didRequestGlobalRefresh` key still exists with nothing posting or observing it. |

Deliberately **not** restored: auto-marking an episode played at 95%. It cleared the Next Up
row a little faster, but quitting at 95% marked the episode watched when you hadn't finished
it. The server decides watch state now.

---

## Verifying player changes

The player work above is focus- and timing-sensitive, and the tvOS simulator does not
reproduce either faithfully. Build to a real Apple TV before trusting any of it.
