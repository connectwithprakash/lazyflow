---
disable-model-invocation: true
argument-hint: "[milestone-name e.g. v1.8]"
description: "Milestone release preparation and checklist"
---

# Release Version

Prepares a milestone release. Does NOT merge — the user performs the final merge manually.

## Steps

### 1. Check Milestone Completion

```bash
gh issue list --milestone "$ARGUMENTS" --state open
```

If open issues remain, list them and ask: defer to next milestone or block release?

### 2. Review Release Please PR

```bash
gh pr list --label "autorelease: pending"
```

Read the PR body — verify CHANGELOG.md entries are correct and complete.

### 3. Verify Version Artifacts

- Check `scripts/bump-version.sh` handles the version correctly
- Verify `scripts/generate-release-notes.sh` produces correct release notes
- Confirm `fastlane/metadata/en-US/release_notes.txt` looks good

### 4. Documentation Review

- `docs/project/roadmap.md` — milestone features documented
- `README.md` — update if major features change capabilities
- `fastlane/metadata/en-US/description.txt` — update if app scope changed

### 5. Marketing Text Check

```bash
cat fastlane/metadata/en-US/promotional_text.txt
```

Ask user: does promotional text need updating for this release? (This is NOT auto-generated.)

### 6. Present Checklist

```markdown
## Release Checklist: $ARGUMENTS

- [ ] All milestone issues closed (or deferred)
- [ ] Release Please PR reviewed
- [ ] CHANGELOG.md entries correct
- [ ] Release notes updated
- [ ] Promotional text reviewed
- [ ] Documentation updated

**Ready to merge Release Please PR?**
```

### 7. Post-Merge Monitoring

After user merges the Release Please PR:
1. Monitor CI: `gh run list --limit 3`
2. Verify GitHub Release was created: `gh release list --limit 1`
3. Confirm TestFlight build was uploaded (check CI logs)
4. Remind user about App Store submission workflow when ready

## Release Pipeline Reference

```
Merge Release Please PR
  -> GitHub Release + tag created
    -> CI: bump version + generate release notes
      -> CI: build + upload to TestFlight
        -> User tests on TestFlight
          -> User updates promotional_text.txt
            -> User triggers App Store workflow (workflow_dispatch)
```

Three human decision points: merge PR, update promo text, trigger App Store.
