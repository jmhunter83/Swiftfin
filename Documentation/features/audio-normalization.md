# Audio Normalization (ReplayGain)

Reefy supports **ReplayGain volume normalization** for music playback. This keeps volume consistent across tracks mastered at different loudness levels — no more reaching for the remote when a quiet jazz track is followed by a loud rock song.

## How It Works

ReplayGain analyzes the perceived loudness of audio tracks and stores a gain adjustment value in the file metadata. When you play music, Reefy reads this value from your Jellyfin server and adjusts the playback volume automatically.

**Example:** A quiet classical recording might need +3 dB boost, while a loudly mastered pop track might need -5 dB reduction. With ReplayGain enabled, both play at similar perceived volume.

## Requirements

| Requirement | Details |
|-------------|---------|
| **Jellyfin Server** | Version 10.9.0 or later |
| **Server Task** | "Audio Normalization" scheduled task must be run |
| **Reefy Setting** | Enable "Volume Normalization" in Settings → Video Player |

## Server Setup

Your Jellyfin server must scan your music library to populate ReplayGain data:

1. Open **Jellyfin Dashboard** (web admin)
2. Go to **Scheduled Tasks**
3. Find **Audio Normalization**
4. Click **Run** to start a manual scan, or configure a schedule

### Important Notes

- **Initial scan takes time** — Large music libraries (10,000+ tracks) may take hours to days for the first scan
- **Server version matters** — Audio normalization has had stability issues in some Jellyfin versions. If the task fails, check for server updates
- **Pre-tagged files work best** — If your music files already have ReplayGain tags (from tools like `mp3gain`, `r128gain`, or music taggers like beets), the server scan will read these values

## Reefy Settings

Once your server has ReplayGain data, enable it in Reefy:

**Settings → Video Player → Audio Normalization**

| Setting | Description | Default |
|---------|-------------|---------|
| **Volume Normalization** | Master toggle for the feature | Off |
| **Mode** | Track (per-song) or Album (preserve album dynamics) | Track |
| **Pre-Amp** | Additional gain adjustment (-12 to +12 dB) | 0 dB |
| **Prevent Clipping** | Limits positive gains to avoid distortion | On |

### Mode Explained

- **Track Mode** — Each song normalized independently. Best for shuffle playlists or mixed-genre listening.
- **Album Mode** — Maintains relative volume within an album (so quiet intros stay quiet). Best for listening to albums straight through.

> **Note:** Jellyfin's API currently only provides track-level gain values. Album mode is present for future compatibility but currently behaves the same as Track mode.

### Pre-Amp

The Pre-Amp setting lets you adjust the overall target volume:

- **Positive values (+1 to +12 dB)** — Make normalized audio louder
- **Negative values (-1 to -12 dB)** — Make normalized audio quieter
- **0 dB** — Use standard ReplayGain target level

Most users should leave this at 0 dB. Use positive values if normalized music sounds too quiet compared to video content.

### Prevent Clipping

When enabled (recommended), this prevents the gain from going above 0 dB. This avoids digital distortion on tracks that are already loud.

**When to disable:** If you've set a negative Pre-Amp value and want the full normalization range, you can safely disable this.

## Troubleshooting

### Music volume isn't normalized

1. **Check server setup** — Verify the Audio Normalization task has completed successfully in Jellyfin Dashboard → Scheduled Tasks
2. **Check track metadata** — In Jellyfin web, view a track's details. Look for "Normalization Gain" in the metadata. If it's missing, the server hasn't scanned that track
3. **Verify Reefy setting** — Ensure Volume Normalization is enabled in Settings → Video Player

### Normalization task fails on server

Audio normalization has had stability issues in certain Jellyfin versions:

- **10.9.x** — Some users experienced temp file race conditions
- **10.10.x** — Generally more stable
- **10.11.x** — Entity tracking bugs reported in early releases

**Solutions:**
- Update Jellyfin to the latest stable version
- Check Jellyfin GitHub issues for known problems with your version
- Try running the task during low-activity periods

### Audio sounds distorted

This usually means clipping from excessive gain:

1. Enable **Prevent Clipping** in Reefy settings
2. Reduce the **Pre-Amp** value (try -3 dB)

## Technical Details

- ReplayGain target loudness: -18 LUFS (standard)
- Gain range: -20 dB to +20 dB (clamped)
- Applied via VLC's gain audio filter
- Only affects items with `type: audio` — video playback is unchanged
