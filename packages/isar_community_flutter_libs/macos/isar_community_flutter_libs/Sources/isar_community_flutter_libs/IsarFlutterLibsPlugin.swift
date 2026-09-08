import Cocoa
import FlutterMacOS

@_silgen_name("isar_get_error")
func isar_get_error(_ err: UInt32) -> UnsafeMutablePointer<Int8>?

public class IsarFlutterLibsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "isar_community_flutter_libs", binaryMessenger: registrar.messenger)
        let instance = IsarFlutterLibsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func dummyMethodToEnforceBundling() {
        isar_get_error(0)
    }
}
