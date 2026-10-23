# Keepsy

An iPhone app for keeping track of what's at home and when it runs out: fridge, pantry, bathroom, anywhere.

- Every item counts down to its expiration date, soonest first.
- Scan the date on a package with the camera.
- Swipe when you use something up or buy it again; Keepsy remembers where it goes and how long it lasts.
- A shopping list that suggests what ran out and what you usually buy around now.
- One reminder a day with what expires soon.

Built with SwiftUI and Core Data, iOS 18+. Korean and English.

## Develop

Open `Keepsy.xcodeproj` in Xcode 26 and run the `Keepsy` scheme. In debug builds, launch with `-sampleData` to start with example items.

Run tests:

```sh
xcodebuild test -project Keepsy.xcodeproj -scheme Keepsy -destination 'platform=iOS Simulator,name=iPhone 16'
```

- `design/AppIcon.svg`: app icon source
- `docs/`: privacy policy, published with GitHub Pages
- `store/AppStore.md`: App Store listing drafts
