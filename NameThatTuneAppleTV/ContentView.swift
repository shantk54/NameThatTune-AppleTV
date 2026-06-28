import SwiftUI

struct ContentView: View {
    @StateObject private var albumWallService = AlbumWallService()
    @State private var didStartLoadingAlbumWall = false

    var body: some View {
        NavigationStack {
            Group {
                if albumWallService.didFinishLoading {
                    titlePageView
                } else {
                    loadingAlbumWallView
                }
            }
            .task {
                guard !didStartLoadingAlbumWall else { return }
                didStartLoadingAlbumWall = true
                await albumWallService.loadAlbumWallArtwork()
            }
        }
    }

    private var titlePageView: some View {
        ZStack {
            if albumWallService.albumArtworkURLs.isEmpty {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.gray.opacity(0.35),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                AlbumWallView(artworkURLs: albumWallService.albumArtworkURLs)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.58),
                    .black.opacity(0.28),
                    .black.opacity(0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 34) {
                VStack(spacing: 12) {
                    Text("Name That Tune")
                        .font(.system(size: 76, weight: .heavy, design: .rounded))
                        .shadow(radius: 18)

                    Text(albumWallService.albumArtworkURLs.isEmpty ? "Guess the song. Beat your friends." : "Guess the song. Beat your friends.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 34)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32))

                NavigationLink {
                    GameView()
                } label: {
                    Text("Start Game")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal, 54)
                        .padding(.vertical, 22)
                }
            }
        }
    }

    private var loadingAlbumWallView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.gray.opacity(0.35),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Name That Tune")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))

                ProgressView()

                Text(albumWallService.errorMessage ?? "Loading your album wall...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 760)
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 48)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
    }
}

private struct AlbumWallView: View {
    let artworkURLs: [URL]

    private let columns = Array(repeating: GridItem(.fixed(150), spacing: 18), count: 9)

    private var coverCount: Int {
        max(artworkURLs.count, 54)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(0..<coverCount, id: \.self) { index in
                        albumCoverTile(for: index)
                    }
                }
                .rotationEffect(.degrees(-6))
                .scaleEffect(1.14)
                .offset(x: -60, y: -80)
                .frame(minHeight: geometry.size.height + 220)
            }
            .disabled(true)
        }
    }

    @ViewBuilder
    private func albumCoverTile(for index: Int) -> some View {
        let artworkURL = artworkURLs[index % artworkURLs.count]

        AsyncImage(url: artworkURL) { phase in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.thinMaterial)

                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "music.note")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 14)
        .opacity(0.84)
    }
}

#Preview {
    ContentView()
}
