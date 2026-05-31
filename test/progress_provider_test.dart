import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
  });

  test('saveProgressSilent persists without notifying listeners', () async {
    final provider = ProgressProvider()..load();
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.saveProgressSilent('lecture-1', 120);
    expect(notifications, 0);
    expect(provider.getPositionSeconds('lecture-1'), 120);

    await provider.saveProgress('lecture-1', 120);
    expect(notifications, 0);

    await provider.saveProgress('lecture-1', 180);
    expect(notifications, 1);
    expect(provider.getPositionSeconds('lecture-1'), 180);
  });
}
