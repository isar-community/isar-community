import Flutter
import UIKit

@_silgen_name("isar_get_error")
func isar_get_error(_ err: UInt32) -> UnsafeMutablePointer<Int8>?

public class IsarFlutterLibsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {}

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(nil)
    }

    public func dummyMethodToEnforceBundling() {
        // dummy call to prevent tree shaking of Isar native symbols
        isar_get_error(0)
    }
}
