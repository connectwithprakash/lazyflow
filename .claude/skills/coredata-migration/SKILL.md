---
disable-model-invocation: true
argument-hint: "[describe-change e.g. 'add dueDate field to TaskItem']"
description: "Safe Core Data model migration with CloudKit compatibility"
---

# Core Data Migration

Guides a safe Core Data model migration.

## STOP — L2 Escalation Required

**Modifying `.xcdatamodeld` files is an L2 action per the project's escalation policy.** Before proceeding with ANY migration steps:

1. Clearly state to the user: "This requires modifying the Core Data model, which is an L2 action. I need your confirmation before making changes to .xcdatamodeld files."
2. Wait for explicit user confirmation before editing any model files
3. If the requested change is NOT safe (type change, rename, delete on a CloudKit-synced entity), warn the user prominently BEFORE they invest time in the approach

This escalation exists because Core Data model changes are hard to reverse and can break iCloud sync for all users.

## Phase 1: Assess the Change

1. Parse the requested change from the argument
2. Read the current model to understand existing entities and relationships:
   - Explore `Lazyflow/Sources/Models/Lazyflow.xcdatamodeld/`
   - Read entity extension files in `Lazyflow/Sources/Models/`
3. **Check if the attribute already exists** — if the user asks to "add" a field that already exists (possibly with a different type), this is a TYPE CHANGE, not an addition. Flag this immediately.
4. Classify the migration type:

| Change Type | Migration | CloudKit Compatible? |
|------------|-----------|---------------------|
| Add new attribute (optional) | Lightweight ✅ | Yes ✅ |
| Add new attribute (required + default) | Lightweight ✅ | No ❌ (must be optional) |
| Add new entity | Lightweight ✅ | Yes ✅ |
| Add new relationship | Lightweight ✅ | Yes ✅ (if optional) |
| Rename attribute | Mapping model needed | No ❌ |
| Delete attribute | Lightweight ✅ | No ❌ (additive only) |
| Change attribute type | Mapping model needed | No ❌ |
| Make optional → required | Mapping model needed | No ❌ |

**CloudKit constraint:** All changes MUST be additive. You cannot rename, delete, or change types of existing attributes synced via CloudKit.

### Current Model State

**Current version:** `Lazyflow 3.xcdatamodel` (3 versions total)

**Entities:**
- **TaskEntity** — 29 attributes, 4 relationships (list, parentTask, recurringRule, subtasks)
- **TaskListEntity** — 7 attributes, 1 relationship (tasks)
- **RecurringRuleEntity** — 11 attributes incl. Transformable arrays, 1 relationship (task)
- **QuickNoteEntity** — 6 attributes, no relationships
- **CustomCategoryEntity** — 6 attributes, no relationships

**Key relationships:**
- TaskEntity ↔ TaskListEntity (many-to-one via `list`/`tasks`)
- TaskEntity ↔ TaskEntity (self-referential via `parentTask`/`subtasks`, cascade delete)
- TaskEntity ↔ RecurringRuleEntity (one-to-one via `recurringRule`/`task`, cascade delete)

**All entities use `syncable="YES"`** — CloudKit-compatible changes only.

## Phase 2: Pre-Migration Checklist

- [ ] Current model version identified (`Lazyflow 3.xcdatamodel`)
- [ ] All entity relationships documented
- [ ] Change is CloudKit-compatible (additive only)
- [ ] Backup: `git stash` or commit current work
- [ ] User has confirmed the change (L2 requirement)

## Phase 3: Migration Steps (User-Guided)

**These steps must be performed in Xcode by the user. Guide them through each step.**

### 3a. Create New Model Version
1. In Xcode: Select `Lazyflow.xcdatamodeld` → Editor → Add Model Version
2. Name: `Lazyflow {N+1}` (next would be `Lazyflow 4`)
3. Set the new version as **Current** in File Inspector

### 3b. Modify the Model
1. Select the new model version
2. Add/modify attributes, entities, or relationships as needed
3. For new attributes: set as **Optional** (CloudKit requirement)
4. Set appropriate default values where needed

### 3c. Update Code
After the user has modified the model in Xcode:

1. Update entity extension files:
   ```
   Lazyflow/Sources/Models/{Entity}+DomainModel.swift
   Lazyflow/Sources/Models/{Entity}+Extensions.swift
   ```
2. Update affected services:
   ```
   Lazyflow/Sources/Services/TaskService.swift
   Lazyflow/Sources/Services/TaskListService.swift
   Lazyflow/Sources/Services/QuickNoteService.swift
   Lazyflow/Sources/Services/CategoryService.swift
   ```
3. Update ViewModels that display the data
4. Update any fetch requests or predicates

### 3d. Verify PersistenceController Configuration
The PersistenceController (`Lazyflow/Sources/Services/PersistenceController.swift`) already has lightweight migration enabled:
```swift
description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
```

These options are set in both `init()` and `reloadStoreWithCurrentSyncSettings()`. No changes needed for lightweight migrations.

For heavyweight migrations: create a mapping model (.xcmappingmodel) — but note this is **incompatible with CloudKit sync**.

## Phase 4: Testing

```bash
# 1. Test fresh install (no migration)
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LazyflowTests/PersistenceControllerTests

# 2. Test full suite
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# 3. Manual verification
# - Install previous version on simulator
# - Add test data
# - Install new version over it
# - Verify data migrated correctly
```

### Migration Test Template
```swift
func testMigrationFromPreviousVersion() throws {
    // Load old model store
    // Open with new model
    // Verify all data accessible
    // Verify new attributes have expected defaults
}
```

## Phase 5: Rollback Plan

If migration fails:
1. `git checkout -- Lazyflow/Sources/Models/Lazyflow.xcdatamodeld/`
2. Revert entity extension changes
3. Clean build: `xcodebuild clean -scheme Lazyflow`
4. Rebuild and verify original tests pass

## CloudKit Sync Verification

After migration:
1. Test on device with iCloud enabled
2. Verify new data syncs to CloudKit (container: `iCloud.com.lazyflow.app`)
3. Verify existing data is preserved
4. Test sync between devices with old and new versions

## Common Pitfalls

- **Never delete CloudKit-synced attributes** — mark as unused instead
- **Required attributes break CloudKit** — always use Optional
- **Mapping models don't work with CloudKit** — stick to lightweight migrations
- **Test in-memory stores don't test migration** — need on-disk store for migration testing
- **Entity extension files stay in app target** — not in SPM packages (can't reference .xcdatamodeld)
- **Run `xcodegen generate` after model changes** — ensures project references are updated
