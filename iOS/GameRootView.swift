//
//  GameRootView.swift
//  BChess (iOS)
//
//  The iOS shell: the app opens straight onto a game of the library, saves it as it changes, and
//  lists, imports, shares and deletes games.
//

import SwiftUI
import UniformTypeIdentifiers

/// A game as standard PGN, for the share sheet.
struct PGNExport: Transferable {
    let text: String
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pgn) { export in
            Data(export.text.utf8)
        }
        .suggestedFileName { $0.name + ".pgn" }
    }
}

/// A switch of game that waits for the user to decide about unsaved changes.
private enum PendingSwitch: Identifiable {
    case open(GameFile)
    case create(GamePlayer, GamePlayer)
    case importFile(URL)

    var id: String {
        switch self {
        case .open(let file): return "open \(file.url)"
        case .create: return "create"
        case .importFile(let url): return "import \(url)"
        }
    }
}

struct GameRootView: View {
    let library: GameLibrary

    @State private var shell: GameShell?
    @State private var launchError: String?

    var body: some View {
        Group {
            if let shell {
                GameView(shell: shell)
            } else if let launchError {
                ContentUnavailableView("Couldn't open your games", systemImage: "exclamationmark.triangle", description: Text(launchError))
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard shell == nil else { return }
            do {
                shell = try GameShell(library: library)
            } catch {
                launchError = error.localizedDescription
            }
        }
    }
}

/// The sheets of the game screen that edit the players.
private enum PlayersSheet: String, Identifiable {
    case newGame
    case players

