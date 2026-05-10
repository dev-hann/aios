import 'package:permission_handler/permission_handler.dart';

Permission? permissionFromKey(String key) {
  return switch (key) {
    'contacts' => Permission.contacts,
    'phone' => Permission.phone,
    'sms' => Permission.sms,
    _ => null,
  };
}
