# Contributing to Lazyflow

Thank you for your interest in contributing to Lazyflow!

## Development Workflow

### 1. Create an Issue

Before starting work, create a GitHub issue:
- **Bug**: Use the bug report template
- **Feature**: Use the feature request template
- **Other**: Create a blank issue with clear description

### 2. Create a Branch

Create a branch from `main` following this convention:

```
<type>/<issue-number>-<short-description>
```

| Type | Use for |
|------|---------|
| `feature` | New features |
| `fix` | Bug fixes |
| `docs` | Documentation |
| `refactor` | Code restructure |
| `chore` | Maintenance |

Examples:
- `feature/23-add-dark-mode`
- `fix/45-login-crash`
- `docs/12-update-readme`

### 3. Make Changes

- Write code following project conventions
- Use conventional commits (see below)
- Keep commits focused and atomic

### 4. Create a Pull Request

- Link to the related issue
- Fill out the PR template
- Request review when ready

### 5. Review & Merge

- Address review feedback
- Squash merge to main
- Delete the branch after merge

## Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/connectwithprakash/lazyflow.git
   cd lazyflow
   ```

2. Open the project:
   ```bash
   open Lazyflow.xcodeproj
   ```

3. Build and run in Xcode (Cmd+R)

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

| Type | Use for | Version Bump |
|------|---------|--------------|
| `feat` | New feature | Minor (0.1.0) |
| `fix` | Bug fix | Patch (0.0.1) |
| `feat!` | Breaking change | Major (1.0.0) |
| `docs` | Documentation | None |
| `refactor` | Code restructure | None |
| `test` | Tests | None |
| `chore` | Maintenance | None |
| `ci` | CI/CD changes | None |

**Breaking Changes:** Add `!` after type (e.g., `feat!:`) or include `BREAKING CHANGE:` in commit body.

Examples:
- `feat(tasks): add recurring task support`
- `fix(calendar): resolve sync conflict on iOS 17`
- `docs(readme): update installation instructions`

## Release Process

We use [release-please](https://github.com/googleapis/release-please) for automated releases:

1. `feat:` and `fix:` commits on `main` update a release PR
2. Merging the release PR creates a GitHub release
3. iOS version is automatically updated in Xcode project

No manual version bumping required.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
