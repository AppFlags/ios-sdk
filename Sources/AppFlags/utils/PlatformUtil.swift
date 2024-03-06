
import Foundation
import UIKit
import AppFlagsSwiftProtobufs

internal class PlatformUtil {
    
    static func getPlatformData() -> Appflags_PlatformData {
        // TODO: make this work on all devices
        var systemName = UIDevice.current.systemName
        var systemVersion = UIDevice.current.systemVersion
        
        var platformData = Appflags_PlatformData()
        platformData.sdk = "iOS"
        platformData.sdkType = "mobile"
        platformData.sdkVersion = SdkVersion.SDK_VERSION
        platformData.platform = systemName
        platformData.platformVersion = systemVersion
        return platformData
    }
    
}
