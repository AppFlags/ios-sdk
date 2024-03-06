
import Foundation
import UIKit
import AppFlagsSwiftProtobufs

public class AppFlagsClient {
    
    private let sdkKey: String
    private var user: AppFlagsUser
    private let edgeUrl: String
    
    private let flagsApi: FlagsApi
    private var configurationEventListener: ConfigurationUpdateListener? = nil
    
    private var configuration: Configuration? = nil
    private var cachedFlags: [String: [Weak<AnyObject>]] = [:]

    private var appClosedWorkItem: DispatchWorkItem?
    private var clientPaused: Bool = false
    
    public init(sdkKey: String, user: AppFlagsUser, options: AppFlagsClientOptions? = nil) throws {
        self.sdkKey = sdkKey
        self.user = user
        
        if let logLevelOverride = options?.logLevel {
            Logger.logLevel = logLevelOverride
        }
        
        self.edgeUrl = options?.edgeUrlOverride ?? "https://edge.appflags.net"
        self.flagsApi = FlagsApi(clientKey: sdkKey, edgeUrl: edgeUrl)
        
        initialize()
        
        Logger.debug("Created AppFlagsClient")
    }
    
    private func initialize() {
        loadConfiguration(loadType: Appflags_ConfigurationLoadType.initialLoad)
        
        configurationEventListener = ConfigurationUpdateListener(sdkKey: self.sdkKey, edgeUrl: self.edgeUrl) { (published: Int64) in
            self.loadConfiguration(loadType: Appflags_ConfigurationLoadType.realtimeReload, publishedAt: published)
        }
        
        addAppObservers()
    }
    
    private func addAppObservers() {
        // TODO: this handles iOS, will need to update for other platforms
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onApplicationClosed),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onApplicationResumed),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func onApplicationClosed() {
        Logger.debug("Application closed")
        
        let workItem = DispatchWorkItem {
            self.clientPaused = true
            self.configurationEventListener?.close()
            Logger.debug("Paused client")
        }
        self.appClosedWorkItem = workItem
        
        let deadline = DispatchTime.now() + 60 // execute in 60 seconds
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }
    
    @objc private func onApplicationResumed() {
        // Only run if app was closed
        if !self.clientPaused {
            Logger.debug("Application resumed, client is not yet paused")
            return
        }
        self.clientPaused = false
        
        Logger.debug("Application resumed")
        
        self.appClosedWorkItem?.cancel() // cancel pending close action if present
        
        loadConfiguration(loadType: Appflags_ConfigurationLoadType.initialLoad)
        self.configurationEventListener?.reconnectIfNeeded()
        
        Logger.debug("Unpaused client")
    }
    
    private func loadConfiguration(loadType: Appflags_ConfigurationLoadType, publishedAt: Int64? = nil) {
        do {
            try self.flagsApi.getConfiguration(user: user, loadType: loadType, getUpdateAt: publishedAt) {
                (config: Configuration?, error: Error?) in
                if let error = error {
                    Logger.error("Error loading flags", error)
                    return
                }
                if let config = config {
                    self.configuration = config
                    Logger.debug("Updated configuration, has \(config.flags.count) flags")
                }
                self.updatedCachedFlags()
            }
        } catch {
            Logger.error("Failed to load flags", error)
        }
    }
    
    public func getBooleanFlag(flagKey: String, defaultValue: Bool) -> AppFlag<Bool> {
        return getFlagInternal(flagKey: flagKey, flagType: FlagType.boolean, defaultValue: defaultValue)
    }
    
    public func getNumberFlag(flagKey: String, defaultValue: Double) -> AppFlag<Double> {
        return getFlagInternal(flagKey: flagKey, flagType: FlagType.number, defaultValue: defaultValue)
    }
    
    public func getStringFlag(flagKey: String, defaultValue: String) -> AppFlag<String> {
        return getFlagInternal(flagKey: flagKey, flagType: FlagType.string, defaultValue: defaultValue)
    }
    
    enum FlagRetrievalError: Error {
        case typeMismatch(foundType: FlagType)
    }
    
    private func getFlagInternal<T>(flagKey: String, flagType: FlagType, defaultValue: T) -> AppFlag<T> {
        let rawFlag: Appflags_ComputedFlag? = self.configuration?.flags[flagKey]
        
        // If we have a raw flag, convert it
        var flagOrNil: AppFlag<T>? = nil
        if let rawFlag = rawFlag {
            do {
                let convertedFlag = try (ProtobufConverters.toAppFlagsFlag(proto: rawFlag) as? AppFlag<T>)!
                if (convertedFlag.flagType != flagType) {
                    throw FlagRetrievalError.typeMismatch(foundType: convertedFlag.flagType)
                }
                flagOrNil = convertedFlag
            } catch FlagRetrievalError.typeMismatch(let foundType) {
                Logger.warn("Found flag did not match exected type. Expected \(flagType.rawValue) but found \(foundType.rawValue). Falling back to default value.")
            } catch {
                Logger.error("Error retreiving flag during conversion process, falling back to default value")
            }
        }
        
        // Fall back to the default value if unable to retrieve the specified flag
        let flag: AppFlag<T>
        if let flagOrNil = flagOrNil {
            flag = flagOrNil
        } else {
            flag = AppFlag<T>(key: flagKey, flagType: flagType, value: defaultValue, isDefaultValue: true)
        }
        
        // Cache the flag for updates
        if cachedFlags[flagKey] == nil {
            cachedFlags[flagKey] = []
        }
        cachedFlags[flagKey]!.append(Weak(flag))
        
        return flag
    }
    
    private func updatedCachedFlags() {
        for flagKey in cachedFlags.keys {
            
            // Get the current flag from the configuration
            guard let rawFlag = configuration?.flags[flagKey] else {
                Logger.warn("Updated configuration does not include pre-existing flag [\(flagKey)]")
                continue
            }
            let updatedFlag: FlagProtocol
            do {
                updatedFlag = try ProtobufConverters.toAppFlagsFlag(proto: rawFlag)
            } catch {
                Logger.error("Unable to convert updated flag [\(flagKey)]", error)
                continue
            }
            
            // Remove any nil weak flag references
            cachedFlags[flagKey] = cachedFlags[flagKey]!.compactMap { weakFlag in
                if weakFlag.value != nil {
                    return weakFlag
                } else {
                    return nil
                }
            }
            
            // Update the flags
            for weakFlag in cachedFlags[flagKey]! {
                if let flag = weakFlag.value {
                    (flag as? FlagProtocol)?.updateFlag(updatedFlag)
                }
            }
        }
    }
    
    public func updateUser(user: AppFlagsUser) {
        self.user = user
        loadConfiguration(loadType: Appflags_ConfigurationLoadType.periodicReload)
    }
    
}
