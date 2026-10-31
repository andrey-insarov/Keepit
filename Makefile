APP      = Keepit
VERSION ?= $(shell cat VERSION)
BUILD_NO ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
BUILD    = .build/release
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
# Notarization: NOTARY_PROFILE (xcrun notarytool store-credentials) or the APPSTORE_* env vars used by CI.
NOTARY_PROFILE ?=

.PHONY: build app run install clean dist dmg icon notarize appstore

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

appstore: build
	@test -n "$(APP_SIGN_ID)" -a -n "$(PKG_SIGN_ID)" -a -n "$(TEAM_ID)" || (echo "set APP_SIGN_ID, PKG_SIGN_ID and TEAM_ID"; exit 1)
	@test -f Resources/Keepit.provisionprofile || (echo "missing Resources/Keepit.provisionprofile (Mac App Store profile for com.it.keep)"; exit 1)
	rm -rf $(BUNDLE) $(PKG) .build/appstore.entitlements
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD)/$(APP) $(CONTENTS)/MacOS/$(APP)
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD_NO)/' Resources/Info.plist > $(CONTENTS)/Info.plist
	cp Resources/Icon/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	cp Resources/Keepit.provisionprofile $(CONTENTS)/embedded.provisionprofile
	echo -n 'APPL????' > $(CONTENTS)/PkgInfo
	sed 's/__TEAM_ID__/$(TEAM_ID)/g' Resources/Keepit-AppStore.entitlements > .build/appstore.entitlements
	codesign --force --deep --options runtime --timestamp --entitlements .build/appstore.entitlements --sign "$(APP_SIGN_ID)" $(BUNDLE)
	codesign --verify --strict --verbose=2 $(BUNDLE)
	codesign -d --entitlements - $(BUNDLE) | grep -q app-sandbox
	productbuild --component $(BUNDLE) /Applications --sign "$(PKG_SIGN_ID)" $(PKG)
	@echo "Built $(PKG) — upload with Transporter.app or: xcrun altool --upload-package (see RELEASING.md)"

# Re-render Resources/Icon/AppIcon.icns from icon.svg (needs python3 + playwright, or use iconutil on a Mac).
icon:
	python3 Resources/Icon/make_icns.py

dist: app dmg
	rm -f $(APP)-$(VERSION).zip
	ditto -c -k --keepParent $(BUNDLE) $(APP)-$(VERSION).zip
	@echo "Packaged $(APP)-$(VERSION).zip and $(DMG)"

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD)/$(APP) $(CONTENTS)/MacOS/$(APP)
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD_NO)/' Resources/Info.plist > $(CONTENTS)/Info.plist
	cp Resources/Icon/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	echo -n 'APPL????' > $(CONTENTS)/PkgInfo
	@if [ -n "$(HAVE_PROFILE)" ]; then \
	  mkdir -p .build && sed 's/__TEAM_ID__/$(TEAM_ID)/g' Resources/Keepit.entitlements > .build/devid.entitlements; \
	  cp $(DEVID_PROFILE) $(CONTENTS)/embedded.provisionprofile; echo "Embedding Developer ID profile (Touch ID enabled)"; \
	else echo "No Developer ID profile at $(DEVID_PROFILE): Touch ID unlock disabled in this build"; fi
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
	rm -rf .build $(BUNDLE) $(APP)-*.zip $(APP)-*.dmg
