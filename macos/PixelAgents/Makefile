.PHONY: build install test clean open

build:
	xcodegen generate
	xcodebuild -project PixelAgents.xcodeproj -scheme PixelAgents -configuration Release -derivedDataPath .build

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
