
import Foundation

public enum FlagType: String {
    case boolean
    case number
    case string
}

public typealias FlagUpdateHandler<T> = (T) -> Void

protocol FlagProtocol {
    var key: String {get}
    func updateFlag(_ updatedFlagProtocol: FlagProtocol)
}

public class AppFlag<T: Equatable>: FlagProtocol {
    
    public let key: String
    public let flagType: FlagType
    public internal(set) var value: T
    public internal(set) var isDefaultValue: Bool
    private var onUpdateHandlers: [FlagUpdateHandler<T>] = []
    
    init(key: String, flagType: FlagType, value: T, isDefaultValue: Bool = false) {
        self.key = key
        self.flagType = flagType
        self.value = value
        self.isDefaultValue = isDefaultValue
    }
    
    internal func updateFlag(_ updatedFlagProtocol: FlagProtocol) {
        guard let updatedFlag = updatedFlagProtocol as? AppFlag<T> else {
            Logger.warn("Unable to convert updated flag [\(key)] to the corresponding type, cannot update flag's value.")
            return
        }
        if (updatedFlag.flagType != flagType) {
            Logger.warn("Updated flag [\(updatedFlag.key)] is not the same type, canot update flag's value")
            return
        }
        
        isDefaultValue = false
        
        if (value != updatedFlag.value) {
            value = updatedFlag.value
            for handler in onUpdateHandlers {
                handler(value)
            }
        }
    }
    
    public func onUpdate(handler: @escaping FlagUpdateHandler<T>) -> AppFlag<T> {
        self.onUpdateHandlers.append(handler)
        return self
    }
    
}
