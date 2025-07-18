# PrepperApp Development Setup Guide

## Overview
This guide walks through setting up the development environment for PrepperApp on macOS, Windows, and Linux. The setup includes native iOS/Android development tools, Rust toolchain for Tantivy, and content pipeline tools.

## Prerequisites

### System Requirements
- **macOS**: 10.15+ (iOS development)
- **Windows**: Windows 10 version 2004+ (Android only)
- **Linux**: Ubuntu 20.04+ or equivalent (Android only)
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 50GB free space minimum
- **CPU**: Intel i5/AMD Ryzen 5 or better

### Required Software
- Git 2.30+
- Node.js 18+ and npm 8+
- Python 3.9+ (content pipeline)
- Docker 20+ (optional, for CI testing)

## Platform-Specific Setup

### macOS Development Setup

#### 1. Install Xcode
```bash
# Install Xcode from App Store or:
xcode-select --install

# Accept license
sudo xcodebuild -license accept

# Install additional components
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

#### 2. Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 3. Install Development Tools
```bash
# Core tools
brew install git node python@3.9 watchman cocoapods

# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustup target add aarch64-apple-ios x86_64-apple-ios

# Android tools (for macOS Android development)
brew install --cask android-studio java11
```

### Windows Development Setup

#### 1. Install WSL2 (Recommended)
```powershell
# Run as Administrator
wsl --install
wsl --set-default-version 2
```

#### 2. Install Development Tools
```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install tools
choco install git nodejs python rust android-studio
```

### Linux Development Setup

#### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

#### 2. Install Development Tools
```bash
# Core dependencies
sudo apt install -y git curl build-essential pkg-config libssl-dev

# Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Python
sudo apt install -y python3.9 python3-pip python3-venv

# Android Studio
sudo snap install android-studio --classic
```

## Project Setup

### 1. Clone Repository
```bash
git clone https://github.com/prepperapp/prepperapp.git
cd prepperapp
```

### 2. Install Dependencies

#### iOS Dependencies
```bash
cd ios
pod install
cd ..
```

#### Android Dependencies
```bash
cd android
./gradlew build
cd ..
```

#### Rust Dependencies (Tantivy)
```bash
cd rust/tantivy-mobile
cargo build --release
cargo lipo --release  # iOS universal binary
cd ../..
```

#### Node Dependencies (Content Pipeline)
```bash
cd content-pipeline
npm install
cd ..
```

### 3. Environment Configuration

#### Create `.env` file
```bash
cp .env.example .env
```

#### Edit `.env` with your settings:
```env
# Development
NODE_ENV=development
DEBUG=true

# API Keys (for content sources)
WIKIPEDIA_API_KEY=your_key_here
OPENSTREETMAP_KEY=your_key_here

# Build Configuration
IOS_TEAM_ID=your_team_id
ANDROID_KEYSTORE_PASSWORD=your_password

# Content Pipeline
CONTENT_SOURCE_DIR=./content/raw
CONTENT_OUTPUT_DIR=./content/processed
COMPRESSION_LEVEL=19
```

## IDE Setup

### VS Code (Recommended)

#### 1. Install VS Code
```bash
# macOS
brew install --cask visual-studio-code

# Linux
sudo snap install code --classic

# Windows
choco install vscode
```

#### 2. Install Extensions
```bash
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension rust-lang.rust-analyzer
code --install-extension vadimcn.vscode-lldb
code --install-extension vscjava.vscode-java-pack
code --install-extension msjsdiag.vscode-react-native
```

#### 3. Workspace Settings
Create `.vscode/settings.json`:
```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "rust-analyzer.cargo.features": ["mobile"],
  "java.configuration.runtimes": [
    {
      "name": "JavaSE-11",
      "path": "/path/to/java11"
    }
  ]
}
```

### Xcode Setup (iOS)

#### 1. Configure Signing
1. Open `ios/PrepperApp.xcworkspace`
2. Select PrepperApp target
3. Go to Signing & Capabilities
4. Select your team
5. Enable automatic signing

#### 2. Configure Build Settings
- Set minimum iOS version to 13.0
- Enable bitcode: No
- Add Rust library search paths

### Android Studio Setup

#### 1. Import Project
1. Open Android Studio
2. Import `android/` directory
3. Sync Gradle files

#### 2. Configure SDK
- Install SDK 29-33
- Install NDK 25.0+
- Configure Rust toolchain path

## Build & Run

### iOS Development Build
```bash
# Build Rust library
cd rust/tantivy-mobile
./build-ios.sh

