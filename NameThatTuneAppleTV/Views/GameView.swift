
import SwiftUI
import MusicKit

struct GameView: View {
    @StateObject private var musicService = AppleMusicService()

    @State private var gameSongs: [GameSong] = []
    @State private var currentRound: GameRound?
    @State private var answerText = ""
    @State private var submittedAnswer: String?
    @State private var roundNumber = 0
    @State private var score = 0
    @State private var lastSongPoints = 0
    @State private var lastArtistPoints = 0
    @State private var isLoadingMusic = true
    @State private var isLoadingPlaylistSongs = false
    @State private var isPlayingClip = false
    @State private var isAnswering = false
    @State private var didSetup = false

    enum FocusTarget: Hashable {
        case nextRoundButton
    }

    @FocusState private var focusedControl: FocusTarget?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            albumArtworkBackground
                .ignoresSafeArea()

            Color.black
                .opacity(submittedAnswer == nil ? 1.0 : 0.65)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                if isLoadingMusic {
                    Text("Loading Apple Music...")
                        .font(.largeTitle)
                        .bold()

                    if let errorMessage = musicService.errorMessage {
                        Text(errorMessage)
                            .font(.title3)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                } else if currentRound == nil {
                    playlistPickerView
                } else if let currentRound {
                    roundView(currentRound)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let currentRound, submittedAnswer != nil {
                answerRevealCard(currentRound)
            }
        }
        .persistentSystemOverlays(.hidden)
        .task {
            guard !didSetup else { return }
            didSetup = true
            await setupMusic()
        }
    }

    private var playlistPickerView: some View {
        VStack(spacing: 32) {
            Text("Choose a Playlist")
                .font(.largeTitle)
                .bold()

            if isLoadingPlaylistSongs {
                ProgressView()
                Text("Loading playlist songs...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else if musicService.playlists.isEmpty {
                Text("No Apple Music playlists found.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(musicService.playlists, id: \.id) { playlist in
                            Button {
                                choosePlaylist(playlist)
                            } label: {
                                Text(playlist.name)
                                    .font(.title2)
                                    .frame(width: 700)
                            }
                        }
                    }
                }
                .frame(maxHeight: 650)
            }

            if let errorMessage = musicService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func roundView(_ currentRound: GameRound) -> some View {
        VStack(spacing: 32) {
            Text("Round \(currentRound.number)")
                .font(.largeTitle)
                .bold()

            Text("Score: \(score)")
                .font(.title2)

            if let errorMessage = musicService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if isPlayingClip {
                Text("Listen...")
                    .font(.title)
                    .foregroundStyle(.secondary)
            } else if submittedAnswer == nil {
                Text("Say the song title and artist")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Answer revealed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if isAnswering && submittedAnswer == nil {
                FocusableTextField(
                    text: $answerText,
                    placeholder: "Hold Siri button and speak answer",
                    becomeFirstResponder: true,
                    onSubmit: {
                        submitAnswer()
                    }
                )
                .frame(width: 700, height: 70)
                .id(currentRound.number)
            } else if !answerText.isEmpty {
                Text(answerText)
                    .font(.title2)
                    .padding()
                    .frame(width: 700, height: 70)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let submittedAnswer {
                let points = scoreAnswer(submittedAnswer, currentRound: currentRound)

                Text(points.total > 0
                     ? "You got \(points.total)/20 points!"
                     : "Wrong! It was \(currentRound.correctSong.title) by \(currentRound.correctSong.artist).")
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Song: \(lastSongPoints)/10  •  Artist: \(lastArtistPoints)/10")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button("Next Round") {
                    startNewRound()
                }
                .font(.title2)
                .focused($focusedControl, equals: .nextRoundButton)
            }
        }
    }

    private func answerRevealCard(_ currentRound: GameRound) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Now Playing")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(currentRound.correctSong.title)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.trailing)

            Text(currentRound.correctSong.artist)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 40)
        .padding(.trailing, 40)
    }

