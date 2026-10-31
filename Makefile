APP      = Keepit
VERSION ?= $(shell cat VERSION)
BUILD_NO ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
BUILD    = .build/release
BUNDLE   = $(APP).app
CONTENTS = $(BUNDLE)/Contents
# Ad-hoc signature by default. See README "Accessibility permission resets after rebuild".
SIGN_ID ?= -

.PHONY: build app run install clean dist

dist: app
	rm -f $(APP)-$(VERSION).zip
	ditto -c -k --keepParent $(BUNDLE) $(APP)-$(VERSION).zip
	@echo "Packaged $(APP)-$(VERSION).zip"

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD)/$(APP) $(CONTENTS)/MacOS/$(APP)
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD_NO)/' Resources/Info.plist > $(CONTENTS)/Info.plist
	echo -n 'APPL????' > $(CONTENTS)/PkgInfo
	codesign --force --deep --sign "$(SIGN_ID)" $(BUNDLE)
	@echo "Built $(BUNDLE)"

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build $(BUNDLE)
