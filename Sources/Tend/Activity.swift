import Foundation
import IOKit

enum Activity {
    // Returns seconds since the last HID input event (mouse / keyboard / trackpad).
    // Returns 0 if the registry lookup fails — failing closed means "user is active"
    // so we never falsely starve the plant of growth time.
    static func systemIdleSeconds() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idleNs = dict["HIDIdleTime"] as? UInt64
        else {
            return 0
        }

        return Double(idleNs) / 1_000_000_000.0
    }
}
