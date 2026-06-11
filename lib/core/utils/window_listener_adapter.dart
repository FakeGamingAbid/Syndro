import 'package:window_manager/window_manager.dart';

/// Mixin with no-op defaults for all [WindowListener] methods.
///
/// Mix this in instead of [WindowListener] to avoid boilerplate:
/// ```dart
/// class MyState extends StatefulWidget with WindowListenerAdapter {
///   @override
///   void onWindowClose() {
///     // Only this method has logic
///   }
/// }
/// ```
mixin WindowListenerAdapter implements WindowListener {
  @override
  void onWindowClose() {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}
}
