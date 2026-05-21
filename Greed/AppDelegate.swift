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
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFontURL = tempDirectory.appendingPathComponent("\(assetName).ttf")
        
        do {
            try asset.data.write(to: tempFontURL, options: .atomic)
        } catch {
            print("⚠️ Failed to write custom font data to temp URL: \(error.localizedDescription)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(tempFontURL as CFURL, .process, &error) {
            print("✅ Successfully registered custom font: \(assetName)")
        } else {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            print("⚠️ Failed to register custom font: \(errorDescription)")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
