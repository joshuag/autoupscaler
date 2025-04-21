# 🎥 Video Upscaling Automation Script

This project automates the process of extracting video frames, upscaling them using `waifu2x-ncnn-vulkan`, and recombining them with the original audio.

Built for **macOS** and **Linux**, optimized for M1/M2 Macs and modern GPUs with Vulkan support. Might work on Windows with WSL, but I'll never know.

---

## 🔧 Requirements

- macOS or Linux (x86_64 or Apple Silicon)
- Vulkan-compatible GPU
- `ffmpeg` (installed automatically by the installer)
- `waifu2x-ncnn-vulkan` precompiled binary
- A shedload of disk space. The average DVD is going to take ~300GB while it is being upscaled

---

## 📦 Installation

```bash
chmod +x install.sh
./install.sh
```

This will:
- Install dependencies (`ffmpeg`, `git`)
- Download the latest waifu2x-ncnn-vulkan release
- Extract and move binaries to the working directory
- On macOS, remove the quarantine attribute to bypass Gatekeeper prompts

---

## 🔐 macOS Security Note

macOS may initially block the waifu2x binary from running. You may see:

> “waifu2x-ncnn-vulkan” cannot be opened because the developer cannot be verified.

Do one of the following:

**Option 1: GUI**
1. Open **System Settings → Security & Privacy → General**
2. Click **“Allow Anyway”**
3. Retry the command

**Option 2: Automatic**
The installer clears the quarantine flag using:

```bash
xattr -dr com.apple.quarantine waifu2x-ncnn-vulkan*
```

---

## ▶️ Usage

```bash
./upscale_video.sh -i input.mp4 [options]
```

### 🔢 Options

| Flag              | Description                                                                                | Default                 |
|-------------------|--------------------------------------------------------------------------------------------|-------------------------|
| `-i`, `--input`   | Path to the input video file                                                               | **Required**            |
| `-s`, `--scale`   | Scale factor (1, 2, 4, 8, 16, 32)                                                          | `2`                     |
| `-q`, `--quality` | Encoding quality: `high`, `medium`, `low`                                                  | `high`                  |
| `-n`, `--noise`   | Denoise Level: `-1/0/1/2/3`                                                                | `2`                     |
| `--skip-frames`   | Skip frame extraction/upscaling (just re-encode with audio pre-existing frames)            | `false`                 |
| `--no-audio`      | Skip audio extraction & remux (video only)                                                 | `false`                 |
| `-o`, `--output`  | Output file path                                                                           | `video/<input>_upscaled.mp4` |

### 🧪 Example

```bash
./upscale_video.sh -i input.mp4 -s 2 -q medium -n 0 --output 4k-output.mp4
```

---


## 📝 Notes

- Upscaling is GPU and memory-intensive. The script auto-tunes performance based on your CPU/GPU.
- Apple Silicon support via [MoltenVK](https://github.com/KhronosGroup/MoltenVK) is automatically used under-the-hood.
- Audio codec is preserved via stream copy when possible (`-c:a copy`).

---

## 🧹 Cleanup

The script automatically deletes intermediate frame folders (`frames/`, `scaled/`) after encoding, unless `--skip-frames` is passed.

---

## 💬 Questions?

This repo is offered without any implied support. If you're stuck, feel free to open an issue, but any assistance will be on a best-effort basis.
