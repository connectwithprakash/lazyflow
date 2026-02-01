# Deployment Guide

This guide covers how to deploy Lazyflow to TestFlight and the App Store using Fastlane.

## Quick Start

```bash
# One-time setup: store password in macOS Keychain
make setup-keychain

# Deploy to TestFlight
make beta

# Deploy to App Store
make release

# Check current version info
make build-info
```

## Overview

Lazyflow uses [Fastlane](https://fastlane.tools/) for automated deployments:
- **Code signing**: Managed by [match](https://docs.fastlane.tools/actions/match/) with certificates stored in a private Git repo
- **Authentication**: App Store Connect API key (no 2FA required)
- **Targets**: Main app, widget, and watch app
- **Automation**: Makefile wraps Fastlane for simpler commands

## Prerequisites

Before you can deploy, you need:

1. **Access to the certificates repo** - Request access to `lazyflow-certificates` (private)
2. **Match password** - For decrypting certificates (ask a team member)
3. **App Store Connect API key** - The `.p8` file and `api_key.json`

## Initial Setup

### 1. Install Dependencies

```bash
# Install Ruby (if not using system Ruby)
brew install ruby@3.3

# Add to PATH (add to ~/.zshrc for persistence)
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"

# Install Fastlane
bundle install
```

### 2. Set Up API Key

Get the App Store Connect API key from a team member and place it in:

```
fastlane/keys/
├── AuthKey_FM4R243635.p8    # Private key file
└── api_key.json              # Key configuration
```

The `api_key.json` format:
```json
{
  "key_id": "FM4R243635",
  "issuer_id": "96211e5a-ff10-4a17-bb3f-9f468f93457d",
  "key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
  "in_house": false
}
```

### 3. Store Match Password in Keychain

Instead of exporting `MATCH_PASSWORD` every time, store it securely in macOS Keychain:

```bash
make setup-keychain
# Enter your match password when prompted
```

The Makefile automatically retrieves this password when running deployment commands.

### 4. Sync Certificates

```bash
# Sync App Store certificates
make sync-certs

# Or use Fastlane directly
bundle exec fastlane sync_appstore_certs
```

## Available Commands

### Makefile (Recommended)

| Command | Description |
|---------|-------------|
| `make test` | Run all tests |
| `make beta` | Build and upload to TestFlight |
| `make release` | Build and submit to App Store |
| `make sync-certs` | Sync App Store certificates |
| `make build-info` | Show current version and TestFlight build info |
| `make bump-patch` | Increment patch version (x.x.X) |
| `make bump-minor` | Increment minor version (x.X.0) |
| `make bump-major` | Increment major version (X.0.0) |
| `make setup-keychain` | Store MATCH_PASSWORD in macOS Keychain |

### Fastlane Lanes

| Lane | Command | Description |
|------|---------|-------------|
| **test** | `bundle exec fastlane test` | Run all tests |
| **sync_dev_certs** | `bundle exec fastlane sync_dev_certs` | Sync development certificates (readonly) |
| **sync_appstore_certs** | `bundle exec fastlane sync_appstore_certs` | Sync App Store certificates (readonly) |
| **setup_certs** | `bundle exec fastlane setup_certs` | Generate new certificates (initial setup only) |
| **beta** | `bundle exec fastlane beta` | Build and upload to TestFlight |
| **release** | `bundle exec fastlane release` | Build and submit to App Store |
| **refresh_dsyms** | `bundle exec fastlane refresh_dsyms` | Download dSYMs for crash reporting |
| **bump_version** | `bundle exec fastlane bump_version type:minor` | Increment version (patch/minor/major) |
| **build_info** | `bundle exec fastlane build_info` | Show version and build info |

## Deployment Workflow

### Deploy to TestFlight

```bash
make beta
```

This will:
1. Sync App Store certificates
2. Increment the build number
3. Build the app
4. Upload to TestFlight

### Deploy to App Store

```bash
make release
```

This will:
1. Sync App Store certificates
2. Increment the build number
3. Build the app
4. Upload to App Store Connect (ready for manual submission)

## Version Management

### Automatic Updates (Release-Please)

When release-please creates a new release, the GitHub Actions workflow automatically updates versions across the project using `scripts/bump-version.sh`:

- `Lazyflow.xcodeproj/project.pbxproj` (MARKETING_VERSION)
- `project.yml` (XcodeGen source)
- `docs/site/index.html` (website badge)
- `docs/site/design/index.html` (design system badge)
- `README.md` (version badge)

### Manual Version Updates

To manually update versions locally:

```bash
# Update all version strings to a specific version
./scripts/bump-version.sh 1.2.0
```

## Certificates Management

Certificates are stored encrypted in the private `lazyflow-certificates` repo and managed by Fastlane match.

### Certificate Types

| Type | Purpose | Provisioning Profiles |
|------|---------|----------------------|
| **Development** | Local testing on devices | `match Development com.lazyflow.app` |
| **App Store** | TestFlight & App Store distribution | `match AppStore com.lazyflow.app` |

### Regenerating Certificates

If certificates expire or need to be regenerated:

```bash
# This will create new certificates and update the repo
bundle exec fastlane setup_certs
```

## Troubleshooting

### "Could not find app on App Store Connect"

The app needs to be created on App Store Connect first. Go to [App Store Connect](https://appstoreconnect.apple.com/) and create a new app with bundle ID `com.lazyflow.app`.

### "No code signing identity found"

Run `fastlane sync_appstore_certs` to install certificates to your keychain.

### "Invalid provisioning profile"

Regenerate profiles:
```bash
bundle exec fastlane match appstore --force
```

### Match password issues

If using Makefile commands, ensure password is stored in Keychain:
```bash
make setup-keychain
```

If using Fastlane directly, set the environment variable:
```bash
export MATCH_PASSWORD="your-password"
```

## Security Notes

- **Never commit** the `fastlane/keys/` directory (it's gitignored)
- **Never share** the match password in plain text
- **API keys** should be shared securely (e.g., 1Password, encrypted message)
- The certificates repo is **private** - only team members have access

## Regional Compliance

### Excluded Territories

Lazyflow excludes certain territories due to AI/LLM regulatory compliance:

| Territory | Code | Reason |
|-----------|------|--------|
| China | CHN | Requires administrative license from MIIT for generative AI apps (CAC Interim Measures 2023) |

### Managing Territories

```bash
# View excluded territories and reasons
bundle exec fastlane show_excluded_territories

# Apply territory exclusions via App Store Connect API
bundle exec fastlane set_territories
```

**Important:** Do NOT set `price_tier` in Deliverfile - it can [reset territories to all 175 countries](https://github.com/fastlane/fastlane/discussions/21623).

### Before App Store Submission

1. **Run `set_territories` lane** to apply exclusions via API, OR
2. **Manually verify in App Store Connect**:
   - Go to App Store Connect → Pricing and Availability
   - Ensure excluded territories are unchecked

3. **The `submit_for_review` lane will remind you** to verify territories before submission

### Adding/Removing Territories

1. Update `fastlane/excluded_territories.json` with the territory code and reason
2. Run `bundle exec fastlane set_territories` to apply changes
3. Verify with `bundle exec fastlane show_excluded_territories`

## App Store Connect Setup

Before first deployment, create the app on App Store Connect:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: Lazyflow
   - Primary Language: English (U.S.)
   - Bundle ID: com.lazyflow.app
   - SKU: com.lazyflow.app
4. Create the app

Then prepare metadata:
- App description
- Keywords
- Screenshots (iPhone, iPad)
- App icon (1024x1024)
- Privacy policy URL: https://lazyflow.netlify.app/privacy
- Support URL: https://lazyflow.netlify.app
