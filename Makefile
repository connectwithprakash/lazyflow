# Makefile for Lazyflow iOS App
# Uses Ruby 3.3 for Fastlane compatibility

RUBY_PATH := /opt/homebrew/opt/ruby@3.3/bin
BUNDLE := PATH=$(RUBY_PATH):$$PATH bundle exec

# Retrieve MATCH_PASSWORD from macOS Keychain
export MATCH_PASSWORD = $(shell security find-generic-password -a "fastlane" -s "match_password" -w 2>/dev/null)

.PHONY: help test beta release sync-certs bump-patch bump-minor bump-major setup-keychain build-info

help:
	@echo "Lazyflow Deployment Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  test           Run all tests"
	@echo "  beta           Build and upload to TestFlight"
	@echo "  release        Build and submit to App Store"
	@echo "  sync-certs     Sync App Store certificates"
	@echo "  bump-patch     Increment patch version (x.x.X)"
	@echo "  bump-minor     Increment minor version (x.X.0)"
	@echo "  bump-major     Increment major version (X.0.0)"
	@echo "  build-info     Show current version and TestFlight build info"
	@echo "  setup-keychain Store MATCH_PASSWORD in macOS Keychain"
	@echo ""
	@echo "Password is automatically retrieved from macOS Keychain."

test:
	$(BUNDLE) fastlane test

beta:
ifeq ($(MATCH_PASSWORD),)
	$(error MATCH_PASSWORD not found in Keychain. Run: make setup-keychain)
endif
	$(BUNDLE) fastlane beta

release:
ifeq ($(MATCH_PASSWORD),)
	$(error MATCH_PASSWORD not found in Keychain. Run: make setup-keychain)
endif
	$(BUNDLE) fastlane release

sync-certs:
ifeq ($(MATCH_PASSWORD),)
	$(error MATCH_PASSWORD not found in Keychain. Run: make setup-keychain)
endif
	$(BUNDLE) fastlane sync_appstore_certs

bump-patch:
	$(BUNDLE) fastlane bump_version type:patch

bump-minor:
	$(BUNDLE) fastlane bump_version type:minor

bump-major:
	$(BUNDLE) fastlane bump_version type:major

setup-keychain:
	@echo "Enter MATCH_PASSWORD to store in macOS Keychain:"
	@read -s password && security add-generic-password -a "fastlane" -s "match_password" -w "$$password" -U
	@echo "Password stored in Keychain."

build-info:
	$(BUNDLE) fastlane build_info
