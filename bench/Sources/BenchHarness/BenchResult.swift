// Schema for a single benchmark run, written to JSON.

import Foundation

public struct BenchResult: Codable {
    public var device: String
    public var os: String
    public var framework: String          // "mamba-metal-swift" | "mlx-lm" | …
    public var model: String              // HF repo id

    public var promptTokens: Int
    public var decodeTokens: Int

    public var loadSeconds: Double
    public var prefillSeconds: Double
    public var decodeSecondsPerToken: Double

    public var memoryBefore: MemorySample
    public var memoryAfterLoad: MemorySample
    public var memoryPeak: MemorySample

    #if os(iOS)
    public var availableMBMin: Double
    #endif

    public var killedByJetsam: Bool = false
    public var completed: Bool = false
    public var note: String = ""
    public var output: String = ""        // generated text (truncated)

    public init(
        device: String, os osName: String, framework: String, model: String,
        promptTokens: Int = 0, decodeTokens: Int = 0,
        loadSeconds: Double = 0, prefillSeconds: Double = 0,
        decodeSecondsPerToken: Double = 0,
        memoryBefore: MemorySample = .init(physFootprintMB: 0, virtualMB: 0, residentMB: 0, timestamp: 0),
        memoryAfterLoad: MemorySample = .init(physFootprintMB: 0, virtualMB: 0, residentMB: 0, timestamp: 0),
        memoryPeak: MemorySample = .init(physFootprintMB: 0, virtualMB: 0, residentMB: 0, timestamp: 0)
    ) {
        self.device = device
        self.os = osName
        self.framework = framework
        self.model = model
        self.promptTokens = promptTokens
        self.decodeTokens = decodeTokens
        self.loadSeconds = loadSeconds
        self.prefillSeconds = prefillSeconds
        self.decodeSecondsPerToken = decodeSecondsPerToken
        self.memoryBefore = memoryBefore
        self.memoryAfterLoad = memoryAfterLoad
        self.memoryPeak = memoryPeak
        #if os(iOS)
        self.availableMBMin = -1
        #endif
    }

    public func write(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(self)
        try data.write(to: url)
    }
}
