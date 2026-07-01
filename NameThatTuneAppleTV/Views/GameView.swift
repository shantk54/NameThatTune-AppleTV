
import SwiftUI
import MusicKit

struct GameView: View {
    let albumArtworks: [Artwork]
    let onStartGame: () -> Void
    let onReturnToTitle: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var musicService = AppleMusicService()

    @State private var gameSongs: [GameSong] = []
    @State private var usedSongIDs = Set<String>()
    @State private var currentRound: GameRound?
    @State private var answerText = ""
    @State private var submittedAnswer: String?
    @State private var roundNumber = 0
    @State private var score = 0
    @State private var playerScores: [Int] = []
    @State private var selectedPlayerCount: Int?
    @State private var selectedRoundCount: Int?
    @State private var selectedDifficulty: GameDifficulty?
    @State private var isGameOver = false
    @State private var showQuitGameConfirmation = false
    @State private var hasStartedGameSession = false
    @State private var lastSongPoints = 0
    @State private var lastArtistPoints = 0
    @State private var isLoadingMusic = true
    @State private var isLoadingPlaylists = false
    @State private var isLoadingPlaylistSongs = false
    @State private var playlistSearchText = ""
    @State private var isPlayingClip = false
    @State private var isAnswering = false
    @State private var didSetup = false
    @State private var revealPlaybackTask: Task<Void, Never>?
    @State private var clipPlaybackTask: Task<Void, Never>?
    @State private var playbackSessionID = UUID()
    @State private var displayedAlbumArtworks: [Artwork] = []

    init(
        albumArtworks: [Artwork] = [],
        onStartGame: @escaping () -> Void = {},
        onReturnToTitle: @escaping () -> Void = {}
    ) {
        self.albumArtworks = albumArtworks
        self.onStartGame = onStartGame
        self.onReturnToTitle = onReturnToTitle
    }

    enum FocusTarget: Hashable {
        case playerCount(Int)
        case difficulty(GameDifficulty)
        case roundCount(Int)
        case nextRoundButton
    }

    enum GameDifficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"

        var id: String { rawValue }

