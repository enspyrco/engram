import 'package:engram/src/providers/auth_provider.dart';
import 'package:test/test.dart';

void main() {
  group('PopupDismissal.parse', () {
    test('reads the codes for a dismissed popup', () {
      expect(
        PopupDismissal.parse('popup-closed-by-user'),
        PopupDismissal.popupClosedByUser,
      );
      expect(
        PopupDismissal.parse('cancelled-popup-request'),
        PopupDismissal.cancelledPopupRequest,
      );
    });

    test('returns null for real failures', () {
      expect(PopupDismissal.parse('network-request-failed'), isNull);
      expect(PopupDismissal.parse(''), isNull);
    });
  });
}
