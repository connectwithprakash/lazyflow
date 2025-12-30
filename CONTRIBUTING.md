# Contributing to Taskweave

Thank you for your interest in contributing to Taskweave!

## Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/connectwithprakash/taskweave.git
   cd taskweave
   ```

2. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

4. Open the project:
   ```bash
   open Taskweave.xcodeproj
   ```

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `refactor` | Code restructure |
| `test` | Tests |
| `chore` | Maintenance |

Examples:
- `feat(tasks): add recurring task support`
- `fix(calendar): resolve sync conflict on iOS 17`
- `docs(readme): update installation instructions`

## Pull Requests

1. Create a feature branch from `main`
2. Make your changes
3. Ensure all tests pass
4. Submit a pull request with a clear description

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
