import Cocoa
import CoreText

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerCustomFont(named: "PIXELADE")
    }
    
    private func registerCustomFont(named assetName: String) {
        guard let asset = NSDataAsset(name: assetName) else {
            print("⚠️ Failed to find NSDataAsset: \(assetName)")
            return
        }

        let descriptors = CTFontManagerCreateFontDescriptorsFromData(asset.data as CFData) as? [CTFontDescriptor]
        guard let descriptors, !descriptors.isEmpty else {
            print("⚠️ Failed to create font descriptors from asset: \(assetName)")
            return
        }

        for descriptor in descriptors {
            let name = (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String) ?? assetName
            print("✅ Successfully registered custom font: \(name)")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
