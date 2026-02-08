#!/bin/bash
# Creates GitHub labels for agent-driven issue triage.
# Safe to run multiple times — uses --force to upsert existing labels.

set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
echo "Setting up labels for $REPO"

create_label() {
    local name="$1"
    local color="$2"
    local description="$3"
    echo "  Creating: $name"
    gh label create "$name" --color "$color" --description "$description" --force 2>/dev/null || true
}

echo ""
echo "=== Priority Labels ==="
create_label "priority:critical" "B60205" "Must fix immediately — blocks release or causes data loss"
create_label "priority:high"     "D93F0B" "Should fix this milestone"
create_label "priority:medium"   "FBCA04" "Nice to fix this milestone"
create_label "priority:low"      "0E8A16" "Can wait for a future milestone"

echo ""
echo "=== Type Labels ==="
create_label "type:bug"      "D73A4A" "Something is broken"
create_label "type:feature"  "0075CA" "New functionality"
create_label "type:refactor" "CFD3D7" "Code improvement without behavior change"
create_label "type:design"   "C5DEF5" "UI/UX design work"
create_label "type:chore"    "EDEDED" "Maintenance, deps, CI, tooling"
create_label "type:docs"     "0075CA" "Documentation updates"

echo ""
echo "=== Scope Labels ==="
create_label "scope:ai"        "8B5CF6" "Apple Intelligence, on-device ML"
create_label "scope:calendar"  "1D76DB" "EventKit, calendar integration"
create_label "scope:core-data" "E99695" "Core Data models, persistence"
create_label "scope:ui"        "BFD4F2" "SwiftUI views, design system"
create_label "scope:watch"     "F9D0C4" "Apple Watch app"
create_label "scope:widget"    "FEF2C0" "Home Screen widgets"

echo ""
echo "=== Agent Labels ==="
create_label "agent:autonomous"   "0E8A16" "Agent can handle without human input"
create_label "agent:needs-review" "FBCA04" "Requires human review before proceeding"
create_label "agent:blocked"      "D93F0B" "Agent is blocked and needs human help"
create_label "agent:in-progress"  "1D76DB" "Agent is actively working on this"

echo ""
echo "Done! Run 'gh label list' to verify."
