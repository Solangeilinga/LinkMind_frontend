// lib/utils/validators.dart
class Validators {
  
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  
  static bool isValidAge(String age) {
    final ageInt = int.tryParse(age);
    return ageInt != null && ageInt >= 15 && ageInt <= 120;
  }
  
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}