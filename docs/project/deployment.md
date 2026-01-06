# Deployment Guide

This guide covers how to deploy Taskweave to TestFlight and the App Store using Fastlane.

## Overview

Taskweave uses [Fastlane](https://fastlane.tools/) for automated deployments:
- **Code signing**: Managed by [match](https://docs.fastlane.tools/actions/match/) with certificates stored in a private Git repo
- **Authentication**: App Store Connect API key (no 2FA required)
- **Targets**: Main app, widget, and watch app

## Prerequisites

Before you can deploy, you need:

1. **Access to the certificates repo** - Request access to `taskweave-certificates` (private)
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

### 3. Sync Certificates

```bash
# Set the match password
export MATCH_PASSWORD="your-password"

# Sync development certificates
bundle exec fastlane sync_dev_certs

# Sync App Store certificates
bundle exec fastlane sync_appstore_certs
```

## Available Lanes

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

## Deployment Workflow

### Deploy to TestFlight

```bash
export MATCH_PASSWORD="your-password"
bundle exec fastlane beta
```

This will:
1. Sync App Store certificates
2. Increment the build number
3. Build the app
4. Upload to TestFlight

### Deploy to App Store

```bash
export MATCH_PASSWORD="your-password"
bundle exec fastlane release
```

This will:
1. Sync App Store certificates
2. Increment the build number
3. Build the app
4. Upload to App Store Connect (ready for manual submission)

## Certificates Management

Certificates are stored encrypted in the private `taskweave-certificates` repo and managed by Fastlane match.

### Certificate Types

| Type | Purpose | Provisioning Profiles |
|------|---------|----------------------|
| **Development** | Local testing on devices | `match Development com.taskweave.app` |
| **App Store** | TestFlight & App Store distribution | `match AppStore com.taskweave.app` |

### Regenerating Certificates

If certificates expire or need to be regenerated:

```bash
# This will create new certificates and update the repo
bundle exec fastlane setup_certs
```

## Troubleshooting

### "Could not find app on App Store Connect"

The app needs to be created on App Store Connect first. Go to [App Store Connect](https://appstoreconnect.apple.com/) and create a new app with bundle ID `com.taskweave.app`.

### "No code signing identity found"

Run `fastlane sync_appstore_certs` to install certificates to your keychain.

### "Invalid provisioning profile"

Regenerate profiles:
```bash
bundle exec fastlane match appstore --force
```

### Match password issues

Ensure `MATCH_PASSWORD` environment variable is set:
```bash
export MATCH_PASSWORD="your-password"
```

## Security Notes

- **Never commit** the `fastlane/keys/` directory (it's gitignored)
- **Never share** the match password in plain text
- **API keys** should be shared securely (e.g., 1Password, encrypted message)
- The certificates repo is **private** - only team members have access

## App Store Connect Setup

Before first deployment, create the app on App Store Connect:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: Taskweave
   - Primary Language: English (U.S.)
   - Bundle ID: com.taskweave.app
   - SKU: com.taskweave.app
4. Create the app

Then prepare metadata:
- App description
- Keywords
- Screenshots (iPhone, iPad)
- App icon (1024x1024)
- Privacy policy URL: https://taskweave.netlify.app/privacy
- Support URL: https://taskweave.netlify.app
