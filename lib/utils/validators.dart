// lib/utils/validators.dart
class Validators {
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\.]'), '');
  }
  
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  static bool isValidPhone(String phone) {
    return RegExp(r'^(\+?\d{6,15})$').hasMatch(normalizePhone(phone));
  }
  
  static bool isValidAge(String age) {
    final ageInt = int.tryParse(age);
    return ageInt != null && ageInt >= 15 && ageInt <= 120;
  }
  
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}