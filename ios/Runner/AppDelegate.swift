import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Load API key from environment or Info.plist
    // Add GOOGLE_MAPS_API_KEY to your Info.plist or use --dart-define
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    } else {
      // Fallback - this should be set via build configuration
      print("WARNING: GOOGLE_MAPS_API_KEY not found in Info.plist")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
