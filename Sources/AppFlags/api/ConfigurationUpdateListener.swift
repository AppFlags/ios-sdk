
import Foundation
import LDSwiftEventSource

class ConfigurationUpdateListener {
    
    typealias SseUrlHandler = (String) -> Void
    typealias SseMessageHandler = (LDSwiftEventSource.MessageEvent) -> Void
    typealias SseClosedHandler = () -> Void
    
    typealias UpdateEventHandler = (Int64) -> Void
    
    let sdkKey: String
    let edgeUrl: String
    let updateEventHandler: UpdateEventHandler
    
    var eventSource: EventSource? = nil
    var lastEventId: String? = nil
    var isClosed: Bool = true
    
    let eventSourceCreationLock = NSLock()
    
    init(sdkKey: String, edgeUrl: String, updateEventHandler: @escaping UpdateEventHandler) {
        self.sdkKey = sdkKey
        self.edgeUrl = edgeUrl
        self.updateEventHandler = updateEventHandler
        
        Logger.debug("Creating ConfigurationUpdateListener")
        createEventSource()
        Logger.debug("Created ConfigurationUpdateListener")
    }
    
    private func handleMessageEvent(messageEvent: LDSwiftEventSource.MessageEvent) {
        self.lastEventId = messageEvent.lastEventId
        do {
            let eventSourceMessage: EventSourceMessage = try JSONDecoder().decode(
                EventSourceMessage.self,
                from: messageEvent.data.data(using: .utf8)!
            )
            let configUpdateEvent: ConfigurationUpdateEvent = try JSONDecoder().decode(
                ConfigurationUpdateEvent.self,
                from: eventSourceMessage.data!.data(using: .utf8)!
            )
            updateEventHandler(configUpdateEvent.published)
        } catch {
            Logger.error("Error handling SSE message", error)
        }
    }
    
    private func closeEventSource() {
        if let eventSource = eventSource {
            eventSource.stop()
            Logger.debug("Closed existing event source")
        } else {
            Logger.debug("Event source already closed")
        }
        self.eventSource = nil
        self.isClosed = true
    }
    
    private func createEventSource() {
        // get the SSE URL and then create a new EventSource
        getSseUrl() { (urlString: String) in
            // prevent multiple threads from creating event sources simultaneously
            self.eventSourceCreationLock.lock()
            defer {self.eventSourceCreationLock.unlock()}
            
            // close the existing EventSource, if present
            if let eventSource = self.eventSource {
                self.closeEventSource()
            }
            
            let url = URL(string: urlString)!
            let sseEventHandler = SseEventHandler(
                messageEventHandler: self.handleMessageEvent
            )
            let config = EventSource.Config(
                handler: sseEventHandler,
                url: url
            )
            self.eventSource = EventSource(config: config)
            self.eventSource?.start()
            self.isClosed = false
            Logger.debug("Created new EventSource [#\(sseEventHandler.id)]")
        }
    }
    
    private class SseEventHandler: EventHandler {
        static var currentID: Int = 0
        
        let id: Int
        
        let messageEventHandler: SseMessageHandler
        
        init(messageEventHandler: @escaping SseMessageHandler) {
            self.messageEventHandler = messageEventHandler
            
            SseEventHandler.currentID += 1
            self.id = SseEventHandler.currentID
        }
        
        func onOpened() {
            Logger.debug("SSE EventSource [#\(id)] opened")
        }
        
        func onClosed() {
            Logger.debug("SSE EventSource [#\(id)] closed")
        }
        
        func onMessage(eventType: String, messageEvent: LDSwiftEventSource.MessageEvent) {
            Logger.debug("SSE EventSource [#\(id)] onMessage")
            if (eventType == "message") {
                messageEventHandler(messageEvent)
            }
        }
        
        func onComment(comment: String) {
            return
        }
        
        func onError(error: Error) {
            Logger.error("SSE EventSource [#\(id)] onError", error)
        }
    }
    
    private func getSseUrl(handler: @escaping SseUrlHandler) {
        let url: URL = URL(string: "\(self.edgeUrl)/realtimeToken/\(self.sdkKey)/eventSource")! 
        var request = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                Logger.error("Error getting SSE url", error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("Response getting SSE url was not an HTTPURLResponse")
                return
            }
            let statusCode = httpResponse.statusCode
            if (statusCode != 200) {
                Logger.error("Error getting SSE url, status code \(statusCode)")
                return
            }
            do {
                let responseBody: GetSseUrlResponse = try JSONDecoder().decode(GetSseUrlResponse.self, from: data!)
                handler(responseBody.url)
            } catch {
                Logger.error("Error decoding SSE URL response", error)
            }
        }
        task.resume()
    }
    
    func close() {
        Logger.debug("Closing ConfigurationUpdateListener")
        
        closeEventSource()
    }
    
    func reconnectIfNeeded() {
        Logger.debug("Resuming ConfigurationUpdateListener")
        
        if (eventSource == nil) {
            Logger.debug("EventSource is closed, reconnecting")
            createEventSource()
        } else {
            Logger.debug("EventSource is already connected")
        }
    }
    
}

struct GetSseUrlResponse: Codable {
    let url: String
}

struct EventSourceMessage: Codable {
    let data: String?
}

struct ConfigurationUpdateEvent: Codable {
    let published: Int64
}
