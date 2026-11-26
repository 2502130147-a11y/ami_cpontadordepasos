import 'package:flutter_test/flutter_test.dart';

import 'package:app_contador_maye/features/tracking/logic/effort.dart';
import 'package:app_contador_maye/shared/utils/fmt.dart';

void main() {
  test('Formato de tiempo', () {
    expect(Fmt.clock(75), '01:15');
    expect(Fmt.clock(3725), '1:02:05');
  });

  test('Formato de miles', () {
    expect(Fmt.thousands(12345), '12,345');
  });

  test('Clasificación de intensidad', () {
    expect(Effort.fromLevel(0.2), Effort.rest);
    expect(Effort.fromLevel(2.0), Effort.walk);
    expect(Effort.fromLevel(5.0), Effort.jog);
  });
}
