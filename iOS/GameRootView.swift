//
//  GameRootView.swift
//  BChess (iOS)
//
//  The iOS shell: the app opens straight onto a game of the library, saves it as it changes, and
//  lists, imports, exports and deletes games.
//

import SwiftUI
import UniformTypeIdentifiers

/// A game in one format, for the share sheet. The bytes are read when the user picks a destination,
/// not while a menu renders.
struct GameExport: Transferable {
    let shell: GameShell
    let file: GameFile
    let format: ExportFormat

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pgn) { export in
            try await MainActor.run { try export.shell.exportData(of: export.file, as: export.format) }
        }
        .exportingCondition { $0.format == .pgn }
        .suggestedFileName { $0.file.title + "." + $0.format.fileExtension }

        DataRepresentation(exportedContentType: .bchessGame) { export in
            try await MainActor.run { try export.shell.exportData(of: export.file, as: export.format) }
        }
        .exportingCondition { $0.format == .bchess }
        .suggestedFileName { $0.file.title + "." + $0.format.fileExtension }
    }
}

/// "Export" with a choice of format, for the open game (More menu) and for a row of the games list.
struct ExportMenu: View {
    let shell: GameShell
    let file: GameFile

    var body: some View {
        Menu {
            ShareLink(item: GameExport(shell: shell, file: file, format: .pgn), preview: SharePreview(file.title)) {
                Label {
                    Text("PGN")
                    Text("For other chess apps")
                } icon: {
                    Image(systemName: "doc.text")
                }
            }
            ShareLink(item: GameExport(shell: shell, file: file, format: .bchess), preview: SharePreview(file.title)) {
                Label {
                    Text("BChess")
                    Text("Keeps the players and the board side")
                } icon: {
                    Image(systemName: "crown")
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
}

/// A switch of game that waits for the user to decide about unsaved changes.
enum PendingSwitch: Identifiable {
    case open(GameFile)
    case create(GamePlayer, GamePlayer, rotated: Bool)
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
            switch sheet {
            case .newGame:
                NewGameSheet(choice: NewGame(remembered: .standard), mode: .new) { choice in
                    let players = choice.players(firstPlaysWhite: Bool.random())
                    attempt(.create(players.white, players.black, rotated: players.rotated))
                }
            case .players:
                NewGameSheet(choice: NewGame(white: shell.session.gameState.white, black: shell.session.gameState.black), mode: .edit) { choice in
                    let players = choice.players(firstPlaysWhite: true)
                    shell.session.setPlayers(white: players.white, black: players.black)
                    shell.session.requestEngineMoveIfNeeded()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
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
            Button("Players", systemImage: "person.2") { playersSheet = .players }
            Button("Flip Board", systemImage: "arrow.triangle.2.circlepath.circle") { shell.session.rotate() }
            ExportMenu(shell: shell, file: shell.current)
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
            case .create(let white, let black, let rotated):
                return try shell.createGame(white: white, black: black, rotated: rotated, discardingUnsavedChanges: discarding)
            case .importFile(let url):
                return try shell.importFile(at: url, discardingUnsavedChanges: discarding)
            }
        } catch {
            actionError = error.localizedDescription
            return true
        }
    }
}

/// What the games list's one file picker is for. Never cleared: dismissal cannot lose it.
private enum FilePicker {
    case importGame
    case exportFolder(ExportFormat)
}

struct GamesList: View {
    let shell: GameShell
    let attempt: (PendingSwitch) -> Void
    let onNewGame: () -> Void
    @Binding var actionError: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showImporter = false
    @State private var pickerMode: FilePicker = .importGame
    @State private var exported: String?
    /// The day the groups are relative to; refreshed when the day changes and when the app returns.
    @State private var now = Date()

    private func showPicker(_ mode: FilePicker) {
        pickerMode = mode
        showImporter = true
    }

    private func exportAll(to folder: URL, as format: ExportFormat) {
        Task {
            do {
                let urls = try await shell.exportAll(to: folder, as: format)
                exported = "\(urls.count) \(urls.count == 1 ? "game" : "games") exported to “\(folder.lastPathComponent)”"
            } catch {
                actionError = "Couldn't export the games. \(error.localizedDescription)"
            }
        }
    }

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
        .contextMenu { ExportMenu(shell: shell, file: file) }
        .listRowBackground(Walnut.card)
    }

    private var allowedTypes: [UTType] {
        switch pickerMode {
        case .importGame: [.bchessGame, .json, .pgn]
        case .exportFolder: [.folder]
        }
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
                    Text("Swipe left on a game to delete it, touch and hold to export it.")
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
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Import") { showPicker(.importGame) }
                    Menu("Export") {
                        Button("All Games as PGN") { showPicker(.exportFolder(.pgn)) }
                        Button("All Games as BChess") { showPicker(.exportFolder(.bchess)) }
                    }
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
            .fileImporter(isPresented: $showImporter, allowedContentTypes: allowedTypes) { result in
                switch (result, pickerMode) {
                case (.success(let url), .importGame):
                    attempt(.importFile(url))
                case (.success(let url), .exportFolder(let format)):
                    exportAll(to: url, as: format)
                case (.failure(let error), _):
                    if (error as? CocoaError)?.code != .userCancelled {
                        actionError = error.localizedDescription
                    }
                }
            }
            .alert("Games exported", isPresented: Binding(get: { exported != nil }, set: { if !$0 { exported = nil } })) {
                Button("OK", role: .cancel) { exported = nil }
            } message: {
                Text(exported ?? "")
            }
        }
    }
}
