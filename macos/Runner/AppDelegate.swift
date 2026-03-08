import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true;
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true;
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    // Handle shared files from other apps
    let controller = window?.contentViewController as? FlutterViewController
    let channel = FlutterMethodChannel(name: "com.syndro.app/share_intent", binaryMessenger: controller!.binaryMessenger)
    
    let filePaths = urls.map { $0.path }
    channel.invokeMethod("handleSharedFiles", arguments: filePaths)
  }
}
