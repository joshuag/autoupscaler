#!/bin/bash

set -e
set -o pipefail

print_usage() {
  echo "Usage: $0 -i input.mp4 [-s scale] [-q quality] [--skip-frames] [--no-audio] [--output output.mp4]"
  echo ""
  echo "Options:"
  echo "  -i, --input         Path to input video file"
  echo "  -s, --scale         Scale factor: 1, 2, 4, 8, 16, or 32 (default: 2)"
  echo "  -q, --quality       Quality level: high, medium, low (default: high)"
  echo "      --skip-frames   Skip frame extraction and upscaling (just re-encode)"
  echo "      --no-audio      Skip audio extraction and merging"
  echo "  -o, --output        Output filename (default: video/<input>_upscaled.mp4)"
  exit 1
}

# Defaults
SCALE=2
QUALITY="high"
NOISE=2
MODEL="photo"
SKIP_FRAMES=false
NO_AUDIO=false

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -i|--input)
      VIDEO_INPUT="$2"
      shift 2
      ;;
    -s|--scale)
      SCALE="$2"
      shift 2
      ;;
    -q|--quality)
      QUALITY="$2"
      shift 2
      ;;
    -n|--noise)
      NOISE="$2"
      shift 2
      ;;
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    --skip-frames)
      SKIP_FRAMES=true
      shift
      ;;
    --no-audio)
      NO_AUDIO=true
      shift
      ;;
    -o|--output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -*|--*)
      echo "Unknown option $1"
      print_usage
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# For quick & dirty invocation with just a filename
if [[ -z "$VIDEO_INPUT" && ${#POSITIONAL[@]} -gt 0 ]]; then
  VIDEO_INPUT="${POSITIONAL[0]}"
fi

# Validate input
if [[ -z "$VIDEO_INPUT" || ! -f "$VIDEO_INPUT" ]]; then
  echo "❌ Error: Input file is missing or does not exist."
  print_usage
fi

if ! [[ "$SCALE" =~ ^(1|2|4|8|16|32)$ ]]; then
  echo "❌ Error: Scale must be one of 1, 2, 4, 8, 16, or 32"
  exit 1
fi

if ! [[ "$NOISE" =~ ^(-1|0|1|2|3)$ ]]; then
  echo "❌ Error: Noise must be one of -1, 0, 1, 2, or 3"
  exit 1
fi

case "$MODEL" in
  photo) MODEL_PATH=models-upconv_7_photo ;;
  anime) MODEL_PATH=models-upconv_7_anime_style_art_rgb ;;
  2d)    MODEL_PATH=models-cunet ;;
  *) echo "❌ Error: Model must be 'photo', 'anime', or '2d'" ; exit 1 ;;
esac

case "$QUALITY" in
  high)   CRF=16 ;;
  medium) CRF=23 ;;
  low)    CRF=30 ;;
  *) echo "❌ Error: Quality must be 'high', 'medium', or 'low'" ; exit 1 ;;
esac

BASENAME=$(basename "$VIDEO_INPUT")
NAME="${BASENAME%.*}"
OUTPUT_PATH="${OUTPUT_PATH:-video/${NAME}_upscaled.mp4}"

mkdir -p frames scaled video

# Accurate fractional frame rate
echo "🔍 Extracting frame rate..."
FRAMERATE=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=avg_frame_rate \
  -of default=noprint_wrappers=1:nokey=1 "$VIDEO_INPUT")
echo "🎞️  Frame rate: $FRAMERATE"

# Detect audio codec
if ! $NO_AUDIO; then
  echo "🔍 Detecting audio codec..."
  AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO_INPUT")
  case "$AUDIO_CODEC" in
    aac) AUDIO_EXT="aac" ;;
    mp3) AUDIO_EXT="mp3" ;;
    ac3) AUDIO_EXT="ac3" ;;
    opus) AUDIO_EXT="opus" ;;
    *) AUDIO_EXT="m4a" ;;
  esac
  AUDIO_OUTPUT="video/audio.$AUDIO_EXT"
fi

if ! $SKIP_FRAMES; then
  echo "📸 Extracting frames..."
  ffmpeg -i "$VIDEO_INPUT" frames/frame%06d.png
fi

if ! $NO_AUDIO; then
  echo "🔊 Extracting audio to $AUDIO_OUTPUT"
  ffmpeg -y -i "$VIDEO_INPUT" -vn -acodec copy "$AUDIO_OUTPUT"
fi

if ! $SKIP_FRAMES; then
  echo "⚙️  Determining optimal waifu2x thread configuration..."
  if [[ "$(uname -m)" == "arm64" && "$(uname)" == "Darwin" ]]; then
    SYS_RAM_GB=$(sysctl -n hw.memsize | awk '{print int($1 / 1024 / 1024 / 1024)}')
    if (( SYS_RAM_GB >= 64 )); then
      echo "🍎 M1 Ultra + ${SYS_RAM_GB}GB RAM detected — max performance mode"
      WAIFU_THREADS="6:12:4"
    else
      echo "🍎 Apple Silicon detected — safe mode"
      WAIFU_THREADS="4:6:2"
    fi
  else
    CORES=$(nproc)
    if [ "$CORES" -le 4 ]; then
      WAIFU_THREADS="1:2:1"
    elif [ "$CORES" -le 8 ]; then
      WAIFU_THREADS="2:4:2"
    else
      WAIFU_THREADS="4:8:4"
    fi
  fi

  echo "✨ Upscaling frames using: -j $WAIFU_THREADS"
  ./waifu2x/waifu2x-ncnn-vulkan -i frames/ -o scaled/ -n "$NOISE" -s "$SCALE" -j "$WAIFU_THREADS" -m "$MODEL_PATH"
fi

echo "🎬 Reassembling video..."
if $NO_AUDIO; then
  ffmpeg -y \
    -f image2 -framerate "$FRAMERATE" -i scaled/frame%06d.png \
    -c:v libx264 -crf "$CRF" -pix_fmt yuv420p \
    -shortest \
    -r "$FRAMERATE" \
    "$OUTPUT_PATH"
else
  ffmpeg -y \
    -f image2 -framerate "$FRAMERATE" -i scaled/frame%06d.png \
    -i "$AUDIO_OUTPUT" \
    -c:v libx264 -crf "$CRF" -pix_fmt yuv420p \
    -c:a copy \
    -shortest \
    -r "$FRAMERATE" \
    "$OUTPUT_PATH"
fi

echo "🧹 Cleaning up..."
if ! $SKIP_FRAMES; then
  rm -rf frames scaled
fi
rm -f scaled/test.png 2>/dev/null || true

echo "✅ Done! Output saved as: $OUTPUT_PATH"