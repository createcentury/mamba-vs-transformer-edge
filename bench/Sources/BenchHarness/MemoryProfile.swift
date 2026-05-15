// Cross-platform (macOS + iOS) memory profile via Mach task_info.

import Foundation
import Darwin

public struct MemorySample: Codable {
    public let physFootprintMB: Double
    public let virtualMB: Double
    public let residentMB: Double
    public let timestamp: TimeInterval

    public init(physFootprintMB: Double, virtualMB: Double, residentMB: Double, timestamp: TimeInterval) {
        self.physFootprintMB = physFootprintMB
        self.virtualMB = virtualMB
        self.residentMB = residentMB
        self.timestamp = timestamp
    }
}

public enum MemoryProfile {

    /// Current process physical footprint (what Apple's "memory used" reports).
    public static func sample() -> MemorySample {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let mb = 1024.0 * 1024.0
        if result == KERN_SUCCESS {
            return MemorySample(
                physFootprintMB: Double(info.phys_footprint) / mb,
                virtualMB: Double(info.virtual_size) / mb,
                residentMB: Double(info.resident_size) / mb,
                timestamp: Date().timeIntervalSince1970
            )
        }
        return MemorySample(physFootprintMB: 0, virtualMB: 0, residentMB: 0, timestamp: Date().timeIntervalSince1970)
    }

    #if os(iOS)
    /// Bytes the OS will let us allocate before pressuring/killing us.
    public static func availableMB() -> Double {
        Double(os_proc_available_memory()) / (1024.0 * 1024.0)
    }
    #else
    public static func availableMB() -> Double { -1 }  // not applicable on macOS
    #endif
}
