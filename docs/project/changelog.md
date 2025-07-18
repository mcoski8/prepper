# PrepperApp Changelog

All notable changes to PrepperApp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planning Phase - 2025-07-18

#### Added
- Comprehensive documentation structure
- System architecture design
- Content specification for three-tier system
- Search architecture using Tantivy
- Emergency-optimized UI design system
- Content curation guidelines
- API documentation (Content, Search, Storage)
- Development setup guide
- Sprint planning and roadmap

#### Technical Decisions
- Native iOS (Swift) and Android (Kotlin) development
- Tantivy (Rust) for search engine
- ZIM format for content storage
- FlatBuffers for structured data
- Zstandard compression with custom dictionaries
- Pure black OLED theme for battery optimization

#### Content Strategy
- Core app: 500MB-1GB critical survival content
- Modules: 1-5GB specialized content packs
- External: Support for 100GB+ archives

---

## [1.0.0] - TBD (Target: September 2025)

### Added
- Initial release with core survival content
- Offline search functionality
- Bookmarking system
- Pure black OLED theme
- iOS and Android apps

### Core Content Includes
- Medical emergency procedures
- Water safety and purification
- Dangerous flora/fauna identification
- Basic shelter and fire
- Emergency navigation

---

## [0.9.0-beta] - TBD (Target: August 2025)

### Added
- Beta release for testing
- Core app functionality
- Search implementation
- Basic content reader

### Testing
- 1,000 beta testers
- Performance validation
- Battery usage optimization
- UI/UX feedback collection

---

## [0.5.0-alpha] - TBD (Target: July 2025)

### Added
- Technical prototype
- Tantivy integration proof of concept
- ZIM reader implementation
- Basic UI shell

### Technical
- iOS Tantivy bridge working
- Android JNI integration complete
- Search performance validated
- Compression ratios achieved

---

## Version Naming Convention

### Version Format: MAJOR.MINOR.PATCH

- **MAJOR**: Incompatible API changes or major feature additions
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

### Release Channels

- **Alpha**: Internal testing only (0.x.x-alpha)
- **Beta**: Limited external testing (0.x.x-beta)
- **RC**: Release candidate (1.x.x-rc)
- **Stable**: Public release (1.x.x)

---

## Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only
- **style**: Code style changes
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Test additions/changes
- **chore**: Build process or auxiliary tool changes

### Examples
```
feat(search): add fuzzy matching support
fix(ios): resolve memory leak in content cache
docs(api): update search API documentation
perf(android): optimize image loading
```

---

## Release Process

### 1. Version Bump
```bash
npm version <major|minor|patch>
```

### 2. Update Changelog
- Move Unreleased items to new version
- Add release date
- Update version links

### 3. Tag Release
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 4. Build Releases
```bash
npm run build:ios:release
npm run build:android:release
```

### 5. Deploy
- Upload to App Store Connect
- Upload to Google Play Console
- Update website
- Send release notes

---

## Deprecation Policy

### Feature Deprecation
1. Announce in release notes
2. Show in-app warning for 2 versions
3. Remove in 3rd version
4. Maintain backwards compatibility when possible

### API Deprecation
1. Mark as deprecated in documentation
2. Log warning when used
3. Maintain for 6 months minimum
4. Provide migration guide

---

## Security Updates

### Critical Security Fixes
- Released immediately
- Backported to last 2 major versions
- Security advisory published
- Users notified in-app

### Regular Security Updates
- Monthly security review
- Quarterly dependency updates
- Annual penetration testing
- Continuous static analysis

---

## Archive

Older versions and their changelogs are archived at:
`https://github.com/prepperapp/prepperapp/releases`

---

_This changelog is generated partially automatically and partially through manual updates. For the complete commit history, see the git log._