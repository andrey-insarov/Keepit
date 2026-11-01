APP      = Keepit
VERSION ?= $(shell cat VERSION)
# Sparkle EdDSA public key (base64) — from `generate_keys`; empty disables the "Check for Updates" item.
SPARKLE_PUBLIC_KEY ?= $(shell cat SPARKLE_PUBLIC_KEY 2>/dev/null)
SPARKLE_FW = $(shell find .build -type d -name Sparkle.framework -path "*macos*" 2>/dev/null | head -1)
BUILD_NO ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
GIT_SHA  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
PLIST_SUBST = -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD_NO)/' -e 's/__SHA__/$(GIT_SHA)/' -e 's/__DATE__/$(BUILD_DATE)/'
# Universal (arm64 + x86_64) for distribution builds; single-arch for quick ad-hoc builds.
# `swift build --arch a --arch b` writes to <build-path>/apple/Products/Release.
UNIVERSAL ?= $(if $(filter -,$(SIGN_ID)),0,1)
ifeq ($(UNIVERSAL),1)
ARCH_FLAGS = --arch arm64 --arch x86_64
else
ARCH_FLAGS =
endif
# Ask SwiftPM where it puts the products — the layout differs between toolchains and arch sets.
BUILD    = $(shell swift build -c release $(ARCH_FLAGS) --show-bin-path 2>/dev/null)
APPSTORE_BUILD = $(shell KEEPIT_APPSTORE=1 swift build -c release $(ARCH_FLAGS) --build-path .build-appstore --show-bin-path 2>/dev/null)
# Universal check: hard error on CI (release artifacts), a warning for local builds whose toolchain may lack a slice.
define CHECK_UNIVERSAL
	@if [ "$(UNIVERSAL)" = "1" ]; then \
	  if lipo -archs $(CONTENTS)/MacOS/$(APP) | grep -q x86_64 && lipo -archs $(CONTENTS)/MacOS/$(APP) | grep -q arm64; then echo "Universal binary: $$(lipo -archs $(CONTENTS)/MacOS/$(APP))"; \
	  else echo "WARNING: not a universal binary ($$(lipo -archs $(CONTENTS)/MacOS/$(APP)))"; [ -z "$$CI" ] || exit 1; fi; \
	fi
