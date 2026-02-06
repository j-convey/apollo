import 'dart:io' show Platform;
import 'desktop/main_desktop.dart' as desktop;
import 'mobile/main_mobile.dart' as mobile;

void main() {
  if (Platform.isAndroid || Platform.isIOS) {
    mobile.main();
  } else {
    desktop.main();
  }
}
