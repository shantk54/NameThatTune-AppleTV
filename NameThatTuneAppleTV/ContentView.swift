import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 48) {
                Text("Name That Tune")
                    .font(.system(size: 72, weight: .bold))
                
                Text("Apple Music Edition")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                NavigationLink {
                    MusicTestView()
                } label: {
                    Text("MusicKit Test")
                        .font(.title2)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 20)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
