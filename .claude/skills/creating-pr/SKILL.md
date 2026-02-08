---
disable-model-invocation: true
argument-hint: "[base-branch]"
description: "Create a well-formatted pull request with conventional commit title"
---

# Create Pull Request

Creates a properly formatted PR. Base branch defaults to `main` if not specified.

## Steps

1. **Gather context:**
   ```bash
   git log main...HEAD --oneline
   git diff main...HEAD --stat
   ```

2. **Extract issue number** from branch name (e.g., `feat/43-smart-learning` -> `#43`)

3. **Determine PR title** from the primary conventional commit:
   - Use the most significant commit message as the title
   - Format: `feat(scope): description (#issue)` or `fix(scope): description (#issue)`

4. **Build PR body** using this template:
   ```markdown
   ## Summary
   - <bullet 1: what changed>
   - <bullet 2: why it changed>
   - <bullet 3: key technical decisions>

   ## Test Plan
   - [ ] Unit tests pass
   - [ ] Build succeeds on iPhone 17 Pro simulator
   - [ ] <specific test scenarios from the feature>

   ## Screenshots
   <!-- Add if UI changed -->

   Closes #<issue-number>
   ```

5. **Push and create PR** (requires user confirmation — this is an L3 action):
   ```bash
   git push -u origin HEAD
   gh pr create --title "..." --body "..." --base {base-branch}
   ```

6. **Return the PR URL** to the user
