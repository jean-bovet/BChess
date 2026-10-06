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
        .sheet(isPresented: $showGames) {
            GamesList(shell: shell, attempt: attempt, actionError: $actionError)
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
    @Binding var actionError: String?

    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(shell.library.games) { file in
                    Button {
                        attempt(.open(file))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(file.title)
                                Text(file.modified, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if file.url == shell.current.url {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    let files = offsets.map { shell.library.games[$0] }
                    for file in files {
                        do {
                            try shell.delete(file)
                        } catch {
                            actionError = "Couldn't delete this game. \(error.localizedDescription)"
                        }
                    }
                }
            }
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Import") { showImporter = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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

#Preview {
    GameRootView(library: GameLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Preview-\(UUID().uuidString)", isDirectory: true)))
}
