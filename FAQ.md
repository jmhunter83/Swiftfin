# Frequently Asked Questions

## General

### What is Reefy?

Reefy is a native tvOS client for Jellyfin media servers. It's a fork of Swiftfin focused exclusively on Apple TV with modern tvOS features like Liquid Glass effects.

### Is Reefy affiliated with Jellyfin or Swiftfin?

No. Reefy is an independent fork of Swiftfin, developed separately. It is not affiliated with or endorsed by the Jellyfin project or the Swiftfin team.

### What platforms does Reefy support?

tvOS only (Apple TV). Reefy does not support iOS, iPadOS, or macOS.

---

## Pricing & Source Code

### Why does Reefy cost $8.99 on the App Store?

The $8.99 covers:
- Apple's $99/year developer program fee
- Ongoing development, support, and updates
- App Store distribution and hosting

### Is the source code free?

Yes. Reefy is open source under the MPL 2.0 license. The full source code is available at [github.com/jmhunter83/reefy](https://github.com/jmhunter83/reefy).

### Can I build Reefy for free?

Yes. Developers can clone the repository and build Reefy themselves using Xcode. See [INSTALLATION.md](INSTALLATION.md) for instructions.

---

## Technical

### What tvOS version do I need?

- **Minimum**: tvOS 26

Every Apple TV HD and Apple TV 4K model can run tvOS 26, but the box has to be updated.
On anything older Reefy stops appearing in your updates with no warning — update the
Apple TV and it comes back.

Liquid Glass needs a 2nd-gen Apple TV 4K or later. Older boxes get the flat look.

### Does Reefy work with all Jellyfin servers?

Reefy is designed for Jellyfin 10.11+. Older versions may work but are not officially supported.

### What media formats does Reefy support?

Reefy uses VLC for playback, which supports a wide range of codecs including:
- H.264, H.265/HEVC
- VP9, AV1
- MP4, MKV, AVI containers
- AAC, AC3, DTS audio

See VLCKit documentation for the complete codec list.

### Does Reefy support HDR?

Yes. Reefy supports HDR10 and Dolby Vision content when your Apple TV and TV support these formats.

---

## App Store

### Which countries is Reefy available in?

Reefy is available in 175 countries on the Apple App Store, covering most global regions.

### Can I purchase Reefy from my iPhone?

No. tvOS apps must be purchased directly on your Apple TV device. You can browse the app on your iPhone/iPad, but the purchase must be completed on Apple TV.

### Is there a subscription?

No. Reefy is a one-time purchase of $8.99 USD with no subscriptions or in-app purchases.

### Do I need to pay again for updates?

No. Once purchased, all future updates are free.

---

## Fork Relationship

### Why fork Swiftfin instead of contributing?

Swiftfin tvOS development has been paused with no TestFlight available and no committed timeline. Reefy was created to serve tvOS users who needed a working app immediately.

Long-term, focusing exclusively on tvOS allows for platform-specific improvements that are more difficult in a multi-platform codebase.

### Will Reefy merge back into Swiftfin?

No plans for that. Reefy is a separate project with independent development. However, improvements from Reefy may be contributed back to Swiftfin if appropriate.

### What's different from Swiftfin?

Reefy rebases onto upstream rather than drifting from it — the current base is Swiftfin 1.5.
Everything Reefy deliberately does differently is listed in [IMPROVEMENTS.md](IMPROVEMENTS.md),
and anything not in that list behaves the way upstream does.

The short version: tvOS is the only target that gets attention, VLC is the only player, and
the end-of-episode experience (up next card, skip intro, sticky subtitles) is Reefy's.

---

## Support

### How do I report a bug?

File an issue on GitHub: [github.com/jmhunter83/reefy/issues](https://github.com/jmhunter83/reefy/issues)

Use the bug report template and include:
- Reefy version/build number
- Apple TV model and tvOS version
- Steps to reproduce
- Expected vs. actual behavior

### How do I request a feature?

Create a feature request on GitHub Discussions: [github.com/jmhunter83/reefy/discussions](https://github.com/jmhunter83/reefy/discussions)

---

## Beta Program

### Was there a beta program?

Yes. Reefy ran a public beta via TestFlight from December 2025 through January 17, 2026. The beta program closed when Reefy launched on the App Store.

### Can I still join the beta?

The public beta program is closed. Beta testers have been migrated to the App Store version.

### Will there be future betas?

Possibly, for major feature testing. Future beta programs will be announced on GitHub.
