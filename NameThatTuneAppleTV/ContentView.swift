import SwiftUI
import MusicKit

struct ContentView: View {
    @StateObject private var albumWallService = AlbumWallService()
    @State private var didStartLoadingAlbumWall = false
    @State private var isShowingGame = false

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
                await albumWallService.loadAlbumWallArtwork(targetArtworkCount: 45)
            }
        }
    }

    private var titlePageView: some View {
        ZStack {
            if albumWallService.albumArtworks.isEmpty {
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
                AlbumWallView(artworks: albumWallService.albumArtworks)
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

                    Text("Guess The Song. Beat Your Friends.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 34)
                .background(.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 32))

                Button {
                    DispatchQueue.main.async {
                        isShowingGame = true
                    }
                } label: {
                    Text("Start Game")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal, 54)
                        .padding(.vertical, 22)
                }
            }
        }
        .navigationDestination(isPresented: $isShowingGame) {
            GameView(
                albumArtworks: albumWallService.albumArtworks,
                onStartGame: {
                    albumWallService.stopLobbyMusic()
                },
                onReturnToTitle: {
                    albumWallService.refreshAlbumWallArtwork()
                    Task {
                        await albumWallService.playRandomLobbyMusic()
                    }
                }
            )
        }
        .onAppear {
            Task {
                await albumWallService.playRandomLobbyMusic()
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

struct AlbumWallView: View {
    let artworks: [Artwork]

    private let columnCount = 9
    private let rowCount = 5


    private var coverCount: Int {
        columnCount * rowCount
    }

    var body: some View {
        GeometryReader { geometry in
            let coverSize = min(
                geometry.size.width / CGFloat(columnCount),
                geometry.size.height / CGFloat(rowCount)
            )
            let columns = Array(repeating: GridItem(.fixed(coverSize), spacing: 0), count: columnCount)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<coverCount, id: \.self) { index in
                    albumCoverTile(for: index, coverSize: coverSize)
                }
            }
            .frame(
                width: coverSize * CGFloat(columnCount),
                height: coverSize * CGFloat(rowCount)
            )
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    @ViewBuilder
    private func albumCoverTile(for index: Int, coverSize: CGFloat) -> some View {
        let artwork = artworks[index % artworks.count]

        ZStack {
            Color.black

            ArtworkImage(artwork, width: coverSize, height: coverSize)
                .scaledToFit()
                .frame(width: coverSize, height: coverSize)
        }
        .frame(width: coverSize, height: coverSize)
        .clipped()
        .opacity(0.88)
    }
}

#Preview {
    ContentView()
}
