import Cocoa
import Darwin
import FlutterMacOS
import AVFoundation
import Speech

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSLog("[APP] PID=\(getpid()) applicationDidFinishLaunching")
    // طلب صلاحية في نفس العملية فقط عند الإطلاق الآمن — لا يفتح .app ثاني.
    MacOSTccChannel.promptPermissionsIfSafeLaunch()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
