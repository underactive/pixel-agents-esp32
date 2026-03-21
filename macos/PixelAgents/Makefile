.PHONY: build sign install test clean open

build:
	xcodegen generate
	xcodebuild -project PixelAgents.xcodeproj -scheme PixelAgents -configuration Release -derivedDataPath .build

sign:
	@if [ -z "$(TEAM_ID)" ]; then echo "Usage: make sign TEAM_ID=XXXXXXXXXX"; exit 1; fi
	xcodegen generate
	xcodebuild -project PixelAgents.xcodeproj -scheme PixelAgents -configuration Release -derivedDataPath .build \
		CODE_SIGN_STYLE=Manual \
		"CODE_SIGN_IDENTITY=Developer ID Application" \
		"DEVELOPMENT_TEAM=$(TEAM_ID)"

install: build
	cp -R .build/Build/Products/Release/PixelAgents.app /Applications/

test:
	xcodegen generate
	xcodebuild test -project PixelAgents.xcodeproj -scheme PixelAgents -configuration Debug -derivedDataPath .build

clean:
	rm -rf .build

open:
	xcodegen generate
	open PixelAgents.xcodeproj