    @ViewBuilder
    private var albumArtworkBackground: some View {
        if submittedAnswer != nil,
           let artworkURL = currentRound?.correctSong.musicKitSong?.artwork?.url(width: 1920, height: 1080) {
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.black
                }
            }
        } else {
            Color.black
        }
    }

    private func setupMusic() async {
        isLoadingMusic = true

        await musicService.requestAuthorization()
        await musicService.loadLibraryPlaylists()

        isLoadingMusic = false
    }

    private func choosePlaylist(_ playlist: Playlist) {
        guard !isLoadingPlaylistSongs else { return }

        isLoadingPlaylistSongs = true
        musicService.errorMessage = nil

        Task {
            await musicService.loadSongs(from: playlist)
            gameSongs = musicService.getGameSongs()

            score = 0
            roundNumber = 0
            currentRound = nil
            answerText = ""
            submittedAnswer = nil
            lastSongPoints = 0
            lastArtistPoints = 0
            isLoadingPlaylistSongs = false

            if gameSongs.isEmpty {
                musicService.errorMessage = "No playable songs found in \(playlist.name)."
            } else {
                startNewRound()
            }
        }
    }

    private func startNewRound() {
        let nextRoundNumber = roundNumber + 1
        let engine = GameEngine(songs: gameSongs.isEmpty ? nil : gameSongs)
        let newRound = engine.generateRound(number: nextRoundNumber)

        focusedControl = nil
        currentRound = newRound
        answerText = ""
        submittedAnswer = nil
        lastSongPoints = 0
        lastArtistPoints = 0
        roundNumber = nextRoundNumber
        isPlayingClip = true
        isAnswering = false

        Task {
            await playClipThenAnswer(for: newRound.correctSong)
        }
    }

    private func playClipThenAnswer(for song: GameSong) async {
        if song.musicKitSong != nil {
            await musicService.playPreviewClip(for: song, seconds: 15)
        } else {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        isPlayingClip = false
        isAnswering = true
    }

    private func submitAnswer() {
        let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard submittedAnswer == nil, !cleaned.isEmpty else {
            return
        }

        submittedAnswer = cleaned
        isAnswering = false

        if let currentRound {
            let points = scoreAnswer(cleaned, currentRound: currentRound)
            lastSongPoints = points.song
            lastArtistPoints = points.artist
            score += points.total

            Task {
                await musicService.playPreviewClip(for: currentRound.correctSong, seconds: 30)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            focusedControl = .nextRoundButton
        }
    }

    private func scoreAnswer(_ answer: String, currentRound: GameRound) -> (song: Int, artist: Int, total: Int) {
        let titleToMatch = removeParentheses(from: currentRound.correctSong.title)
        let artistToMatch = currentRound.correctSong.artist

        let songMatches = matchesAnswer(answer, target: titleToMatch)
        let artistMatches = matchesAnswer(answer, target: artistToMatch)

        let songPoints = songMatches ? 10 : 0
        let artistPoints = artistMatches ? 10 : 0

        return (songPoints, artistPoints, songPoints + artistPoints)
    }

    private func matchesAnswer(_ answer: String, target: String) -> Bool {
        let normalizedAnswer = normalize(answer)
        let normalizedTarget = normalize(target)

        guard !normalizedAnswer.isEmpty, !normalizedTarget.isEmpty else {
            return false
        }

        let compactAnswer = compactNormalize(answer)
        let compactTarget = compactNormalize(target)

        if normalizedAnswer.contains(normalizedTarget) || compactAnswer.contains(compactTarget) {
            return true
        }

        let phoneticAnswer = phoneticNormalize(answer)
        let phoneticTarget = phoneticNormalize(target)
        let compactPhoneticAnswer = phoneticAnswer.replacingOccurrences(of: " ", with: "")
        let compactPhoneticTarget = phoneticTarget.replacingOccurrences(of: " ", with: "")

        if phoneticAnswer.contains(phoneticTarget) || compactPhoneticAnswer.contains(compactPhoneticTarget) {
            return true
        }

        if isCloseEnough(compactPhoneticAnswer, compactPhoneticTarget) {
            return true
        }

        return fuzzyPhraseMatch(answer: normalizedAnswer, target: normalizedTarget)
    }

    private func fuzzyPhraseMatch(answer: String, target: String) -> Bool {
        let answerWords = answer.split(separator: " ").map(String.init)
        let targetWords = target.split(separator: " ").map(String.init)

        guard !answerWords.isEmpty, !targetWords.isEmpty else {
            return false
        }

        if answerWords.count < targetWords.count {
            let compactAnswer = answer.replacingOccurrences(of: " ", with: "")
            let compactTarget = target.replacingOccurrences(of: " ", with: "")
            return isCloseEnough(compactAnswer, compactTarget)
        }

        for startIndex in 0...(answerWords.count - targetWords.count) {
            let answerWindow = answerWords[startIndex..<(startIndex + targetWords.count)].joined(separator: "")
            let compactTarget = targetWords.joined(separator: "")

            if isCloseEnough(answerWindow, compactTarget) {
                return true
            }
        }

        return false
    }

    private func isCloseEnough(_ guess: String, _ target: String) -> Bool {
        guard !guess.isEmpty, !target.isEmpty else {
            return false
        }

        let distance = levenshteinDistance(guess, target)
        let targetLength = target.count

        let allowedDistance: Int
        if targetLength <= 4 {
            allowedDistance = 0
        } else if targetLength <= 8 {
            allowedDistance = 1
        } else if targetLength <= 14 {
            allowedDistance = 2
        } else {
            allowedDistance = 3
        }

        return distance <= allowedDistance
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)

        if lhsArray.isEmpty { return rhsArray.count }
        if rhsArray.isEmpty { return lhsArray.count }

        var previousRow = Array(0...rhsArray.count)
        var currentRow = Array(repeating: 0, count: rhsArray.count + 1)

        for lhsIndex in 1...lhsArray.count {
            currentRow[0] = lhsIndex

            for rhsIndex in 1...rhsArray.count {
                let deleteCost = previousRow[rhsIndex] + 1
                let insertCost = currentRow[rhsIndex - 1] + 1
                let replaceCost = previousRow[rhsIndex - 1] + (lhsArray[lhsIndex - 1] == rhsArray[rhsIndex - 1] ? 0 : 1)

                currentRow[rhsIndex] = min(deleteCost, insertCost, replaceCost)
            }

            previousRow = currentRow
        }

        return previousRow[rhsArray.count]
    }

    private func removeParentheses(from text: String) -> String {
        text.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
    }

    private func normalize(_ text: String) -> String {
        let cleaned = text
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "feat.", with: " ")
            .replacingOccurrences(of: "featuring", with: " ")
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func compactNormalize(_ text: String) -> String {
        normalize(text).replacingOccurrences(of: " ", with: "")
    }

    private func phoneticNormalize(_ text: String) -> String {
        normalize(text)
            .split(separator: " ")
            .map { phoneticWord(String($0)) }
            .joined(separator: " ")
    }

    private func phoneticWord(_ word: String) -> String {
        var result = word

        result = result.replacingOccurrences(of: "augh", with: "o")
        result = result.replacingOccurrences(of: "ough", with: "o")
        result = result.replacingOccurrences(of: "gh", with: "")
        result = result.replacingOccurrences(of: "ph", with: "f")
        result = result.replacingOccurrences(of: "ck", with: "k")
        result = result.replacingOccurrences(of: "qu", with: "k")
        result = result.replacingOccurrences(of: "oa", with: "o")
        result = result.replacingOccurrences(of: "ow", with: "o")
        result = result.replacingOccurrences(of: "x", with: "ks")
        result = result.replacingOccurrences(of: "z", with: "s")
        result = result.replacingOccurrences(of: "c", with: "k")

        if result.hasSuffix("er") {
            result.removeLast(2)
            result += "a"
        }

        if result.hasSuffix("ah") {
            result.removeLast(2)
            result += "a"
        }

        if result.hasSuffix("ie") {
            result.removeLast(2)
            result += "i"
        }

        result = collapseRepeatedLetters(result)

        if result.hasSuffix("l"), let previousCharacter = result.dropLast().last, "aeiou".contains(previousCharacter) {
            result.removeLast()
        }

        return result
    }

    private func collapseRepeatedLetters(_ text: String) -> String {
        var collapsed = ""
        var previous: Character?

        for character in text {
            if character != previous {
                collapsed.append(character)
            }
            previous = character
        }

        return collapsed
    }
}

#Preview {
    GameView()
}
