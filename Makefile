.PHONY: help generate build build-release test run app dmg release install uninstall open-dist-app open-installed-app clean

APP_NAME := AeroMux
PROJECT := $(APP_NAME).xcodeproj
PROJECT_FILE := $(PROJECT)/project.pbxproj
SCHEME := $(APP_NAME)
DERIVED_DATA := DerivedData
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_INSTALL_DIR ?= /Applications
APP_INSTALL_PATH := $(APP_INSTALL_DIR)/$(APP_NAME).app
VERSION ?= $(shell git describe --tags --always --dirty)

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA)
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Regenerate the Xcode project when the spec changes or when files are added,
# removed, or renamed under Sources/ or Tests/ (which updates the mtime of the
# containing directory). xcodegen may leave an unchanged project untouched, so
# touch it to keep make from regenerating on every run.
PROJECT_INPUTS := project.yml $(shell find Sources Tests -type d)

$(PROJECT_FILE): $(PROJECT_INPUTS)
	xcodegen generate
	touch $@

generate: ## Regenerate the Xcode project from project.yml
	xcodegen generate

build: $(PROJECT_FILE) ## Build the debug app with xcodebuild
	$(XCODEBUILD) -configuration Debug build

build-release: $(PROJECT_FILE) ## Build the release app with xcodebuild
	$(XCODEBUILD) -configuration Release build

test: $(PROJECT_FILE) ## Run the unit tests with xcodebuild
	$(XCODEBUILD) -configuration Debug test

run: build ## Build and launch the debug app
	open "$(DEBUG_APP)"

app: ## Build the Developer ID-signed .app bundle into dist/
	VERSION="$(VERSION)" ./scripts/build-release-app.sh

dmg: ## Build (and notarize, if credentials are set) the DMG into dist/
	VERSION="$(VERSION)" ./scripts/build-release-dmg.sh

release: dmg ## Publish a GitHub release from a local notarized build (set VERSION=vX.Y.Z and AEROMUX_NOTARY_PROFILE)
	cd "$(DIST_DIR)" && shasum -a 256 "$(APP_NAME)-$(VERSION).dmg" > "$(APP_NAME)-$(VERSION).dmg.sha256"
	gh release create "$(VERSION)" \
		"$(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg" \
		"$(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg.sha256" \
		--generate-notes --title "$(VERSION)"

install: app ## Install the built app bundle into /Applications
	rm -rf "$(APP_INSTALL_PATH)"
	/usr/bin/ditto "$(APP_BUNDLE)" "$(APP_INSTALL_PATH)"
	@printf 'Installed %s\n' "$(APP_INSTALL_PATH)"

uninstall: ## Remove the installed app bundle from /Applications
	rm -rf "$(APP_INSTALL_PATH)"
	@printf 'Removed %s\n' "$(APP_INSTALL_PATH)"

open-dist-app: app ## Open the locally built app bundle from dist/
	open "$(APP_BUNDLE)"

open-installed-app: ## Open the installed app from /Applications
	open "$(APP_INSTALL_PATH)"

clean: ## Remove build, packaging, and generated-project artifacts
	rm -rf "$(DERIVED_DATA)" "$(DIST_DIR)" build "$(PROJECT)" Packaging/AeroMux-Info.generated.plist
