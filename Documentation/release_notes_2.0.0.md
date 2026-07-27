# App Store Connect copy — 2.0.0

Paste into the 2.0.0 submission. Limits in parens.

## Subtitle (30)

```
Jellyfin for your Apple TV
```

## Promotional text (170)

```
Years on a foundation that hadn't moved. We said we'd fix it, and here it is: full rebase, new player, real library filters. Needs tvOS 26. Update your Apple TV first.
```

## What's New (4000)

```
This is the big one, and it's the one we promised.

Reefy has been running on a foundation that hadn't moved in years. The app worked, but underneath it the base was five years behind, which meant every improvement had to be rebuilt here by hand instead of just arriving. That was never going to hold. We said we'd deal with it.

2.0 is a full rebase onto the current base. Seven months of work lands in one release, and from here updates come in the normal way instead of one at a time.

Heads up: 2.0 needs tvOS 26. Every Apple TV HD and Apple TV 4K can run it, but you have to update the box first. Liquid Glass wants a 2nd-gen Apple TV 4K or newer.

New player. Liquid Glass, an orange position marker on the transport bar, jump intervals you set yourself, and playback speed that survives a restart. Episode name and year now show in the overlay next to the show and season/episode.

Library screens finally have a filter and sort bar. There was no way to get at filters on tvOS before this. Content groups are in too, and settings got redesigned into one place instead of scattered across the app.

Fixes:
- Audio and subtitle tracks map by index now, so the track you pick is the one that plays
- Signing in as a second Jellyfin user doesn't kick out the first anymore
- Release years stopped reading a year early on anything airing near New Year

Accent color is coral now, to match the icon. If you already set your own, yours stays. VLCKit is on 3.7.2.
```

## TestFlight — What to Test (4000)

```
Here's the rebase I've been promising. It's onto a much newer base, so treat it like a new app rather than an update. Poke at everything, but here's where it's most likely to be broken.

Needs tvOS 26. Update your Apple TV first or the build won't show up.

Library, settings, and saved users should carry over from 1.4.x. If anything came across empty or wrong that's the most important thing to tell me, and say what version you came from.

Worth beating on:

- Audio and subtitle tracks. Pick something that isn't the default, confirm that's what actually plays. Files with audio ahead of video in the track order used to break this.
- Two Jellyfin users. Sign in as a second, switch back to the first, neither should get logged out.
- The new filter and sort bar on library screens. tvOS-only work, so almost nobody has touched it.
- Playback speed and jump intervals. Set both, force quit, reopen, see if they held.
- Player overlay should show episode name and year next to the show and season/episode.

Not bugs: accent color defaults to coral now (custom picks are kept), and Liquid Glass only renders on 2nd-gen Apple TV 4K and up. Older boxes get the flat look.

If something breaks, send your Apple TV model, tvOS version, Jellyfin server version, and what you upgraded from.
```

## Keywords (100)

```
jellyfin,server,stream,home,theater,movies,shows,vlc,library,subtitles,4k,hdr,dolby
```

Skips "media" and "player" since both are already in the app name and get indexed anyway.

## Notes

Upstream isn't named anywhere. MPL-2.0 attribution lives in the source headers, so there's no obligation to name it in store copy.

The tvOS 26 requirement leads both blurbs on purpose. Anyone on an older box just sees the app quietly stop updating, and that turns into a support email.
