import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_app/features/auth/validators.dart';

void main() {
  group('email', () {
    test('accepts tip.edu.ph addresses', () {
      expect(Validators.isValidEmail('radiant@tip.edu.ph'), isTrue);
      expect(Validators.isValidEmail('  Radiant@TIP.edu.ph '), isTrue);
    });

    test('rejects everything else', () {
      for (final bad in [
        '',
        'radiant@gmail.com',
        '@tip.edu.ph',
        'a@b@tip.edu.ph',
        'radiant@tip.edu.ph.com',
        'radiant tip@tip.edu.ph',
      ]) {
        expect(Validators.isValidEmail(bad), isFalse, reason: bad);
      }
    });

    test('error text matches the design', () {
      expect(Validators.emailError('x@gmail.com'),
          'Use your @tip.edu.ph email address');
      expect(Validators.emailError('x@tip.edu.ph'), isNull);
    });
  });

  group('password', () {
    test('needs at least 6 characters', () {
      expect(Validators.isValidPassword('abcde'), isFalse);
      expect(Validators.isValidPassword('abcdef'), isTrue);
    });

    test('confirmation must match and not be empty', () {
      expect(Validators.passwordsMatch('abc123', 'abc123'), isTrue);
      expect(Validators.passwordsMatch('abc123', 'abc124'), isFalse);
      expect(Validators.passwordsMatch('abc123', ''), isFalse);
      expect(Validators.confirmError('abc123', 'abc124'),
          'Passwords do not match. Re-type to confirm.');
      expect(Validators.confirmError('abc123', 'abc123'), isNull);
    });
  });
}
