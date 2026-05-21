import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct CounterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CounterActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Palette.primary)
                .activitySystemActionForegroundColor(Palette.walnut)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.projectTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(context.state.rows)")
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 10) {
                        Button(intent: DecrementRowIntent(projectId: context.attributes.projectId)) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Palette.primarySoft)
                        }
                        .buttonStyle(.plain)
                        Button(intent: IncrementRowIntent(projectId: context.attributes.projectId)) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Palette.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let text = context.state.currentRowText {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(Palette.creamSoft)
                                .lineLimit(2)
                        }
                        if context.attributes.rowsTotal > 0 {
                            ProgressView(value: progress(state: context.state,
                                                         attrs: context.attributes))
                                .progressViewStyle(.linear)
                                .tint(Palette.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "list.number")
            } compactTrailing: {
                Text("\(context.state.rows)")
                    .monospacedDigit()
            } minimal: {
                Text("\(context.state.rows)")
                    .monospacedDigit()
            }
        }
    }

    private func lockScreen(context: ActivityViewContext<CounterActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.projectTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.cream.opacity(0.90))
                        .lineLimit(1)
                    Text(rowLabel(state: context.state, attrs: context.attributes))
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
            }

            if context.attributes.rowsTotal > 0 {
                ProgressView(value: progress(state: context.state,
                                             attrs: context.attributes))
                    .progressViewStyle(.linear)
                    .tint(Palette.cream)
            }

            if let text = context.state.currentRowText {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.cream.opacity(0.90))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 10) {
                Button(intent: ResetRowsIntent(projectId: context.attributes.projectId)) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.20)))
                }
                .buttonStyle(.plain)

                Button(intent: DecrementRowIntent(projectId: context.attributes.projectId)) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.20)))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(intent: IncrementRowIntent(projectId: context.attributes.projectId)) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text("Row")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Palette.walnut)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(Palette.cream))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Palette.primary.opacity(0.92), Palette.primary],
                startPoint: .top, endPoint: .bottom)
        )
    }

    private func rowLabel(state: CounterActivityAttributes.ContentState,
                          attrs: CounterActivityAttributes) -> String {
        attrs.rowsTotal > 0 ? "Row \(state.rows) / \(attrs.rowsTotal)" : "Row \(state.rows)"
    }

    private func progress(state: CounterActivityAttributes.ContentState,
                          attrs: CounterActivityAttributes) -> Double {
        guard attrs.rowsTotal > 0 else { return 0 }
        return min(1, Double(state.rows) / Double(attrs.rowsTotal))
    }
}