        var clipSeconds: UInt64 {
            switch self {
            case .easy:
                return 15
            case .medium:
                return 10
            case .hard:
                return 5
            case .expert:
                return 2
            }
        }
    }


    @FocusState private var focusedControl: FocusTarget?

    private var currentPlayerIndex: Int {
        guard let selectedPlayerCount, selectedPlayerCount > 0 else {
            return 0
        }

        return max(roundNumber - 1, 0) % selectedPlayerCount
    }

    private var currentPlayerNumber: Int {
        currentPlayerIndex + 1
    }

    private var displayedRoundNumber: Int {
        guard let selectedPlayerCount, selectedPlayerCount > 0 else {
            return max(roundNumber, 1)
        }

        return ((max(roundNumber, 1) - 1) / selectedPlayerCount) + 1
    }

    private var totalTurnCount: Int {
        (selectedPlayerCount ?? 0) * (selectedRoundCount ?? 0)
    }

    private var scoreBoxWidth: CGFloat {
        switch playerScores.count {
        case 1:
            return 180
        case 2:
            return 150
        case 3:
            return 130
        default:
            return 115
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if shouldShowAlbumWallBackground, !displayedAlbumArtworks.isEmpty {
                AlbumWallView(artworks: displayedAlbumArtworks)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .black.opacity(0.62),
                        .black.opacity(0.34),
                        .black.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                albumArtworkBackground
                    .ignoresSafeArea()
            }

            VStack(spacing: 40) {
                if isLoadingMusic {
                    ProgressView()

                    Text("GameView: Checking Apple Music access...")
                        .font(.largeTitle)
                        .bold()

                    Text("This is the gameplay screen, not the album-wall title screen.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let errorMessage = musicService.errorMessage {
                        Text(errorMessage)
                            .font(.title3)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                } else if isGameOver {
                    gameOverView
                } else if selectedPlayerCount == nil || selectedRoundCount == nil || selectedDifficulty == nil {
                    gameOptionsView
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
        .navigationBarBackButtonHidden(true)
        .onExitCommand {
            handleBackButton()
        }
        .alert("Quit Game?", isPresented: $showQuitGameConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                quitCurrentGame()
            }
        } message: {
            Text("Your current game progress will be lost.")
        }
        .onAppear {
            refreshDisplayedAlbumWall()
        }
        .onDisappear {
            stopAllPlayback()
        }
        .task {
            guard !didSetup else { return }
            didSetup = true
            await setupMusic()
        }
    }

    private var gameOptionsView: some View {
        VStack(spacing: 34) {
            VStack(spacing: 10) {
                Text("Select Game Settings")
                    .font(.largeTitle)
                    .bold()
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .background(.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )

            VStack(spacing: 16) {
                Text("Players:")
                    .font(.title2)
                    .bold()

                HStack(spacing: 90) {
                    ForEach([1, 2, 3, 4], id: \.self) { playerCount in
                        optionButton(
                            title: "\(playerCount)",
                            subtitle: "",
                            isSelected: selectedPlayerCount == playerCount
                        ) {
                            selectedPlayerCount = playerCount
                            selectedDifficulty = nil
                            selectedRoundCount = nil
                            playerScores = Array(repeating: 0, count: playerCount)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedControl = .difficulty(.easy)
                            }
                        }
                        .focused($focusedControl, equals: .playerCount(playerCount))
                    }
                }
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 18)
            .background(.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )

            if selectedPlayerCount != nil {
                VStack(spacing: 16) {
                    Text("Difficulty:")
                        .font(.title2)
                        .bold()

                    HStack(spacing: 90) {
                        ForEach(GameDifficulty.allCases) { difficulty in
                            optionButton(
                                title: difficulty.rawValue,
                                subtitle: "\(difficulty.clipSeconds)s clip",
                                isSelected: selectedDifficulty == difficulty,
                                fixedWidth: 220
                            ) {
                                selectedDifficulty = difficulty
                                selectedRoundCount = nil

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    focusedControl = .roundCount(3)
                                }
                            }
                            .focused($focusedControl, equals: .difficulty(difficulty))
                        }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 18)
                .background(.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if selectedDifficulty != nil {
                VStack(spacing: 16) {
                    Text("Rounds:")
                        .font(.title2)
                        .bold()

                    HStack(spacing: 90) {
                        ForEach([3, 5, 10], id: \.self) { roundCount in
                            optionButton(
                                title: "\(roundCount)",
                                subtitle: "",
                                isSelected: selectedRoundCount == roundCount
                            ) {
                                selectedRoundCount = roundCount
                            }
                            .focused($focusedControl, equals: .roundCount(roundCount))
                        }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 18)
                .background(.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if selectedPlayerCount != nil && selectedRoundCount != nil && selectedDifficulty != nil {
                Text("Continue by choosing a playlist.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 18)
                    .background(.black.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPlayerCount)
        .animation(.easeInOut(duration: 0.25), value: selectedDifficulty)
        .onChange(of: focusedControl) { newFocus in
            keepFocusInCurrentSettingsSection(newFocus)
        }
    }

    private func optionButton(title: String, subtitle: String, isSelected: Bool, fixedWidth: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 12)
            .frame(minWidth: fixedWidth ?? 170, minHeight: 96)
            .background(isSelected ? .thinMaterial : .regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private var playlistPickerView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Choose a Playlist")
                    .font(.largeTitle)
                    .bold()

                Text("\(selectedPlayerCount ?? 1) Player Game • \(selectedRoundCount ?? 0) Rounds • \(selectedDifficulty?.rawValue ?? "")")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if isLoadingPlaylistSongs {
                ProgressView()
                Text("Loading playlist songs...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else if isLoadingPlaylists && musicService.playlists.isEmpty {
                ProgressView()
                Text("Loading playlists...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else if musicService.playlists.isEmpty {
                Text("No Apple Music playlists found.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 18) {
                    TextField("Search playlists", text: $playlistSearchText)
                        .font(.title3)
                        .padding(18)
                        .frame(width: 720)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if filteredPlaylists.isEmpty {
                        Text("No playlists match \"\(playlistSearchText)\".")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.fixed(360), spacing: 56),
                                    GridItem(.fixed(360), spacing: 56),
                                    GridItem(.fixed(360), spacing: 56),
                                    GridItem(.fixed(360), spacing: 56)
                                ],
                                spacing: 48
                            ) {
                                ForEach(filteredPlaylists, id: \.id) { playlist in
                                    Button {
                                        choosePlaylist(playlist)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(.thinMaterial)

                                                if let artwork = playlist.artwork {
                                                    ArtworkImage(artwork, width: 320, height: 320)
                                                        .scaledToFit()
                                                        .frame(width: 320, height: 320)
                                                } else {
                                                    Image(systemName: "music.note.list")
                                                        .font(.largeTitle)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(width: 320, height: 320)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))

                                            Text(playlist.name)
                                                .font(.headline)
                                                .bold()
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            Text("Playlist")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 320, height: 420, alignment: .topLeading)
                                        .padding(16)
                                        .background(.black.opacity(0.58))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 28)
                        }
                        .frame(maxHeight: 700)
                    }
                }
            }

            if let errorMessage = musicService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var filteredPlaylists: [Playlist] {
        let cleanedSearch = playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedSearch.isEmpty else {
            return musicService.playlists
        }

        return musicService.playlists.filter { playlist in
            playlist.name.localizedCaseInsensitiveContains(cleanedSearch)
        }
    }

    private func roundView(_ currentRound: GameRound) -> some View {
        Group {
            if submittedAnswer != nil {
                EmptyView()
            } else {
                VStack(spacing: 34) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Round \(displayedRoundNumber) of \(selectedRoundCount ?? 0)")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Player \(currentPlayerNumber)'s Turn")
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                                .lineLimit(1)
                        }

                        Spacer()

                        scoreBoardView
                    }
                    .padding(.horizontal, 70)
                    .padding(.top, 34)

                    Spacer(minLength: 12)

                    mysterySongCard

                    VStack(spacing: 18) {
                        if let errorMessage = musicService.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        if isPlayingClip {
                            Text("Listen carefully...")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text("\(selectedDifficulty?.clipSeconds ?? 15)-second clip")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Make your guess")
                                .font(.system(size: 34, weight: .bold, design: .rounded))

                            Text("Hold the Siri button and say the song title and artist")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        if isAnswering {
                            FocusableTextField(
                                text: $answerText,
                                placeholder: "Enter Song Title and Artist",
                                becomeFirstResponder: true,
                                onSubmit: {
                                    submitAnswer()
                                }
                            )
                            .frame(width: 860, height: 78)
                            .padding(.horizontal, 20)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .id(currentRound.number)
                        } else if !answerText.isEmpty {
                            Text(answerText)
                                .font(.title2)
                                .padding()
                                .frame(width: 860, height: 78)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(.bottom, 54)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var mysterySongCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(.white.opacity(0.16), lineWidth: 2)
                )
                .shadow(radius: 32)

            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.thinMaterial)
                        .frame(width: 360, height: 150)

                    if isPlayingClip {
                        AnimatedWaveformView()
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 78, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                VStack(spacing: 10) {
                    Text(isPlayingClip ? "Mystery Song Playing" : "Ready for Your Answer")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                }
            }
            .padding(44)
        }
        .frame(width: 760, height: 380)
    }

    private var scoreBoardView: some View {
        HStack(spacing: playerScores.count >= 4 ? 12 : 16) {
            if playerScores.isEmpty {
                Text("Score: \(score)")
                    .font(.title2)
            } else {
                ForEach(playerScores.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text("P\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("\(playerScores[index])")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 14)
                    .frame(width: scoreBoxWidth, height: 82)
                    .background(index == currentPlayerIndex ? .thinMaterial : .regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var gameOverView: some View {
        VStack(spacing: 32) {
            Text("Game Over")
                .font(.largeTitle)
                .bold()

            VStack(spacing: 14) {
                ForEach(playerScores.indices, id: \.self) { index in
                    HStack(spacing: 20) {
                        Text("Player \(index + 1)")
                            .font(.title2)
                            .frame(width: 220, alignment: .leading)

                        Text("\(playerScores[index]) points")
                            .font(.title2)
                            .bold()
                    }
                    .padding()
                    .frame(width: 520)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Button("Back to Title") {
                resetGame()
                refreshDisplayedAlbumWall()
                onReturnToTitle()
                dismiss()
            }
            .font(.title2)
        }
    }

    private func answerRevealCard(_ currentRound: GameRound) -> some View {
        VStack(spacing: 36) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Round \(displayedRoundNumber) of \(selectedRoundCount ?? 0)")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                         .clipShape(Capsule())

                    Text("Player \(currentPlayerNumber)'s Reveal")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                scoreBoardView
            }
            .padding(.horizontal, 80)
            .padding(.top, 40)

            Spacer()

            HStack(spacing: 56) {
                albumArtworkCard(for: currentRound)

                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentRound.correctSong.artist)
                            .font(.title2)
                            .bold()

                        Text(currentRound.correctSong.title)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                    }

                    HStack(spacing: 14) {
                        correctnessPill(label: "Song", points: lastSongPoints)
                        correctnessPill(label: "Artist", points: lastArtistPoints)
                    }

                    Text("You Said: \(submittedAnswer ?? "")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: 820, alignment: .leading)

                    Button(roundNumber >= totalTurnCount ? "Show Final Scores" : "Next Turn") {
                        if roundNumber >= totalTurnCount {
                            finishGame()
                        } else {
                            startNewRound()
                        }
                    }
                    .font(.title2)
                    .focused($focusedControl, equals: .nextRoundButton)
                    .padding(.top, 10)
                }
                .frame(width: 820, alignment: .leading)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private func albumArtworkCard(for currentRound: GameRound) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.regularMaterial)
                .shadow(radius: 30)

            if let artworkURL = currentRound.correctSong.musicKitSong?.artwork?.url(width: 700, height: 700) {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "music.note")
                            .font(.system(size: 90))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 90))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 380, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func correctnessPill(label: String, points: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: points > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text("\(label): \(points)/10")
                .bold()
        }
        .font(.headline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(points > 0 ? .green.opacity(0.85) : .red.opacity(0.75))
        .clipShape(Capsule())
    }

    private var answerResultColor: Color {
        switch (lastSongPoints > 0, lastArtistPoints > 0) {
        case (true, true):
            return .green
        case (true, false), (false, true):
            return .yellow
        case (false, false):
            return .red
        }
    }

    
    private var shouldShowAlbumWallBackground: Bool {
        !isLoadingMusic && !isGameOver && currentRound == nil && (selectedPlayerCount == nil || selectedRoundCount == nil || selectedDifficulty == nil)
    }
    
    private func refreshDisplayedAlbumWall() {
        displayedAlbumArtworks = albumArtworks
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
                        .blur(radius: 22)
                        .opacity(0.55)
                        .overlay(.black.opacity(0.18))
                default:
                    Color.black
                }
            }
        } else {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.gray.opacity(0.35),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func keepFocusInCurrentSettingsSection(_ newFocus: FocusTarget?) {
        guard currentRound == nil,
              !isGameOver,
              selectedPlayerCount == nil || selectedDifficulty == nil || selectedRoundCount == nil else {
            return
        }

        guard let newFocus else {
            restoreCurrentSettingsFocus()
            return
        }

        switch newFocus {
        case .playerCount:
            if selectedPlayerCount != nil {
                restoreCurrentSettingsFocus()
            }
        case .difficulty:
            if selectedPlayerCount == nil || selectedDifficulty != nil {
                restoreCurrentSettingsFocus()
            }
        case .roundCount:
            if selectedDifficulty == nil || selectedRoundCount != nil {
                restoreCurrentSettingsFocus()
            }
        case .nextRoundButton:
            restoreCurrentSettingsFocus()
        }
    }

    private func restoreCurrentSettingsFocus() {
        DispatchQueue.main.async {
            if selectedPlayerCount == nil {
                focusedControl = .playerCount(1)
            } else if selectedDifficulty == nil {
                focusedControl = .difficulty(.easy)
            } else if selectedRoundCount == nil {
                focusedControl = .roundCount(3)
            }
        }
    }

    private func handleBackButton() {
        guard !isLoadingMusic else {
            return
        }

        if hasStartedGameSession {
            showQuitGameConfirmation = true
            return
        }

        if selectedRoundCount != nil {
            selectedRoundCount = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedControl = .roundCount(3)
            }
        } else if selectedDifficulty != nil {
            selectedDifficulty = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let selectedPlayerCount {
                    focusedControl = .playerCount(selectedPlayerCount)
                }
            }
        } else if selectedPlayerCount != nil {
            selectedPlayerCount = nil
            playerScores = []
        } else {
            dismiss()
        }
    }

    private func stopAllPlayback() {
        let hadActivePlayback = clipPlaybackTask != nil || revealPlaybackTask != nil || isPlayingClip

        playbackSessionID = UUID()
        clipPlaybackTask?.cancel()
        clipPlaybackTask = nil
        revealPlaybackTask?.cancel()
        revealPlaybackTask = nil

        if hadActivePlayback {
            musicService.stop()
        }

        isPlayingClip = false
    }

    private func quitCurrentGame() {
        stopAllPlayback()
        showQuitGameConfirmation = false
        currentRound = nil
        answerText = ""
        submittedAnswer = nil
        roundNumber = 0
        usedSongIDs.removeAll()
        score = 0
        playerScores = []
        selectedPlayerCount = nil
        selectedRoundCount = nil
        selectedDifficulty = nil
        isGameOver = false
        hasStartedGameSession = false
        lastSongPoints = 0
        lastArtistPoints = 0
        isPlayingClip = false
        isAnswering = false
        refreshDisplayedAlbumWall()
        onReturnToTitle()
        dismiss()
    }

    private func setupMusic() async {
        isLoadingMusic = true

        let currentStatus = MusicAuthorization.currentStatus
        musicService.authorizationStatus = currentStatus

        if currentStatus == .notDetermined {
            await musicService.requestAuthorization()
        }

        isLoadingMusic = false

        guard musicService.authorizationStatus == .authorized else {
            musicService.errorMessage = "Apple Music access is required to choose playlists."
            return
        }

        isLoadingPlaylists = true
        await musicService.loadLibraryPlaylists()
        isLoadingPlaylists = false
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
            usedSongIDs.removeAll()
            currentRound = nil
            answerText = ""
            submittedAnswer = nil
            playlistSearchText = ""
            lastSongPoints = 0
            lastArtistPoints = 0
            isGameOver = false
            isLoadingPlaylistSongs = false

            if let selectedPlayerCount {
                playerScores = Array(repeating: 0, count: selectedPlayerCount)
            }

            if gameSongs.isEmpty {
                musicService.errorMessage = "No playable songs found in \(playlist.name)."
                return
            }

            let requiredSongCount = totalTurnCount
            guard gameSongs.count >= requiredSongCount else {
                musicService.errorMessage = "This playlist only has \(gameSongs.count) recognized song\(gameSongs.count == 1 ? "" : "s"), but this game needs \(requiredSongCount). Choose a playlist with more Apple Music-recognized songs or lower the player/round count."
                return
            }

            onStartGame()
            hasStartedGameSession = true
            startNewRound()
        }
    }

    private func startNewRound() {
        guard roundNumber < totalTurnCount else {
            finishGame()
            return
        }
        stopAllPlayback()
        let nextRoundNumber = roundNumber + 1
        let availableSongs = gameSongs.filter { !usedSongIDs.contains($0.id) }

        guard !availableSongs.isEmpty else {
            finishGame()
            return
        }

        let engine = GameEngine(songs: availableSongs)
        let newRound = engine.generateRound(number: nextRoundNumber)
        usedSongIDs.insert(newRound.correctSong.id)

        focusedControl = nil
        currentRound = newRound
        answerText = ""
        submittedAnswer = nil
        lastSongPoints = 0
        lastArtistPoints = 0
        roundNumber = nextRoundNumber
        isPlayingClip = true
        isAnswering = false

        let sessionID = playbackSessionID
        clipPlaybackTask = Task {
            await playClipThenAnswer(for: newRound.correctSong, sessionID: sessionID)
        }
    }

    private func playClipThenAnswer(for song: GameSong, sessionID: UUID) async {
        if song.musicKitSong != nil {
            await musicService.playPreviewClip(for: song, seconds: selectedDifficulty?.clipSeconds ?? 15)
        } else {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        guard !Task.isCancelled, sessionID == playbackSessionID else {
            return
        }

        clipPlaybackTask = nil
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

            if playerScores.indices.contains(currentPlayerIndex) {
                playerScores[currentPlayerIndex] += points.total
            }

            stopAllPlayback()
            let sessionID = playbackSessionID
            let revealSong = currentRound.correctSong
            revealPlaybackTask = Task {
                guard !Task.isCancelled, sessionID == playbackSessionID else {
                    return
                }

                await musicService.playPreviewClip(for: revealSong, seconds: 30)

                guard !Task.isCancelled, sessionID == playbackSessionID else {
                    return
                }

                revealPlaybackTask = nil
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            focusedControl = .nextRoundButton
        }
    }


    private func finishGame() {
        stopAllPlayback()
        currentRound = nil
        submittedAnswer = nil
        answerText = ""
        isPlayingClip = false
        isAnswering = false
        isGameOver = true
    }

    private func resetGame() {
        stopAllPlayback()
        gameSongs = []
        usedSongIDs.removeAll()
        currentRound = nil
        answerText = ""
        submittedAnswer = nil
        roundNumber = 0
        score = 0
        playerScores = []
        selectedPlayerCount = nil
        selectedRoundCount = nil
        selectedDifficulty = nil
        isGameOver = false
        hasStartedGameSession = false
        lastSongPoints = 0
        lastArtistPoints = 0
        isPlayingClip = false
        isAnswering = false
        refreshDisplayedAlbumWall()
    }

    private func scoreAnswer(_ answer: String, currentRound: GameRound) -> (song: Int, artist: Int, total: Int) {
        let artistToMatch = currentRound.correctSong.artist

        let songMatches = titleCandidates(for: currentRound.correctSong.title).contains { candidate in
            matchesAnswer(answer, target: candidate)
        }
        let artistMatches = matchesAnswer(answer, target: artistToMatch)

        let songPoints = songMatches ? 10 : 0
        let artistPoints = artistMatches ? 10 : 0

        return (songPoints, artistPoints, songPoints + artistPoints)
    }

    private func titleCandidates(for title: String) -> [String] {
        let cleanedTitle = removeParentheses(from: title)
        var candidates = [cleanedTitle]

        let slashParts = cleanedTitle
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidSlashTitleCandidate($0) }

        candidates.append(contentsOf: slashParts)

        var seen = Set<String>()
        return candidates.filter { candidate in
            let normalizedCandidate = normalize(candidate)
            guard !normalizedCandidate.isEmpty, !seen.contains(normalizedCandidate) else {
                return false
            }

            seen.insert(normalizedCandidate)
            return true
        }
    }

    private func isValidSlashTitleCandidate(_ title: String) -> Bool {
        let normalizedTitle = normalize(title)
        let words = normalizedTitle.split(separator: " ")

        guard !normalizedTitle.isEmpty else {
            return false
        }

        if words.count >= 2 {
            return true
        }

        return normalizedTitle.count >= 6
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

private struct AnimatedWaveformView: View {
    @State private var isAnimating = false

    private let barCount = 22

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.9))
                    .frame(width: 9, height: isAnimating ? animatedHeight(for: index) : 28)
                    .animation(
                        .easeInOut(duration: animationDuration(for: index))
                            .repeatForever(autoreverses: true)
                            .delay(animationDelay(for: index)),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 300, height: 120)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }

    private func animatedHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [36, 78, 52, 106, 64, 92, 44, 118, 70, 96, 56]
        return pattern[index % pattern.count]
    }

    private func animationDuration(for index: Int) -> Double {
        0.42 + Double(index % 5) * 0.08
    }

    private func animationDelay(for index: Int) -> Double {
        Double(index % 7) * 0.045
    }
}

#Preview {
    GameView()
}

 
