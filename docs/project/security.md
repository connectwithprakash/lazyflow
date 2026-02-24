# Security Model

Lazyflow follows iOS security best practices to protect user data at rest and in transit.

## Data Protection

### Core Data (Tasks, Lists, Notes)
- **File protection**: `NSFileProtectionComplete` on the persistent store — the SQLite database is encrypted by the OS and inaccessible when the device is locked.
- **CloudKit sync**: Uses Apple's end-to-end encrypted private database. Data is stored in the user's iCloud private zone and is not accessible to the developer.

### API Keys (LLM Provider Credentials)
- Stored in the iOS **Keychain** with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:
  - Only accessible when the device is unlocked
  - Not included in iCloud Keychain sync or device backups
  - Not exposed through UserDefaults or Codable serialization
- The `OpenResponsesConfig.apiKey` field is intentionally excluded from `Codable` encoding to prevent accidental persistence outside the Keychain.

### UserDefaults (@AppStorage)
Only non-sensitive UI preferences are stored in UserDefaults:
- Appearance mode, reminder times, feature toggles
- Pomodoro timer settings, calendar sync preferences
- Onboarding completion flags, last-viewed dates

No passwords, tokens, or personally identifiable information is stored in UserDefaults.

## Network Security

### App Transport Security (ATS)
- **No ATS exceptions** — all network requests require HTTPS by default.
- No `NSAllowsArbitraryLoads` or `NSExceptionDomains` in Info.plist.

### HTTPS Enforcement (LLM Providers)
- External AI provider endpoints must use HTTPS. HTTP is rejected at the request-building layer with a clear error.
- **Localhost exemption**: `localhost`, `127.0.0.1`, `::1`, and `.local` addresses are allowed over HTTP for local inference servers (e.g., Ollama).
- Endpoint URL validation is also enforced in the provider configuration UI.

### CloudKit
- Uses Apple's CloudKit framework over HTTPS.
- Private database operations are authenticated via the user's iCloud account.

## Source Code Hygiene

- **No hardcoded secrets** in source code.
- `.gitignore` excludes sensitive paths: `.env`, `*.p12`, `*.mobileprovision`, Fastlane credentials.
- API keys are never logged, printed, or included in crash reports.
- MetricKit diagnostic payloads are logged at the `error` level but contain only system-level crash data, not user content.

## Audit Summary

| Area | Status | Details |
|------|--------|---------|
| ATS | Secure | No exceptions configured |
| Core Data | Encrypted | `NSFileProtectionComplete` on store |
| Keychain | Hardened | `WhenUnlockedThisDeviceOnly` accessibility |
| UserDefaults | Clean | UI preferences only |
| Network (LLM) | Enforced | HTTPS required for external endpoints |
| Source code | Clean | No hardcoded secrets |
| Git | Protected | Credentials excluded via .gitignore |
