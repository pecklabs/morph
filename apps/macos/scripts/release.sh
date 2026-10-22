#!/usr/bin/env bash
#
# Build, sign, (optionally) notarize, and publish a Morph update via GitHub Releases + Sparkle.
#
# Each run:
#   1. builds Release and zips Morph.app
#   2. creates/updates GitHub release  v<version>  on pecklabs/morph and uploads the zip
#   3. regenerates appcast.xml (signed with your Sparkle key) pointing at that asset
#   4. commits appcast.xml to the repo's  main  branch (that is the SUFeedURL)
#
# Usage:
#   ./scripts/release.sh               # build + publish (no notarization)
#   NOTARIZE=1 ./scripts/release.sh    # also notarize + staple (needs a notarytool profile)
#
# Prerequisites:
#   - gh logged in with push access to pecklabs/morph
#   - Developer ID Application cert + Sparkle EdDSA private key in the login keychain
#   - For notarization: xcrun notarytool store-credentials "$NOTARY_PROFILE" done once

set -euo pipefail
cd "$(dirname "$0")/.."                       # apps/macos

REPO="pecklabs/morph"
BRANCH="main"
SCHEME="Morph"
BUILD_DIR="$(pwd)/build"
DIST_DIR="$(pwd)/dist"
SPARKLE_BIN="$(pwd)/scripts/sparkle-bin"
NOTARY_PROFILE="${NOTARY_PROFILE:-morph-notary}"

rm -rf "$BUILD_DIR"; mkdir -p "$DIST_DIR"

echo "▸ Building Release…"
xcodebuild -project Morph.xcodeproj -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$BUILD_DIR/spm" \
  build | tail -3

APP="$BUILD_DIR/Build/Products/Release/Morph.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
TAG="v$VERSION"
ZIP="$DIST_DIR/Morph-$VERSION.zip"

echo "▸ Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  echo "▸ Notarizing…"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
fi

echo "▸ Zipping → $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Creating/updating GitHub release $TAG and uploading asset…"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP" --repo "$REPO" --clobber
else
  gh release create "$TAG" "$ZIP" --repo "$REPO" --title "Morph $VERSION" --notes "Morph $VERSION"
fi

echo "▸ Generating + signing appcast…"
# Pull the current appcast so generate_appcast appends rather than starting fresh.
gh api "repos/$REPO/contents/appcast.xml?ref=$BRANCH" -q '.content' 2>/dev/null \
  | base64 --decode > "$DIST_DIR/appcast.xml" || true
"$SPARKLE_BIN/generate_appcast" "$DIST_DIR" \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/"

echo "▸ Committing appcast.xml to $REPO@$BRANCH…"
SHA="$(gh api "repos/$REPO/contents/appcast.xml?ref=$BRANCH" -q '.sha' 2>/dev/null || true)"
gh api -X PUT "repos/$REPO/contents/appcast.xml" \
  -f message="Publish Morph $VERSION appcast" \
  -f branch="$BRANCH" \
  -f content="$(base64 -i "$DIST_DIR/appcast.xml")" \
  ${SHA:+-f sha="$SHA"} >/dev/null

echo
echo "✅ Published Morph $VERSION."
echo "   Release asset: https://github.com/$REPO/releases/tag/$TAG"
echo "   Feed:          https://raw.githubusercontent.com/$REPO/$BRANCH/appcast.xml"
