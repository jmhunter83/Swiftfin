# App Store Connect copy — 2.0.1

Paste into the 2.0.1 submission. Limits in parens.

Still requires tvOS 26, same as 2.0.0. Nothing changed there, so it doesn't need to lead this time.

## Subtitle (30)

```
Jellyfin for your Apple TV
```

## Promotional text (170)

```
Skip the intro, roll into the next episode without touching the remote, and stop re-picking your subtitles every single episode.
```

## What's New (4000)

```
2.0 was the rebase. This one is about the thing you do most: watching a series straight through.

Episodes now hand off to each other. In the last 30 seconds a card slides up with what's next and a countdown, the video dims behind it, and you can take it early or ignore it and let it run.

Skip intro is here, and it's real this time. If your server tags intros — the Media Segments plugin, Jellyfin 10.10 or newer — a pill appears during the intro and one press jumps past it. Once the credits start, that pill turns into Next Episode. No tagged outro on the server? It falls back to the last two minutes.

Subtitles are remembered per series. Pick your subtitle track on episode one and every episode after it comes up the same way, including turning them off. Movies remember too.

Fixes:
- Pressing Menu during playback no longer drops you out of the app
- Home refreshes Next Up and Continue Watching after you finish something, instead of showing you the episode you just watched
- Auto play stopped switching itself off when you edited the toolbar
- Autoplay no longer gets derailed by a stale end-of-playback event
```

## TestFlight — What to Test (4000)

```
Still requires tvOS 26.

This build is all about watching a series end to end, so that's what I need beaten on. Put on a show you'd actually binge and let it run through two or three episodes without touching anything.

Worth beating on:

- The up next card. Last 30 seconds of an episode, it should slide up with the next one and a countdown, and the video should dim behind it. Take it early, ignore it, and back out of it — all three.
- Skip intro. Needs the Media Segments plugin on your server and Jellyfin 10.10+. During a tagged intro you should get a pill; one press jumps to the end of it. If you don't run that plugin, tell me — you should just never see the pill, not see a broken one.
- Next episode pill during credits. With a tagged outro it starts there, otherwise the last two minutes. It should only show up when there's actually something queued behind it.
- Subtitles across episodes. Pick a track on episode one, confirm episode two comes up the same. Then turn subtitles off and confirm off sticks too.
- Menu during playback. Press it a lot, at the pause menu, at the overlay, mid-card. It should never bounce you to the tvOS home screen.
- Finish something, then look at Home. Next Up and Continue Watching should have moved on.

Heads up: I skipped my own device pass on this one to get it out, so it's rougher than usual. If something's obviously broken, it probably is.

If it breaks, send your Apple TV model, tvOS version, Jellyfin server version, and whether you run the Media Segments plugin.
```

## Keywords (100)

Unchanged from 2.0.0.

```
jellyfin,server,stream,home,theater,movies,shows,vlc,library,subtitles,4k,hdr,dolby
```

## Notes

Skip intro reads the server's Media Segments API, so it's only as good as the server's tagging. The two-minute credits fallback exists so the Next Episode pill still works for people with no segment plugin at all.
