/// Input rules for the authorized user sign-in form.
class Validators {
  static const requiredDomain = '@tip.edu.ph';
  static const minPasswordLength = 6;

  static bool isValidEmail(String value) {
    final email = value.trim().toLowerCase();
    return email.length > requiredDomain.length &&
        email.endsWith(requiredDomain) &&
        !email.contains(' ') &&
        // The first "@" must be the one that starts the domain.
        email.indexOf('@') == email.length - requiredDomain.length;
  }

  static String? emailError(String value) =>
      isValidEmail(value) ? null : 'Use your @tip.edu.ph email address';

  static bool isValidPassword(String value) =>
      value.length >= minPasswordLength;

  static String? passwordError(String value) => isValidPassword(value)
      ? null
      : 'Use at least $minPasswordLength characters';

  static bool passwordsMatch(String password, String confirm) =>
      confirm.isNotEmpty && password == confirm;

  static String? confirmError(String password, String confirm) =>
      passwordsMatch(password, confirm)
          ? null
          : 'Passwords do not match. Re-type to confirm.';
}
