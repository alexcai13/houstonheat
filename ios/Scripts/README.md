# iOS Mapbox Token Setup

This folder contains a script to securely load the Mapbox access token from `.env` during build time.

## How It Works

1. The `load-env.sh` script reads `MAPBOX_ACCESS_TOKEN` from your `.env` file
2. It exports the token as an environment variable
3. Xcode uses this variable to replace `$(MAPBOX_ACCESS_TOKEN)` in `Info.plist`

## Setup (One-Time)

You need to add this script to your Xcode project's build phases:

### Option 1: Via Xcode GUI

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project in the left panel
3. Select the **Runner** target
4. Go to **Build Phases** tab
5. Click the **+** button and select **New Run Script Phase**
6. Drag the new script phase to be **before** "Compile Sources"
7. In the script box, paste:
   ```bash
   source "${SRCROOT}/Scripts/load-env.sh"
   ```
8. Check **"Based on dependency analysis"**

### Option 2: Flutter Run (Automatic)

The token will be automatically loaded when you run:
```bash
flutter run
```

## Verification

After setup, you can verify it works by building in Xcode. Check the build log for:
```
✅ Mapbox token loaded from .env
```

## Troubleshooting

### "MAPBOX_ACCESS_TOKEN not found"
- Make sure `.env` exists in the project root (not in the ios folder)
- Check that `.env` contains: `MAPBOX_ACCESS_TOKEN=pk.your_token_here`

### Token not replaced in Info.plist
- Make sure the build script runs **before** "Compile Sources"
- Clean build folder (Product → Clean Build Folder in Xcode)

## Security

✅ The actual token is never committed to git (it's in `.env` which is gitignored)  
✅ Info.plist only contains the placeholder `$(MAPBOX_ACCESS_TOKEN)`  
✅ Each developer uses their own token from their local `.env` file
