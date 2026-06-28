import Foundation
import MusicKit
import Combine

@MainActor
final class AlbumWallService: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var albumArtworkURLs: [URL] = []
    @Published var isLoading = false
    @Published var didFinishLoading = false
    @Published var errorMessage: String?

    func loadAlbumWallArtwork() async {
        isLoading = true
        didFinishLoading = false
        errorMessage = nil

        authorizationStatus = await MusicAuthorization.request()

        guard authorizationStatus == .authorized else {
            albumArtworkURLs = []
            isLoading = false
            didFinishLoading = true
            errorMessage = "Apple Music access is required to show your album wall."
            return
        }

        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 100

            let response = try await request.response()
            albumArtworkURLs = uniqueArtworkURLs(from: Array(response.items))
            isLoading = false
            didFinishLoading = true
        } catch {
            albumArtworkURLs = []
            isLoading = false
            didFinishLoading = true
            errorMessage = "Failed to load album artwork: \(error.localizedDescription)"
        }
    }

    private func uniqueArtworkURLs(from songs: [Song]) -> [URL] {
        var seenURLs: Set<URL> = []

        return songs.compactMap { song in
            guard let artworkURL = song.artwork?.url(width: 400, height: 400), !seenURLs.contains(artworkURL) else {
                return nil
            }

            seenURLs.insert(artworkURL)
            return artworkURL
        }
    }
}
