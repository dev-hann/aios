# Build Guide

Detailed instructions for building AIOS from source.

## Prerequisites

### Required

| Tool | Version | Notes |
|------|---------|-------|
| Android Studio | Latest stable | Hedgehog or newer recommended |
| JDK | 17+ | Bundled with Android Studio |
| Android SDK | API 35 | Install via SDK Manager |
| Android NDK | 27.2+ | Install via SDK Manager → SDK Tools tab |
| CMake | 3.22.1+ | Install via SDK Manager → SDK Tools tab |
| Git | 2.0+ | With submodule support |
| Physical Android device | arm64-v8a | API 26+ (Android 8.0+) |

### Optional

| Tool | Purpose |
|------|---------|
| adb | Command-line install/debug |
| llmodel files | GGUF quantized models for testing |

## Step-by-Step Build

### 1. Clone Repository

```bash
git clone https://github.com/hann/aios.git
cd aios

# Initialize llama.cpp submodule
git submodule update --init --recursive
```

### 2. Open in Android Studio

1. Open Android Studio
2. Select **Open an Existing Project**
3. Navigate to the `android/` directory (not the project root)
4. Wait for Gradle sync to complete

### 3. Install SDK Components

If prompted, install:
- Android SDK Platform 35
- Android NDK 27.2+
- CMake

You can also install manually via **Tools → SDK Manager**:
- **SDK Platforms** tab: Android 15.0 (API 35)
- **SDK Tools** tab: NDK (Side by side), CMake, Android SDK Build-Tools

### 4. Build

#### Debug Build (Android Studio)

1. Select **app** module and your device
2. Click **Run** (green play button) or `Shift+F10`

#### Command-Line Build

```bash
# From the android/ directory
cd android

# Debug APK
./gradlew assembleDebug

# Release APK (requires signing configuration)
./gradlew assembleRelease
```

Output APKs are in `android/app/build/outputs/apk/`.

### 5. Install on Device

```bash
# Via Gradle
cd android
./gradlew installDebug

# Via adb
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Model Setup

AIOS requires GGUF model files to run inference.

### Getting Models

Download quantized GGUF models from:
- [Hugging Face](https://huggingface.co/models?search=gguf)
- Recommended: **Q4_K_M** or **Q5_K_M** quantization for mobile

Recommended models for on-device use:

| Model | Size | Parameters | Notes |
|-------|------|-----------|-------|
| Qwen2.5-3B-Instruct | ~2GB | 3B | Good balance of speed and quality |
| Llama-3.2-3B-Instruct | ~2GB | 3B | General purpose |
| Mistral-7B-Instruct | ~4GB | 7B | Higher quality, slower |
| Phi-3-mini-4k | ~2.5GB | 3.8B | Microsoft, strong reasoning |

### Loading Models

Place the `.gguf` file on your device:

**Option A: Download folder (recommended)**
```bash
adb push model.gguf /sdcard/Download/
```

**Option B: App internal storage**
```bash
adb push model.gguf /sdcard/Android/data/com.agent.aios/files/models/
```

Then select the model from the model picker in the app.

## Native Build (C++)

The C++ layer builds automatically via CMake as part of the Gradle build. No separate build step is needed.

### Standalone Native Tests

To build and run native tests without the Android app:

```bash
cd native/tests
mkdir build && cd build
cmake .. -DLLAMA_CPP_DIR=../../native/llama.cpp
make
./test_inference
```

### CMake Configuration

The native build is configured in `android/app/src/main/cpp/CMakeLists.txt`:

- Builds `libaios-native.so` shared library
- Links against llama.cpp static library
- Compiles for `arm64-v8a` only
- Enables C++17

## Troubleshooting

### Gradle Sync Fails

- Ensure NDK is installed via SDK Manager
- Check that `local.properties` has the correct `sdk.dir`
- Run `./gradlew clean` and re-sync

### NDK Not Found

```bash
# Set NDK version in android/app/build.gradle.kts
# android { ndkVersion = "27.2.12479018" }
```

### CMake Build Errors

- Ensure CMake is installed via SDK Manager
- Check that `native/llama.cpp/` submodule is initialized:
  ```bash
  git submodule update --init --recursive
  ```

### Model Not Loading

- Verify the GGUF file is valid and not corrupted
- Check that the model fits in available RAM
- Ensure the file path is accessible to the app

### Out of Memory

- Use a smaller model (3B instead of 7B)
- Use a more aggressive quantization (Q4_K_M instead of Q8)
- Close other apps before running inference

## Build Configuration

### Build Variants

| Variant | Debuggable | Signing | Use Case |
|---------|-----------|---------|----------|
| `debug` | Yes | Debug key | Development |
| `release` | No | Configured keystore | Distribution |

### Release Signing

To create a release build, configure signing in `android/app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = "your-password"
            keyAlias = "your-alias"
            keyPassword = "your-password"
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```
