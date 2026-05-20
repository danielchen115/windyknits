import SwiftUI

struct ContentView: View {
    var body: some View { RootView() }
}

#Preview {
    ContentView().environment(PatternStore.shared)
}
