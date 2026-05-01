#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 1.1.0"
    exit 1
fi

NEW_VERSION="$1"
REPO_ROOT="$(git rev-parse --show-toplevel)"
VERSION_FILE="$REPO_ROOT/android/app/build.gradle.kts"

CURRENT_VERSION=$(grep 'versionName' "$VERSION_FILE" | head -1 | sed 's/.*versionName = "\(.*\)".*/\1/')
CURRENT_CODE=$(grep 'versionCode' "$VERSION_FILE" | head -1 | sed 's/.*versionCode = \(.*\)/\1/')

IFS='.' read -ra PARTS <<< "$NEW_VERSION"
MAJOR="${PARTS[0]:-0}"
MINOR="${PARTS[1]:-0}"
PATCH="${PARTS[2]:-0}"
NEW_CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))

echo "Current: v${CURRENT_VERSION} (code ${CURRENT_CODE})"
echo "New:     v${NEW_VERSION} (code ${NEW_CODE})"

sed -i "s/versionCode = ${CURRENT_CODE}/versionCode = ${NEW_CODE}/" "$VERSION_FILE"
sed -i "s/versionName = \"${CURRENT_VERSION}\"/versionName = \"${NEW_VERSION}\"/" "$VERSION_FILE"

echo "Building release APK..."
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

cd "$REPO_ROOT/android"
./gradlew assembleRelease 2>&1 | tail -5

APK_NAME="aios-${NEW_VERSION}.apk"
cp "app/build/outputs/apk/release/app-release.apk" "/tmp/$APK_NAME"

cd "$REPO_ROOT"

git add "$VERSION_FILE"
git commit -m "release: v${NEW_VERSION}" || true
git tag "v${NEW_VERSION}"

echo "Pushing to origin..."
git push origin master
git push origin "v${NEW_VERSION}"

echo "Creating GitHub Release..."
gh release create "v${NEW_VERSION}" "/tmp/$APK_NAME" \
    --title "AIOS v${NEW_VERSION}" \
    --notes "## AIOS v${NEW_VERSION}

### Install
1. Download \`${APK_NAME}\`
2. Open on your Android device
3. Allow installation when prompted"

echo "Release v${NEW_VERSION} created successfully!"
echo "https://github.com/dev-hann/aios/releases/tag/v${NEW_VERSION}"
