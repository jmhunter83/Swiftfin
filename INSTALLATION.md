# Installing Reefy

Reefy is available through two methods: the Apple App Store (recommended for most users) or building from source (for developers).

---

## Option 1: App Store (Recommended)

### Requirements
- Apple TV (tvOS 26 or later)
- Apple ID with payment method
- $8.99 USD (one-time purchase)

### Installation Steps

1. **On your Apple TV:**
   - Open the App Store application
   - Navigate to the Search tab
   - Search for "Reefy Media Player"
   - Select the app from search results

2. **Purchase and Download:**
   - Price is displayed as $8.99 USD (or equivalent in your region)
   - Select "Buy" or "Get" (if you have a promo code)
   - Authenticate with your Apple ID
   - Wait for download to complete

3. **Launch:**
   - Find Reefy on your home screen
   - Launch the app
   - Connect to your Jellyfin server

### International Availability

Reefy is available in 175 countries on the App Store. Pricing is automatically converted to your local currency by Apple.

### Troubleshooting

**"Cannot find Reefy on App Store"**
- Ensure you're searching on your Apple TV device (not iPhone/iPad)
- Try the full name: "Reefy Media Player"
- Check that your Apple TV is running tvOS 26 or later — on older tvOS the app won't
  show up in search or updates at all
- Verify your region is supported (175 countries supported)

**"Already purchased on another device"**
- Navigate to your Purchased apps in the App Store
- Re-download Reefy for free

---

## Option 2: Build from Source (Developers)

Reefy is open source under the MPL 2.0 license. Developers can build and run the app for free.

### Requirements
- macOS with Xcode 16.4+
- Apple Developer account (free tier is sufficient)
- Command-line tools: Carthage, SwiftFormat, SwiftGen

### Build Instructions

See [Documentation/contributing.md](Documentation/contributing.md) for complete build setup instructions.

Quick start:
```bash
# Install dependencies
brew install carthage swiftformat swiftgen

# Clone repository
git clone https://github.com/jmhunter83/reefy.git
cd reefy

# Install Carthage dependencies
carthage update --use-xcframeworks --cache-builds

# Open in Xcode
open Swiftfin.xcodeproj
```

### Developer vs. App Store Version

| Feature | App Store | Self-Built |
|---------|-----------|------------|
| Cost | $8.99 USD | Free |
| Updates | Automatic | Manual (pull & rebuild) |
| Signing | Apple-managed | Self-managed |
| Support | App Store reviews | GitHub issues |
| Installation | One-click | Requires Xcode |

---

## Support

- **Bug Reports**: [GitHub Issues](https://github.com/jmhunter83/reefy/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/jmhunter83/reefy/discussions)
- **Source Code**: [github.com/jmhunter83/reefy](https://github.com/jmhunter83/reefy)
