APP      = Keepit
VERSION ?= $(shell cat VERSION)
BUILD_NO ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
BUILD    = .build/release
BUNDLE   = $(APP).app
CONTENTS = $(BUNDLE)/Contents
# Ad-hoc signature by default. See README "Accessibility permission resets after rebuild".
# For distribution: SIGN_ID="Developer ID Application: Name (TEAMID)" — adds hardened runtime + timestamp.
SIGN_ID ?= -
ifeq ($(SIGN_ID),-)
SIGN_FLAGS =
else
SIGN_FLAGS = --options runtime --timestamp --entitlements Resources/Keepit.entitlements
endif
# Notarization: NOTARY_PROFILE (xcrun notarytool store-credentials) or the APPSTORE_* env vars used by CI.
NOTARY_PROFILE ?=

.PHONY: build app run install clean dist dmg icon notarize

DMG      = $(APP)-$(VERSION).dmg
DMG_VOL  = Keep it
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
	xcrun stapler staple $(DMG)
	xcrun stapler staple $(BUNDLE)
	spctl -a -vv -t install $(DMG)
	@echo "Notarized and stapled $(DMG)"

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
