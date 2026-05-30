# Development Checklist

## Initial Setup
- [ ] Clone project: `git clone <repo>`
- [ ] Run setup: `bash setup.sh`
- [ ] Verify Flutter: `flutter doctor`
- [ ] Check dependencies: `flutter pub get`
- [ ] Read documentation: `SETUP_GUIDE.md` and `TESTING_GUIDE.md`

## Before Starting Development
- [ ] Create feature branch: `git checkout -b feature/feature-name`
- [ ] Update packages: `flutter pub upgrade`
- [ ] Run tests: `flutter test`
- [ ] Check code: `flutter analyze`

## During Development
- [ ] Follow Dart style guide
- [ ] Add unit tests for new code
- [ ] Update documentation as needed
- [ ] Format code: `flutter format .`
- [ ] Test on both Android and iOS

## Before Committing
- [ ] Run full test suite: `flutter test`
- [ ] Check code quality: `flutter analyze`
- [ ] Format code: `flutter format .`
- [ ] Verify no console errors: `flutter run -v`
- [ ] Update CHANGELOG if applicable

## Build & Release

### Android Release
- [ ] Verify minSdkVersion = 34
- [ ] Update version in pubspec.yaml
- [ ] Run: `flutter build appbundle --release`
- [ ] Upload to Google Play Console

### iOS Release
- [ ] Update version in pubspec.yaml
- [ ] Run: `flutter build ios --release`
- [ ] Create archive in Xcode
- [ ] Submit to App Store

## Testing Checklist
- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] Code coverage > 80%
- [ ] No linting errors
- [ ] App runs on Android emulator
- [ ] App runs on iOS simulator
- [ ] Tested on physical device

## Documentation Checklist
- [ ] Updated README if needed
- [ ] Added inline code comments
- [ ] Updated CHANGELOG
- [ ] Added test documentation
- [ ] Added API documentation

## Performance Checklist
- [ ] App starts in < 2 seconds
- [ ] No jank during scrolling
- [ ] Memory usage acceptable
- [ ] Battery usage optimized
- [ ] Network calls minimized

## Security Checklist
- [ ] No secrets in code
- [ ] API keys in environment variables
- [ ] Firebase rules are secure
- [ ] No sensitive data in logs
- [ ] HTTPS used for all requests

## After Release
- [ ] Monitor crash reports
- [ ] Check user reviews
- [ ] Update documentation
- [ ] Plan next release
- [ ] Archive release files
