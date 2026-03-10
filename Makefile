.PHONY: help build build-release run app dmg install uninstall open-dist-app open-installed-app clean

APP_NAME := AeroMux
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_INSTALL_DIR ?= /Applications
APP_INSTALL_PATH := $(APP_INSTALL_DIR)/$(APP_NAME).app
VERSION ?= $(shell git describe --tags --always --dirty)

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the debug binary with SwiftPM
	swift build

build-release: ## Build the release binary with SwiftPM
	swift build -c release

run: ## Run the app from source with SwiftPM
	swift run

app: ## Build the macOS .app bundle into dist/
	VERSION="$(VERSION)" ./scripts/build-release-app.sh

dmg: ## Build the DMG into dist/
	VERSION="$(VERSION)" ./scripts/build-release-dmg.sh

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

clean: ## Remove SwiftPM and packaging build artifacts
	swift package clean
	rm -rf "$(DIST_DIR)"
