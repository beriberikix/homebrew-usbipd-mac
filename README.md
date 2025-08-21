# homebrew-usbipd-mac

Homebrew tap for [usbipd-mac](https://github.com/beriberikix/usbipd-mac) - a macOS USB/IP protocol implementation for sharing USB devices over IP networks.

## Installation

```bash
# Add the tap
brew tap beriberikix/usbipd-mac

# Install usbipd-mac
brew install usbipd-mac

# Start the service
sudo brew services start usbipd-mac
```

## Updating

```bash
# Update to latest version
brew upgrade usbipd-mac
```

## Formula Management

This tap uses **automated formula updates** via [homebrew-releaser](https://github.com/Justintime50/homebrew-releaser) integration.

### How It Works

1. **Release Process**: When a new version is released in the main repository
2. **Automated Update**: The homebrew-releaser GitHub Action automatically updates the formula
3. **Direct Commit**: Formula changes are committed directly to this repository
4. **User Access**: Users can immediately install/upgrade via Homebrew

### No Manual Intervention Required

- Formula updates happen automatically with each release
- Version numbers, download URLs, and SHA256 checksums are updated automatically
- No pull requests or manual review needed for routine updates

## Formula Details

- **Package**: `usbipd-mac`
- **Formula**: [`Formula/usbipd-mac.rb`](Formula/usbipd-mac.rb)
- **Requirements**: macOS 11.0+, Xcode 13.0+ (build time)
- **License**: MIT

## Repository Structure

```
homebrew-usbipd-mac/
├── Formula/
│   └── usbipd-mac.rb          # Main formula file
└── .github/
    └── workflows/
        └── archived/           # Archived webhook workflows (no longer used)
            ├── README.md       # Migration explanation
            ├── formula-update.yml.archived
            └── debug-dispatch.yml.archived
```

## Migration Note

This tap previously used webhook-based formula updates but has migrated to homebrew-releaser for improved reliability and simplified architecture. Webhook workflows have been archived for reference.

## Support

- **Main Project**: https://github.com/beriberikix/usbipd-mac
- **Issues**: Report issues in the main repository
- **Documentation**: See main repository for usage and troubleshooting

## Contributing

Formula updates are automated. For changes to the formula structure or dependencies, please open an issue in the main repository.