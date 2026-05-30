# Testing Guide for Al-Tawheed Project

## Running Tests

### Quick Start
```bash
# Run all tests
flutter test

# Run with verbose output
flutter test --verbose

# Run specific test file
flutter test test/widget_test.dart
flutter test test/unit_tests.dart
flutter test test/widget_test_updated.dart

# Run with coverage
flutter test --coverage
```

## Test Files

### 1. `test/widget_test.dart`
- **Purpose**: Widget and UI component tests
- **Type**: Integration tests for Flutter widgets
- **Run**: `flutter test test/widget_test.dart`

### 2. `test/unit_tests.dart`
- **Purpose**: Unit tests for models, services, and utilities
- **Type**: Pure Dart unit tests
- **Run**: `flutter test test/unit_tests.dart`

### 3. `test/widget_test_updated.dart`
- **Purpose**: Updated widget tests with better structure
- **Type**: Widget testing examples
- **Run**: `flutter test test/widget_test_updated.dart`

## Test Categories

### Widget Tests
Test Flutter UI components and interactions:
```bash
flutter test test/widget_test.dart
```

### Unit Tests
Test business logic, models, and services:
```bash
flutter test test/unit_tests.dart
```

### Integration Tests
Test app flows across multiple screens (requires integration test setup):
```bash
flutter drive --target=test_driver/app.dart
```

## Code Coverage

### Generate Coverage Report
```bash
# Generate coverage data
flutter test --coverage

# View coverage (requires lcov)
# macOS:
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Best Practices

### 1. Test Organization
- Group related tests with `group()`
- Use descriptive test names
- Follow AAA pattern: Arrange, Act, Assert

### 2. Widget Testing
```dart
testWidgets('Description of what should happen', (WidgetTester tester) async {
  // Arrange: Build widget
  await tester.pumpWidget(MyWidget());
  
  // Act: Interact with widget
  await tester.tap(find.byType(Button));
  await tester.pumpAndSettle();
  
  // Assert: Verify results
  expect(find.text('Expected Text'), findsOneWidget);
});
```

### 3. Mocking External Dependencies
```dart
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  test('Service test with mock', () {
    final mockService = MockApiService();
    when(mockService.fetchData()).thenAnswer((_) async => []);
  });
}
```

## CI/CD Integration

### Pre-commit Testing
```bash
# Run before committing code
flutter analyze && flutter test && flutter build apk --debug
```

### GitHub Actions Example
Create `.github/workflows/test.yml`:
```yaml
name: Flutter Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

## Debugging Tests

### Run with Verbose Output
```bash
flutter test --verbose
```

### Run Single Test
```bash
# By test name
flutter test --name "should_create_channel"

# By grep pattern
flutter test -p "unit_tests"
```

### Debug Mode
```bash
flutter test test/widget_test.dart -v --start-paused
```

## Common Test Issues

### Issue: Tests timeout
**Solution**: Increase timeout
```dart
testWidgets('Test name', (WidgetTester tester) async {
  // test code
}, timeout: Timeout(Duration(seconds: 30)));
```

### Issue: Async test hangs
**Solution**: Use `pumpAndSettle()`
```dart
await tester.pumpAndSettle(); // Waits for all animations to complete
```

### Issue: Widget not found
**Solution**: Debug with `tester.printToConsole()`
```dart
tester.printToConsole();
print(find.byType(MyWidget).evaluate());
```

## Test Metrics

Track these metrics for code quality:
- **Code Coverage**: Aim for >80%
- **Test Pass Rate**: 100%
- **Test Execution Time**: <5 minutes total
- **Test Flakiness**: <1%

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Integration Test Guide](https://flutter.dev/docs/testing/integration-tests)

---

**Last Updated**: February 2026
**Flutter Version**: 3.0.0+
