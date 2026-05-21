import ActivityKit
import Foundation

/// Live Activity contract for a knitting session. The attributes are set when
/// the user taps "Start session" and don't change for the activity's lifetime;
/// only the `ContentState` (row count) updates as the user knits.
struct CounterActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var rows: Int
        /// Instruction text for the row the knitter is currently working on
        /// (rows + 1). Nil when the project has no pattern attached. Optional
        /// so existing encoded states without this field stay decodable.
        var currentRowText: String? = nil
    }

    let projectId: String
    let projectTitle: String
    let rowsTotal: Int
}
