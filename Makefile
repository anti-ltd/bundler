APP_NAME    = Bundler
BUNDLE      = build/$(APP_NAME).app
BIN         = .build/release/$(APP_NAME)
ENTITLEMENTS = Resources/Bundler.entitlements
ICONSET     = Resources/AppIcon.iconset
ICNS        = Resources/AppIcon.icns
SVG         = assets/icon.svg

SIGN_ID := $(shell security find-certificate -c "Bundler Dev" >/dev/null 2>&1 && echo "Bundler Dev" || echo -)

.PHONY: all build app icon run clean

all: app

build:
	swift build -c release

icon:
	@mkdir -p $(ICONSET)
	@for size in 16 32 64 128 256 512 1024; do \
		swift /tmp/svg2png.swift $(SVG) $(ICONSET)/icon_$${size}x$${size}.png $$size; \
	done
	@cd $(ICONSET) && \
		cp icon_32x32.png   "icon_16x16@2x.png"  && \
		cp icon_64x64.png   "icon_32x32@2x.png"  && \
		cp icon_256x256.png "icon_128x128@2x.png" && \
		cp icon_512x512.png "icon_256x256@2x.png" && \
		cp icon_1024x1024.png "icon_512x512@2x.png" && \
		rm -f icon_64x64.png icon_1024x1024.png
	@if command -v pngquant >/dev/null 2>&1; then \
		for f in $(ICONSET)/*.png; do \
			pngquant --quality=90-100 --speed 1 --force --output "$$f" "$$f" || true; \
		done; \
	fi
	@if command -v optipng >/dev/null 2>&1; then \
		optipng -quiet -o7 $(ICONSET)/*.png; \
	fi
	@iconutil -c icns $(ICONSET) -o $(ICNS)
	@echo "→ $(ICNS)"

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	strip $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	@if [ -f $(ICNS) ]; then cp $(ICNS) $(BUNDLE)/Contents/Resources/AppIcon.icns; fi
	codesign --force --deep --sign "$(SIGN_ID)" --entitlements $(ENTITLEMENTS) $(BUNDLE)
	@echo "Built $(BUNDLE) (signed: $(SIGN_ID))"

run: app
	open $(BUNDLE)

clean:
	rm -rf .build build
