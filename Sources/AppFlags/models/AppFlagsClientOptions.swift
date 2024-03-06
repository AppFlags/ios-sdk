
import Foundation

public class AppFlagsClientOptions {
    var edgeUrlOverride: String? = nil
    var logLevel: LogLevel? = nil
    
    public class Builder {
        
        private var options: AppFlagsClientOptions
        
        public init() {
            self.options = AppFlagsClientOptions()
        }
        
        public func edgeUrlOverride(_ edgeUrlOverride: String) -> Builder {
            self.options.edgeUrlOverride = edgeUrlOverride
            return self
        }
        
        public func logLevel(_ logLevel: LogLevel) -> Builder {
            self.options.logLevel = logLevel
            return self
        }
        
        public func build() -> AppFlagsClientOptions {
            return options
        }
    }
}
