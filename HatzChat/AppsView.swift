import SwiftUI

struct AppsView: View {
    @EnvironmentObject var store: ChatStore

    @State private var searchText: String = ""
    @State private var selectedAppID: String?
    @State private var selectedApp: HatzApp?

    @State private var selectedModel: String = "gpt-4o"
    @State private var inputValues: [String: String] = [:]

    @State private var outputText: String = ""
    @State private var localError: String?
    @State private var isLoadingDetail: Bool = false
    @State private var isRunning: Bool = false

    private var filteredApps: [HatzApp] {
        let apps = store.availableApps
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return apps }
        return apps.filter {
            $0.name.lowercased().contains(q) || ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search Apps", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await store.refreshApps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh Apps")
                    .disabled(store.isLoadingApps || store.apiKey.isEmpty)
                }
                .padding(10)

                if store.apiKey.isEmpty {
                    ContentUnavailableView("API Key Required",
                                           systemImage: "key.fill",
                                           description: Text("Open Settings and add your Hatz AI API key to load Apps."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.isLoadingApps && store.availableApps.isEmpty {
                    ProgressView("Loading Apps…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredApps.isEmpty {
                    ContentUnavailableView("No Apps Found",
                                           systemImage: "square.grid.2x2",
                                           description: Text("Try refreshing or changing your search."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedAppID) {
                        ForEach(filteredApps) { app in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name).font(.headline)
                                if let d = app.description, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(d)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .tag(app.id as String?)
                        }
                    }
                }
            }
            .frame(minWidth: 320)
            .navigationTitle("Apps")
        } detail: {
            detailView
                .frame(minWidth: 520)
        }
        .onAppear {
            if !store.apiKey.isEmpty, store.availableApps.isEmpty {
                Task { await store.refreshApps() }
            }
        }
        .onChange(of: selectedAppID) { _, newID in
            guard let newID else { return }
            Task { await loadAppDetail(appID: newID) }
        }
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let app = selectedApp {
                header(app)

                Divider()

                if isLoadingDetail {
                    ProgressView("Loading App…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                inputsSection(app)

                HStack {
                    Button {
                        Task { await runApp(app) }
                    } label: {
                        if isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Run")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || !canQuery(app))

                    Button("Clear Output") {
                        outputText = ""
                        localError = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(outputText.isEmpty && localError == nil)

                    Spacer()
                }

                if let err = localError, !err.isEmpty {
                    Text(err)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if !outputText.isEmpty {
                    GroupBox("Output") {
                        ScrollView {
                            MarkdownText(text: outputText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(6)
                        }
                        .frame(minHeight: 220)
                    }
                } else {
                    ContentUnavailableView("No Output Yet",
                                           systemImage: "sparkles",
                                           description: Text("Enter inputs and click Run."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 0)
            } else {
                ContentUnavailableView("Select an App",
                                       systemImage: "square.grid.2x2",
                                       description: Text("Pick an App from the list to view inputs and run it.\n\nPlease note that not all Apps are supported via the API, and file uploads are not possible."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func header(_ app: HatzApp) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.name)
                .font(.title2)
                .bold()

            if let d = app.description, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(d).foregroundStyle(.secondary)
            }

            HStack {
                Text("Model:")
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedModel) {
                    ForEach(store.availableModels.map { $0.name }.sorted(), id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)

                Spacer()
            }
        }
        .onAppear {
            let candidates = store.availableModels.map { $0.name }
            if let appModel = app.default_model, candidates.contains(appModel) {
                selectedModel = appModel
            } else if candidates.contains(store.lastUsedModel) {
                selectedModel = store.lastUsedModel
            } else if let first = candidates.first {
                selectedModel = first
            } else {
                selectedModel = app.default_model ?? "gpt-4o"
            }
        }
    }

    @ViewBuilder
    private func inputsSection(_ app: HatzApp) -> some View {
        GroupBox("Inputs") {
            if !canQuery(app) {
                Text("This App is missing a valid UUID in the /app/list response, so it cannot be queried.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            let inputs = app.user_inputs.sorted { $0.position < $1.position }

            if inputs.isEmpty {
                Text("This App has no user inputs.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(inputs) { input in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(input.display_name)
                                    .font(.headline)

                                if input.required {
                                    Text("Required")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                Text(input.variable_type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !input.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(input.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            inputEditor(for: input)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func inputEditor(for input: HatzAppUserInput) -> some View {
        let key = input.variable_name
        let binding = Binding<String>(
            get: { inputValues[key] ?? "" },
            set: { inputValues[key] = $0 }
        )

        if isLongForm(input.variable_type) {
            TextEditor(text: binding)
                .font(.body)
                .frame(minHeight: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
        } else {
            TextField("", text: binding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func isLongForm(_ variableType: String) -> Bool {
        let t = variableType.lowercased()
        return t.contains("long") || t.contains("paragraph") || t.contains("text_area") || t.contains("multiline")
    }

    private func canQuery(_ app: HatzApp) -> Bool {
        UUID(uuidString: app.id) != nil
    }

    private func loadAppDetail(appID: String) async {
        guard !store.apiKey.isEmpty else { return }
        localError = nil
        outputText = ""
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            let app = try await HatzClient(apiKey: store.apiKey).fetchApp(appID: appID)
            selectedApp = app

            // Initialize/keep input values for this app
            var next: [String: String] = [:]
            for input in app.user_inputs {
                next[input.variable_name] = inputValues[input.variable_name] ?? ""
            }
            inputValues = next

            // Prefer app default_model if it exists in the models list
            let candidates = store.availableModels.map { $0.name }
            if let appModel = app.default_model, candidates.contains(appModel) {
                selectedModel = appModel
            }
        } catch {
            localError = error.localizedDescription
            selectedApp = nil
        }
    }

    private func runApp(_ app: HatzApp) async {
        guard !store.apiKey.isEmpty else { return }
        localError = nil
        outputText = ""
        isRunning = true
        defer { isRunning = false }

        // Validate required inputs
        for r in app.user_inputs where r.required {
            let v = (inputValues[r.variable_name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty {
                localError = "Missing required input: \(r.display_name)"
                return
            }
        }

        do {
            let content = try await HatzClient(apiKey: store.apiKey).queryApp(
                appID: app.id,
                model: selectedModel,
                inputs: inputValues,
                fileUUIDs: []
            )
            outputText = content
        } catch {
            localError = error.localizedDescription
        }
    }
}
