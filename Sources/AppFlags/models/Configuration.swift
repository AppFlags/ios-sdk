
import Foundation
import AppFlagsSwiftProtobufs

internal class Configuration {
    let flags: [String : Appflags_ComputedFlag]
    
    init(flags: [String : Appflags_ComputedFlag]) {
        self.flags = flags
    }
}
