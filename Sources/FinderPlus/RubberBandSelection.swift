import SwiftUI
import AppKit

// MARK: - Preference Key for tracking item frames in a coordinate space
struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Rubber Band Drag Selection State
/// Shared state object for rubber band selection that the overlay and parent view coordinate through.
public class RubberBandState: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var dragRect: CGRect = .zero  // In the scroll content coordinate space
    @Published var startPoint: CGPoint = .zero
}
