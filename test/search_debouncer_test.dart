import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/utils/search_debouncer.dart';

void main() {
  test('search debounce runs only the latest scheduled action', () async {
    final debouncer = SearchDebouncer(
      delay: const Duration(milliseconds: 20),
    );
    final values = <String>[];

    debouncer.schedule(() => values.add('first'));
    debouncer.schedule(() => values.add('latest'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(values, ['latest']);
    debouncer.dispose();
  });

  test('explicit search cancels the pending action and runs immediately', () async {
    final debouncer = SearchDebouncer(
      delay: const Duration(milliseconds: 20),
    );
    final values = <String>[];

    debouncer.schedule(() => values.add('pending'));
    debouncer.runNow(() => values.add('submitted'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(values, ['submitted']);
    debouncer.dispose();
  });
}
