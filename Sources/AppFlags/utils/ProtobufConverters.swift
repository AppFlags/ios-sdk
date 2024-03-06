
import Foundation
import AppFlagsSwiftProtobufs

internal class ProtobufConverters {
    
    static func toUserProto(user: AppFlagsUser) -> Appflags_User {
        var proto = Appflags_User()
        proto.key = user.key
        return proto
    }
    
    static func toConfiguration(getFlagsResponse: Appflags_GetFlagsResponse) -> Configuration {
        var flags: [String : Appflags_ComputedFlag] = [:]
        for flag in getFlagsResponse.flags {
            flags[flag.key] = flag
        }
        return Configuration(flags: flags)
    }
    
    enum AppFlagsValueTypeError: Error {
        case unexpectedType(String)
    }
    
    static func toAppFlagsFlag(proto: Appflags_ComputedFlag) throws -> FlagProtocol {
        switch proto.valueType {
        case .boolean:
            return AppFlag<Bool>(
                key: proto.key,
                flagType: FlagType.boolean,
                value: proto.value.booleanValue
            )
        case .double:
            return AppFlag<Double>(
                key: proto.key,
                flagType: FlagType.number,
                value: proto.value.doubleValue
            )
        case .string:
            return AppFlag<String>(
                key: proto.key,
                flagType: FlagType.string,
                value: proto.value.stringValue
            )
        case .UNRECOGNIZED(let int):
            fallthrough
        default:
            throw AppFlagsValueTypeError.unexpectedType("Unepxected valueType [\(proto.valueType.rawValue)]")
        }
    }
    
}
