# Ripple (iOS + watchOS)

Native iOS app + Apple Watch companion for the [ripple](https://github.com/jayvee6/ripple) breathing tool. Metal-rendered water, CoreHaptics-driven breath cues, singing-bowl audio, and a watch app that runs standalone or pairs with the phone session.

## Status

Phase 0: scaffolded.

## Project structure

```
ripple-apple/
├── project.yml                 ← xcodegen
├── Packages/RippleCore/        ← shared Swift package (iOS + watchOS)
├── Ripple/                     ← iOS target
└── RippleWatch/                ← watchOS target
```

## Build

Requires Xcode 26+ and `xcodegen` (`brew install xcodegen`).

```bash
xcodegen generate
open Ripple.xcodeproj
```

Or from the CLI:

```bash
xcodebuild -scheme Ripple -destination "platform=iOS Simulator,name=iPhone 17 Pro"
xcodebuild -scheme RippleWatch -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"
```

## Tests

```bash
swift test --package-path Packages/RippleCore
```

## License

MIT.
