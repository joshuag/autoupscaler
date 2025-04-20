#!/bin/bash

set -e

PLATFORM="$(uname)"
ARCH="$(uname -m)"
TMPDIR=$(mktemp -d)
API_URL="https://api.github.com/repos/nihui/waifu2x-ncnn-vulkan/releases/latest"

echo "📦 Installing dependencies..."

if [[ "$PLATFORM" == "Darwin" ]]; then
    echo "🍎 Detected macOS"
    if ! command -v brew &> /dev/null; then
        echo "🍺 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install ffmpeg git
elif [[ "$PLATFORM" == "Linux" ]]; then
    echo "🐧 Detected Linux"
    sudo apt update
    sudo apt install -y ffmpeg git curl unzip jq
else
    echo "❌ Unsupported platform: $PLATFORM"
    exit 1
fi

echo "🔍 Fetching latest release tag from GitHub..."
LATEST_TAG=$(curl -s $API_URL | jq -r .tag_name)

if [[ "$LATEST_TAG" == "null" || -z "$LATEST_TAG" ]]; then
    echo "❌ Failed to get latest release tag."
    exit 1
fi

echo "📦 Latest release tag is: $LATEST_TAG"

# Determine the correct file to download
if [[ "$PLATFORM" == "Darwin" ]]; then
    FILENAME="waifu2x-ncnn-vulkan-${LATEST_TAG}-macos.zip"
elif [[ "$PLATFORM" == "Linux" && "$ARCH" == "x86_64" ]]; then
    FILENAME="waifu2x-ncnn-vulkan-${LATEST_TAG}-ubuntu.zip"
else
    echo "❌ Unsupported platform or architecture: $PLATFORM $ARCH"
    exit 1
fi

DOWNLOAD_URL="https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/${LATEST_TAG}/${FILENAME}"

echo "⬇️ Downloading $FILENAME from $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$TMPDIR/waifu2x.zip"
unzip -o "$TMPDIR/waifu2x.zip" -d "$TMPDIR"

INSTALL_DIR="./waifu2x" #IF YOU CHANGE THIS, UPDATE UPSCALE.SH

echo "📂 Locating waifu2x extracted folder..."
EXTRACTED_DIR=$(find "$TMPDIR" -type d -name "waifu2x-ncnn-vulkan*" -maxdepth 1)

if [[ -z "$EXTRACTED_DIR" || ! -d "$EXTRACTED_DIR" ]]; then
  echo "❌ Failed to find extracted waifu2x directory"
  exit 1
fi

echo "📁 Installing waifu2x into: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "$EXTRACTED_DIR/"* "$INSTALL_DIR/"

# Optional: quarantine removal
if [[ "$(uname)" == "Darwin" ]]; then
  echo "🛡 Removing macOS quarantine flags from waifu2x binaries..."
  xattr -dr com.apple.quarantine "$INSTALL_DIR"
fi

echo "✅ waifu2x-ncnn-vulkan installed to $INSTALL_DIR"