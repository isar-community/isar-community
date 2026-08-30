import Flutter
import isar_symbols
import UIKit

public class IsarFlutterLibsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        isar_keep_symbols()
    }
}
