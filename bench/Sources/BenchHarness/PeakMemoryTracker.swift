// Light-weight peak-memory sampler — call .sample() periodically during a run.

import Foundation

public final class PeakMemoryTracker {
    public private(set) var peak: MemorySample
    #if os(iOS)
    public private(set) var availableMBMin: Double = .infinity
    #endif

    public init() {
        peak = MemoryProfile.sample()
        #if os(iOS)
        availableMBMin = MemoryProfile.availableMB()
        #endif
    }

    public func sample() {
        let s = MemoryProfile.sample()
        if s.physFootprintMB > peak.physFootprintMB { peak = s }
        #if os(iOS)
        let a = MemoryProfile.availableMB()
        if a < availableMBMin { availableMBMin = a }
        #endif
    }
}