endef
BUNDLE   = $(APP).app
CONTENTS = $(BUNDLE)/Contents
# Ad-hoc signature by default. See README "Accessibility permission resets after rebuild".
# For distribution: SIGN_ID="Developer ID Application: Name (TEAMID)" — adds hardened runtime + timestamp.
SIGN_ID ?= -
# Developer ID provisioning profile (developer.apple.com → Profiles → Developer ID). Optional: with it the
# app carries Team-ID entitlements and Touch ID unlock works; without it the app still runs, minus Touch ID.
DEVID_PROFILE ?= Resources/KeepitDevID.provisionprofile
ifeq ($(SIGN_ID),-)
SIGN_FLAGS =
HAVE_PROFILE =
else
# Team ID is the part in parentheses of the identity name, e.g. "Developer ID Application: X (ABCDE12345)".
TEAM_ID ?= $(shell echo '$(SIGN_ID)' | sed -E 's/.*\(([A-Z0-9]+)\).*/\1/')
ifneq ($(wildcard $(DEVID_PROFILE)),)
HAVE_PROFILE = 1
SIGN_FLAGS = --options runtime --timestamp --entitlements .build/devid.entitlements
else
HAVE_PROFILE =
SIGN_FLAGS = --options runtime --timestamp --entitlements Resources/Keepit-base.entitlements
endif
endif
# App icon: on a Mac build the .icns with Apple's iconutil from the committed iconset (canonical
# layout); elsewhere fall back to the committed Resources/Icon/AppIcon.icns (made by make_icns.py).
ICNS = $(if $(shell command -v iconutil 2>/dev/null),.build/AppIcon.icns,Resources/Icon/AppIcon.icns)
.build/AppIcon.icns: $(wildcard Resources/Icon/AppIcon.iconset/*.png)
	mkdir -p .build && iconutil -c icns -o $@ Resources/Icon/AppIcon.iconset

# Notarization: NOTARY_PROFILE (xcrun notarytool store-credentials) or the APPSTORE_* env vars used by CI.
NOTARY_PROFILE ?=

.PHONY: build app run install clean dist dmg icon notarize appstore appcast

# Sign the DMG with the Sparkle EdDSA key and write appcast.xml next to it.
#   make appcast SPARKLE_PRIVATE_KEY_FILE=path   (or the key in the keychain from generate_keys)
SPARKLE_BIN = $(shell find .build -type d -name bin -path "*artifacts*parkle*" 2>/dev/null | head -1)
SPARKLE_PRIVATE_KEY_FILE ?=
appcast: 
	@test -n "$(SPARKLE_BIN)" || (echo "Sparkle tools not found under .build/artifacts — run swift build first"; exit 1)
	rm -rf .build/appcast && mkdir -p .build/appcast && cp $(DMG) .build/appcast/
	$(SPARKLE_BIN)/generate_appcast $(if $(SPARKLE_PRIVATE_KEY_FILE),--ed-key-file $(SPARKLE_PRIVATE_KEY_FILE),) \
	  --download-url-prefix "https://github.com/andrey-insarov/Keepit/releases/download/v$(VERSION)/" \
	  --link "https://github.com/andrey-insarov/Keepit/releases" \
	  --embed-release-notes .build/appcast
	cp .build/appcast/appcast.xml appcast.xml
	# Detached EdDSA signature (same Sparkle key) and checksums, for manual verification of downloads.
	$(SPARKLE_BIN)/sign_update $(if $(SPARKLE_PRIVATE_KEY_FILE),--ed-key-file $(SPARKLE_PRIVATE_KEY_FILE),) -p $(DMG) > $(DMG).sig
	shasum -a 256 $(DMG) $(APP)-$(VERSION).zip > SHA256SUMS
	@echo "Wrote appcast.xml, $(DMG).sig and SHA256SUMS"

DMG      = $(APP)-$(VERSION).dmg
DMG_VOL  = Keepit
DMG_TMP  = .build/dmg

# Disk image with the app and an Applications shortcut (drag-and-drop install).
dmg: app
	rm -rf $(DMG_TMP) $(DMG)
	mkdir -p $(DMG_TMP)
	cp -R $(BUNDLE) $(DMG_TMP)/
	ln -s /Applications $(DMG_TMP)/Applications
	cp Resources/Icon/AppIcon.icns $(DMG_TMP)/.VolumeIcon.icns
	SetFile -c icnC $(DMG_TMP)/.VolumeIcon.icns 2>/dev/null || true
	hdiutil create -volname "$(DMG_VOL)" -srcfolder $(DMG_TMP) -ov -fs HFS+ -format UDRW $(DMG_TMP)/rw.dmg
	# Mount read-write to set the volume icon flag and Finder window layout, then convert to compressed read-only.
	MOUNT=$$(hdiutil attach -readwrite -noverify $(DMG_TMP)/rw.dmg | grep -o '/Volumes/.*' | head -1); \
	SetFile -a C "$$MOUNT" 2>/dev/null || true; \
	perl -e 'alarm 60; exec @ARGV' osascript Resources/dmg-layout.applescript "$$MOUNT" >/dev/null 2>&1 || true; \
	sync; hdiutil detach "$$MOUNT" -quiet || hdiutil detach "$$MOUNT" -force
	hdiutil convert $(DMG_TMP)/rw.dmg -format UDZO -imagekey zlib-level=9 -o $(DMG)
	codesign --force $(if $(filter -,$(SIGN_ID)),,--timestamp) --sign "$(SIGN_ID)" $(DMG) 2>/dev/null || true
	rm -rf $(DMG_TMP)
	@echo "Built $(DMG)"

# Submit the DMG to Apple, wait, then staple the ticket to both the DMG and the app (so the zip is good too).
notarize: dmg
ifneq ($(NOTARY_PROFILE),)
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
else
	xcrun notarytool submit $(DMG) --key "$(APPSTORE_KEY_PATH)" --key-id "$(APPSTORE_KEY_ID)" --issuer "$(APPSTORE_ISSUER_ID)" --wait
endif
	# Apple's ticket service drops connections now and then: retry stapling a few times.
	for t in $(DMG) $(BUNDLE); do \
	  n=0; until xcrun stapler staple "$$t"; do n=$$((n+1)); [ $$n -ge 5 ] && exit 68; echo "stapler failed, retry $$n/5 in 20s"; sleep 20; done; \
	done
	spctl -a -vv -t install $(DMG)
	@echo "Notarized and stapled $(DMG)"

# ---- Mac App Store build --------------------------------------------------------------------
# Needs: "Apple Distribution: <Team>" (or "3rd Party Mac Developer Application") and
# "3rd Party Mac Developer Installer" certificates, a Mac App Store provisioning profile for
# com.it.keep saved as Resources/Keepit.provisionprofile, and the App ID registered in App Store Connect.
#   make appstore APP_SIGN_ID="Apple Distribution: UK Intis Telecom LTD (TEAMID)" \
#                 PKG_SIGN_ID="3rd Party Mac Developer Installer: UK Intis Telecom LTD (TEAMID)" TEAM_ID=TEAMID
APP_SIGN_ID ?=
PKG_SIGN_ID ?=
TEAM_ID ?=
PKG = $(APP)-$(VERSION)-appstore.pkg

appstore: $(ICNS)
	@test -n "$(APP_SIGN_ID)" -a -n "$(PKG_SIGN_ID)" -a -n "$(TEAM_ID)" || (echo "set APP_SIGN_ID, PKG_SIGN_ID and TEAM_ID"; exit 1)
	@test -f Resources/Keepit.provisionprofile || (echo "missing Resources/Keepit.provisionprofile (Mac App Store profile for com.it.keep)"; exit 1)
	KEEPIT_APPSTORE=1 swift build -c release $(ARCH_FLAGS) --build-path .build-appstore
	rm -rf $(BUNDLE) $(PKG) .build/appstore.entitlements
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(APPSTORE_BUILD)/$(APP) $(CONTENTS)/MacOS/$(APP)
	$(CHECK_UNIVERSAL)
	# No Sparkle keys in the store build.
	sed $(PLIST_SUBST) Resources/Info.plist \
	  | plutil -remove SUFeedURL -o - - | plutil -remove SUPublicEDKey -o - - | plutil -remove SUEnableAutomaticChecks -o - - \
	  | plutil -remove SUScheduledCheckInterval -o - - | plutil -remove SUAutomaticallyUpdate -o - - > $(CONTENTS)/Info.plist
	@! otool -L $(CONTENTS)/MacOS/$(APP) | grep -q Sparkle || (echo "App Store binary must not link Sparkle"; exit 1)
	cp $(ICNS) $(CONTENTS)/Resources/AppIcon.icns
	cp -R $(APPSTORE_BUILD)/Keepit_Keepit.bundle $(CONTENTS)/Resources/
	cp Resources/Keepit.provisionprofile $(CONTENTS)/embedded.provisionprofile
	echo -n 'APPL????' > $(CONTENTS)/PkgInfo
	sed 's/__TEAM_ID__/$(TEAM_ID)/g' Resources/Keepit-AppStore.entitlements > .build/appstore.entitlements
	xattr -cr $(BUNDLE)          # App Store rejects com.apple.quarantine etc. inside the bundle
	codesign --force --deep --options runtime --timestamp --entitlements .build/appstore.entitlements --sign "$(APP_SIGN_ID)" $(BUNDLE)
	codesign --verify --strict --verbose=2 $(BUNDLE)
	codesign -d --entitlements - $(BUNDLE) | grep -q app-sandbox
	productbuild --component $(BUNDLE) /Applications --sign "$(PKG_SIGN_ID)" $(PKG)
	@echo "Built $(PKG) — upload with Transporter.app or: xcrun altool --upload-package (see RELEASING.md)"

# Re-render Resources/Icon/AppIcon.icns from icon.svg (needs python3 + playwright, or use iconutil on a Mac).
icon:
	python3 Resources/Icon/make_icns.py

dist: app dmg
	rm -f $(APP)-$(VERSION).zip $(DMG).sig SHA256SUMS
	ditto -c -k --keepParent $(BUNDLE) $(APP)-$(VERSION).zip
	@echo "Packaged $(APP)-$(VERSION).zip and $(DMG)"

build:
	swift build -c release $(ARCH_FLAGS)

app: build $(ICNS)
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD)/$(APP) $(CONTENTS)/MacOS/$(APP)
	$(CHECK_UNIVERSAL)
	sed $(PLIST_SUBST) -e 's|__SPARKLE_PUBLIC_KEY__|$(SPARKLE_PUBLIC_KEY)|' Resources/Info.plist > $(CONTENTS)/Info.plist
	cp $(ICNS) $(CONTENTS)/Resources/AppIcon.icns
	cp -R $(BUILD)/Keepit_Keepit.bundle $(CONTENTS)/Resources/      # localized strings (SwiftPM resource bundle)
	echo -n 'APPL????' > $(CONTENTS)/PkgInfo
	@test -n "$(SPARKLE_FW)" || (echo "Sparkle.framework not found under .build — run swift build first"; exit 1)
	mkdir -p $(CONTENTS)/Frameworks
	cp -R "$(SPARKLE_FW)" $(CONTENTS)/Frameworks/
	install_name_tool -add_rpath @executable_path/../Frameworks $(CONTENTS)/MacOS/$(APP) 2>/dev/null || true
	# Sparkle's nested helpers must be signed first (hardened runtime), then the framework, then the app.
	@if [ "$(SIGN_ID)" != "-" ]; then \
	  FW=$(CONTENTS)/Frameworks/Sparkle.framework/Versions/B; \
	  codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $$FW/XPCServices/*.xpc 2>/dev/null || true; \
	  codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $$FW/Autoupdate $$FW/Updater.app; \
	  codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $(CONTENTS)/Frameworks/Sparkle.framework; \
	fi
	@if [ -n "$(HAVE_PROFILE)" ]; then \
	  mkdir -p .build && sed 's/__TEAM_ID__/$(TEAM_ID)/g' Resources/Keepit.entitlements > .build/devid.entitlements; \
	  cp $(DEVID_PROFILE) $(CONTENTS)/embedded.provisionprofile; echo "Embedding Developer ID profile (Touch ID enabled)"; \
	else echo "No Developer ID profile at $(DEVID_PROFILE): Touch ID unlock disabled in this build"; fi
	xattr -cr $(BUNDLE)
	codesign --force --deep $(SIGN_FLAGS) --sign "$(SIGN_ID)" $(BUNDLE)
	codesign --verify --strict --verbose=2 $(BUNDLE)
	@echo "Built $(BUNDLE)"

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build .build-appstore $(BUNDLE) $(APP)-*.zip $(APP)-*.dmg $(APP)-*.pkg