    var id: String { rawValue }
}

private struct GameView: View {
    let shell: GameShell

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showEngine") private var showEngine = false
    @State private var showGames = false
    @State private var showSettings = false
    @State private var newGameAfterGames = false
    @State private var playersSheet: PlayersSheet?
    @State private var pending: PendingSwitch?
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            ContentView(session: shell.session)
            .id(shell.current.url)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Walnut.background, for: .navigationBar, .bottomBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showGames = true } label: {
                        Label("Games", systemImage: "list.bullet")
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(GameText.title(white: shell.session.gameState.white, black: shell.session.gameState.black))
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Walnut.textPrimary)
                        if let opening = shell.session.openingName {
                            Text(opening)
                                .font(.caption)
                                .italic()
                                .foregroundStyle(Walnut.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    moreMenu
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    NavigationButtons(session: shell.session)
                    Spacer()
                    Toggle(isOn: $showEngine) {
                        Label("Engine", systemImage: "gauge")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        // Files "Open in BChess" and the share sheet: the same flow as the importer
        .onOpenURL { url in
            attempt(.importFile(url))
        }
        .onChange(of: shell.session.gameState) {
            shell.save()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                shell.save()
            }
        }
        .sheet(item: $playersSheet) { sheet in
            NewGameView_iOS(session: shell.session, editMode: sheet == .players, onNewGame: { white, black in
                attempt(.create(white, black))
            })
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showGames, onDismiss: {
            // A sheet cannot open while another is closing: the New Game button waits for this
            if newGameAfterGames {
                newGameAfterGames = false
                playersSheet = .newGame
            }
        }) {
            GamesList(shell: shell, attempt: attempt, onNewGame: {
                newGameAfterGames = true
                showGames = false
            }, actionError: $actionError)
        }
        .alert("Couldn't save this game", isPresented: Binding(get: { shell.saveError != nil }, set: { if !$0 { shell.dismissSaveError() } })) {
            Button("Retry") { shell.save() }
            Button("Dismiss", role: .cancel) { shell.dismissSaveError() }
        } message: {
            Text(shell.saveError?.localizedDescription ?? "")
        }
        .confirmationDialog("This game has changes that could not be saved.",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            Button("Discard changes and switch", role: .destructive) {
                if let pending {
                    perform(pending, discarding: true)
                }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        }
        .alert("Something went wrong", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("New Game", systemImage: "plus.circle") { playersSheet = .newGame }
            Button("Players & Level", systemImage: "person.2") { playersSheet = .players }
            Button("Flip Board", systemImage: "arrow.triangle.2.circlepath.circle") { shell.session.rotate() }
            ShareLink(item: PGNExport(text: shell.session.gameState.pgn, name: shell.current.title),
                      preview: SharePreview(shell.current.title)) {
                Label("Share Game", systemImage: "square.and.arrow.up")
            }
            Button("Settings", systemImage: "gearshape") { showSettings = true }
            Divider()
            Button("Copy Position", systemImage: "doc.on.doc") { Pasteboard.set(shell.session.fen) }
            Button("Copy Game", systemImage: "doc.on.doc") { Pasteboard.set(shell.session.pgnCurrentGame) }
            Button("Paste Game or Position", systemImage: "arrow.down.circle") {
                if let text = Pasteboard.string {
                    _ = shell.session.paste(text)
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    private func attempt(_ action: PendingSwitch) {
        showGames = false
        if !perform(action, discarding: false) {
            pending = action
        }
    }

    /// Returns false when the switch waits for a decision about unsaved changes.
    @discardableResult
    private func perform(_ action: PendingSwitch, discarding: Bool) -> Bool {
        do {
            switch action {
            case .open(let file):
                return try shell.open(file, discardingUnsavedChanges: discarding)
            case .create(let white, let black):
                return try shell.createGame(white: white, black: black, discardingUnsavedChanges: discarding)
            case .importFile(let url):
                return try shell.importFile(at: url, discardingUnsavedChanges: discarding)
            }
        } catch {
            actionError = error.localizedDescription
            return true
        }
    }
}

private struct GamesList: View {
    let shell: GameShell
    let attempt: (PendingSwitch) -> Void
    let onNewGame: () -> Void
    @Binding var actionError: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showImporter = false
    /// The day the groups are relative to; refreshed when the day changes and when the app returns.
    @State private var now = Date()

    private func delete(_ files: [GameFile]) {
        for file in files {
            do {
                try shell.delete(file)
            } catch {
                actionError = "Couldn't delete this game. \(error.localizedDescription)"
            }
        }
    }

    /// The time for a game of the last two days, the date for an older one.
    private func when(_ file: GameFile, in group: GameSection.Group) -> Text {
        group == .earlier ? Text(file.modified, format: .dateTime.month(.abbreviated).day().year())
                          : Text(file.modified, format: .dateTime.hour().minute())
    }

    private func row(_ file: GameFile, in group: GameSection.Group) -> some View {
        let isOpen = file.url == shell.current.url
        return Button {
            attempt(.open(file))
        } label: {
            HStack(spacing: 12) {
                Image("knight_b")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .frame(width: 36, height: 36)
                    .background(Walnut.pillBackground, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.title)
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .foregroundStyle(Walnut.textPrimary)
                        .lineLimit(1)
                    when(file, in: group)
                        .font(.caption)
                        .foregroundStyle(Walnut.textSecondary)
                }
                Spacer(minLength: 0)
                if isOpen {
                    Text("OPEN")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Walnut.scoreChipText)
                        .background(Walnut.scoreChip, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .listRowBackground(Walnut.card)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(GameSection.sections(of: shell.library.games, now: now, calendar: .current)) { section in
                    Section {
                        ForEach(section.games) { file in
                            row(file, in: section.group)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { section.games[$0] })
                        }
                    } header: {
                        Text(section.group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Walnut.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Walnut.background.ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                now = Date()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    now = Date()
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text("Swipe left on a game to delete it.")
                        .font(.caption)
                        .foregroundStyle(Walnut.textSecondary)
                    Button(action: onNewGame) {
                        Label("New Game", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(Walnut.scoreChipText)
                            .background(Walnut.scoreChip, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("games-new-game")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .padding(.top, 8)
                .background(Walnut.background)
            }
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Walnut.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Import") { showImporter = true }
                }
                ToolbarItem(placement: .principal) {
                    Text("Games")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Walnut.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.bchessGame, .json, .pgn]) { result in
                switch result {
                case .success(let url):
                    attempt(.importFile(url))
                case .failure(let error):
                    actionError = error.localizedDescription
                }
            }
        }
    }
}

#if DEBUG
/// A library of a few games from fixed times of day, for the previews. It never touches the real
/// defaults.
@MainActor
private func previewShell() -> GameShell? {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Preview-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let library = GameLibrary(directory: directory, defaults: PreviewScenarios.defaults)
    // Calendar arithmetic, so a daylight-saving change cannot move a time of day
    let calendar = Calendar.current
    func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    let games: [(String, Date)] = [
        ("You vs Computer", date(daysAgo: 0, hour: 9, minute: 30)),
        ("Ruy Lopez practice", date(daysAgo: 0, hour: 9, minute: 0)),
        ("Anna vs Jean", date(daysAgo: 1, hour: 18, minute: 15)),
        ("Imported game", date(daysAgo: 9, hour: 11, minute: 0)),
    ]
    for (name, date) in games {
        if let file = try? library.create(GameState(pgn: "*"), baseName: name) {
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.url.path)
        }
    }
    library.reload()
    return try? GameShell(library: library)
}

/// The Games list of the iPhone shell. `GamesList` stays private, so its preview is built here.
@MainActor @ViewBuilder
func gamesListPreview() -> some View {
    if let shell = previewShell() {
        GamesList(shell: shell, attempt: { _ in }, onNewGame: {}, actionError: .constant(nil))
    }
}

#Preview("Games") {
    PreviewScenarios.gamesList.view()
}

#Preview("Launch") {
    PreviewScenarios.gamesLaunch.view()
}
#endif