# Run iOS app
cd ../../ios
pod install
open PrepperApp.xcworkspace
# Then build and run in Xcode
```

### Android Development Build
```bash
# Build Rust library
cd rust/tantivy-mobile
./build-android.sh

# Run Android app
cd ../../android
./gradlew assembleDebug
./gradlew installDebug
# Or run from Android Studio
```

### Content Pipeline Build
```bash
cd content-pipeline
npm run build:content
npm run compress:content
npm run generate:indexes
```

## Testing Setup

### Unit Tests
```bash
# iOS Tests
cd ios
xcodebuild test -workspace PrepperApp.xcworkspace -scheme PrepperApp -destination 'platform=iOS Simulator,name=iPhone 13'

# Android Tests
cd android
./gradlew test

# Rust Tests
cd rust/tantivy-mobile
cargo test
```

### Integration Tests
```bash
# Setup test environment
npm run test:setup

# Run integration tests
npm run test:integration
```

## Troubleshooting

### Common Issues

#### 1. Rust Build Failures
```bash
# Clean and rebuild
cargo clean
rustup update
cargo build --release
```

#### 2. iOS Signing Issues
```bash
# Reset certificates
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/
open Xcode and let it regenerate
```

#### 3. Android NDK Issues
```bash
# Set NDK path explicitly
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.0.8775105
```

#### 4. Memory Issues During Build
```bash
# Increase Node memory
export NODE_OPTIONS="--max-old-space-size=4096"

# Increase Gradle memory
echo "org.gradle.jvmargs=-Xmx4g" >> ~/.gradle/gradle.properties
```

### Debug Tools

#### React Native Debugger
```bash
brew install --cask react-native-debugger
```

#### Flipper (Android)
```bash
brew install --cask flipper
```

#### Charles Proxy (Network debugging)
```bash
brew install --cask charles
```

## Development Workflow

### 1. Feature Branch
```bash
git checkout -b feature/your-feature
```

### 2. Development Cycle
```bash
# Make changes
# Run tests
npm test
# Run linter
npm run lint
# Commit
git add .
git commit -m "feat: your feature description"
```

### 3. Pre-commit Hooks
```bash
# Install hooks
npm run prepare

# Hooks will run:
# - ESLint
# - Prettier
# - Unit tests
# - Type checking
```

### 4. Pull Request
```bash
git push origin feature/your-feature
# Create PR on GitHub
```

## Performance Profiling

### iOS Profiling
1. Open Xcode
2. Product → Profile
3. Select Instruments template:
   - Time Profiler (CPU usage)
   - Allocations (Memory)
   - Energy Log (Battery)

### Android Profiling
1. Open Android Studio
2. View → Tool Windows → Profiler
3. Profile:
   - CPU usage
   - Memory allocation
   - Network (should be minimal)
   - Energy consumption

## Deployment

### Development Builds
```bash
# iOS
npm run ios:dev

# Android  
npm run android:dev
```

### Staging Builds
```bash
# iOS
npm run ios:staging

# Android
npm run android:staging
```

### Production Builds
```bash
# iOS
npm run ios:release

# Android
npm run android:release
```

## Additional Resources

### Documentation
- [React Native Docs](https://reactnative.dev/docs/getting-started)
- [Rust Mobile Bindings](https://mozilla.github.io/uniffi-rs/)
- [Tantivy Documentation](https://docs.rs/tantivy/)

### Community
- Discord: [PrepperApp Developers](https://discord.gg/prepperapp)
- Forum: [developers.prepperapp.com](https://developers.prepperapp.com)
- Issues: [GitHub Issues](https://github.com/prepperapp/prepperapp/issues)

### Code Style
- [JavaScript Style Guide](./javascript-style.md)
- [Swift Style Guide](./swift-style.md)
- [Kotlin Style Guide](./kotlin-style.md)
- [Rust Style Guide](./rust-style.md)