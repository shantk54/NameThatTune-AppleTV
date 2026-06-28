import SwiftUI
import MusicKit

struct MusicTestView: View {
    @StateObject private var musicService = AppleMusicService()

    var body: some View {
        VStack(spacing: 32) {
            Text("MusicKit Test")
                .font(.largeTitle)
                .bold()

            Text("Authorization: \(String(describing: musicService.authorizationStatus))")
                .font(.title3)

            Text("Loaded songs: \(musicService.songs.count)")
                .font(.title3)

            if let firstSong = musicService.songs.first {
                Text("First song: \(firstSong.title)")
                    .font(.title3)

                Text(firstSong.artistName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = musicService.errorMessage {
                Text(errorMessage)
                    .font(.title3)
                    .foregroundStyle(.red)
            }

            Button("Request Apple Music Access") {
                Task {
                    await musicService.requestAuthorization()
                }
            }
            .font(.title2)

            Button("Load Library Songs") {
                Task {
                    await musicService.loadLibrarySongs()
                }
            }
            .font(.title2)

            Button("Play First Song") {
                Task {
                    await musicService.playFirstSong()
                }
            }
            .font(.title2)

            Button("Stop") {
                musicService.stop()
            }
            .font(.title2)
        }
        .padding()
    }
}

#Preview {
    MusicTestView()
}
