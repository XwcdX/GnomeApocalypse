import Cocoa
import CoreText

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerCustomFont(named: "font_pixelade")
    }
    
    private func registerCustomFont(named assetName: String) {
        guard let asset = NSDataAsset(name: assetName) else {
            print("⚠️ Failed to find NSDataAsset: \(assetName)")
            return
        }
        
        guard let provider = CGDataProvider(data: asset.data as CFData),
              let font = CGFont(provider) else {
            print("⚠️ Failed to create CGFont from asset: \(assetName)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(font, &error) {
            if let postScriptName = font.postScriptName {
                print("✅ Successfully registered custom font: \(postScriptName)")
            }
        } else {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            print("⚠️ Failed to register custom font: \(errorDescription)")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
