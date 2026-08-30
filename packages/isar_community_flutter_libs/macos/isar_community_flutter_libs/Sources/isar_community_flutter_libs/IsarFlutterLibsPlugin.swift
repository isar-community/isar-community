import Cocoa
import FlutterMacOS

@_silgen_name("isar_get_error")
func isar_get_error(_ err: Int64) -> UnsafeMutablePointer<Int8>?

public class IsarFlutterLibsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Keep Isar Core loaded for DynamicLibrary.process().
        _ = isar_get_error(0)
    }
}
