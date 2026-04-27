/// Правила пароля и шкала «надёжности» для регистрации и сброса.
class PasswordPolicy {
  PasswordPolicy._();

  static final RegExp _startsWithLetter = RegExp(r'^[a-zA-Zа-яА-ЯёЁ]');

  /// Первый символ — буква (латиница или кириллица), не цифра и не спецсимвол.
  static bool startsWithAllowedLetter(String password) {
    if (password.isEmpty) return false;
    return _startsWithLetter.hasMatch(password.substring(0, 1));
  }

  static String? validate(String password) {
    if (password.length < 6) return 'Пароль не короче 6 символов';
    if (!startsWithAllowedLetter(password)) {
      return 'Пароль должен начинаться с буквы (латиница или кириллица), не с цифры и не со спецсимвола.';
    }
    return null;
  }

  /// 0 — очень слабо … 4 — сильнее (для шкалы из 4–5 делений).
  static int strengthBars(String password) {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[A-ZА-ЯЁ]').hasMatch(password) && RegExp(r'[a-zа-яё]').hasMatch(password)) {
      s++;
    }
    if (RegExp(r'[^a-zA-Zа-яА-ЯёЁ0-9]').hasMatch(password)) s++;
    if (s > 4) s = 4;
    return s;
  }
}
