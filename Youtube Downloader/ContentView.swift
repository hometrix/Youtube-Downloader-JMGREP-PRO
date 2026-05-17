import SwiftUI
import AppKit

// This struct is a great candidate for a reusable sub-view.
// It handles the title and subtitle of the app.
struct AppHeaderView: View {
    @ObservedObject var viewModel: DownloadViewModel
    @Binding var showDisclaimer: Bool
    @Binding var showHistory: Bool
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Localized.string("app_title", lang: viewModel.language))
                    Image(systemName: "video.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.largeTitle)
                .bold()
                
                Text(Localized.string("app_subtitle", lang: viewModel.language))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom)
            
            VStack(alignment: .trailing, spacing: 8) {
                Picker("", selection: $viewModel.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
                
                HStack(spacing: 12) {
                    Button(action: {
                        showHistory = true
                    }) {
                        Image(systemName: "clock.fill")
                        Text(Localized.string("history", lang: viewModel.language))
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(100)
                    .font(.caption)
                    
                    Button(action: {
                        showDisclaimer = true
                    }) {
                        Image(systemName: "info.circle.fill")
                        Text(Localized.string("about_legal", lang: viewModel.language))
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(100)
                    .font(.caption)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/hometrix/Youtube-Downloader-JMGREP-PRO") {
                            NSWorkspace.shared.open(url)
                        }
                    }){
                        Text(Localized.string("view_github", lang: viewModel.language))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(100)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// This component encapsulates the UI for selecting single vs. batch mode.
struct ModeSelectionView: View {
    @ObservedObject var viewModel: DownloadViewModel
    
    var body: some View {
        HStack {
            Text(Localized.string("choose_mode", lang: viewModel.language))
                .font(.title2)
                .bold()
            
            Spacer()
            
            BoolSegmentedPicker(
                selection: $viewModel.isBatchMode,
                labels: [
                    false: Localized.string("single_url", lang: viewModel.language),
                    true: Localized.string("batch_urls", lang: viewModel.language)
                ]
            ) { label in
                Text(label)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// This component handles the input field for URLs, which changes based on the mode.
struct URLInputView: View {
    @ObservedObject var viewModel: DownloadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.isBatchMode ? Localized.string("enter_urls", lang: viewModel.language) : Localized.string("enter_url", lang: viewModel.language))
                    .font(.headline)
                Image(systemName: "link")
                    .font(.headline)
                Spacer()
                Text(viewModel.isBatchMode ? Localized.string("batch_mode", lang: viewModel.language) : Localized.string("single_mode", lang: viewModel.language))
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
            }
            
            if viewModel.isBatchMode {
                TextEditor(text: $viewModel.batchURLs)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100, idealHeight: 150, maxHeight: 200)
                    .padding(4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                CustomInputField(placeholder: "https://youtube.com/watch?v=qwertyuiop", text: $viewModel.singleURL)
            }
        }
    }
}

// This component handles the UI for selecting and opening the download directory.
struct DownloadLocationView: View {
    @ObservedObject var viewModel: DownloadViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Localized.string("download_location", lang: viewModel.language))
                    .font(.headline)
                Image(systemName: "folder")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 8) { // Use spacing for cleaner layout
                Text(viewModel.downloadDirectory?.path ?? Localized.string("no_folder", lang: viewModel.language))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .padding(10)
                    .background(Color(.quaternaryLabelColor))
                    .cornerRadius(6)
                    .foregroundStyle(.tertiary)
                
                Button(action: viewModel.selectDownloadDirectory) {
                    HStack {
                        Image(systemName: "folder.fill.badge.plus")
                        Text(Localized.string("choose", lang: viewModel.language))
                    }
                    .padding(10)
                    .background(Color(.quaternaryLabelColor))
                    .cornerRadius(6)
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: viewModel.openDownloadDirectory) {
                    HStack {
                        Image(systemName: "eyes")
                        Text(Localized.string("open", lang: viewModel.language))
                    }
                    .padding(10)
                    .background(Color(.quaternaryLabelColor))
                    .cornerRadius(6)
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.downloadDirectory == nil)
            }
        }
        .padding(.vertical, 4)
    }
}

// Main content view, now using the reusable components.
struct ContentView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var showAboutDisclaimer = false
    @State private var showHistory = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header of the app
                AppHeaderView(viewModel: viewModel, showDisclaimer: $showAboutDisclaimer, showHistory: $showHistory)
                
                // Mode selection for single vs. batch URL
                ModeSelectionView(viewModel: viewModel)
                
                Divider()
                
                // Input field for the URL(s)
                URLInputView(viewModel: viewModel)
                
                // Download location selection
                DownloadLocationView(viewModel: viewModel)
                
                Divider()

                // Download options section
                VStack(alignment: .leading) {
                    HStack {
                        Text(Localized.string("download_options", lang: viewModel.language))
                            .font(.headline)
                        Image(systemName: "ellipsis.circle")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    // Format picker
                    HStack {
                        Picker("", selection: $viewModel.selectedFormat) {
                            ForEach(DownloadFormat.allCases) { format in
                                Text(Localized.string(format == .best ? "best_auto" : (format == .video ? "best_video" : "best_audio"), lang: viewModel.language)).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        Spacer()
                    }
                    
                    // Conditional format options
                    if viewModel.selectedFormat != .best {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Localized.string("format_options", lang: viewModel.language))
                                .font(.headline)
                                .padding(.bottom, 4)
                            if viewModel.selectedFormat == .video {
                                HStack(spacing: 16) {
                                    Picker(Localized.string("container", lang: viewModel.language), selection: $viewModel.videoContainer) {
                                        ForEach(VideoContainer.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                                    }
                                    Picker(Localized.string("quality", lang: viewModel.language), selection: $viewModel.videoQuality) {
                                        ForEach(VideoQuality.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                }
                            } else if viewModel.selectedFormat == .audio {
                                HStack(spacing: 16) {
                                    Picker(Localized.string("container", lang: viewModel.language), selection: $viewModel.audioFormat) {
                                        ForEach(AudioFormat.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                                    }
                                    Picker(Localized.string("quality", lang: viewModel.language), selection: $viewModel.audioQuality) {
                                        ForEach(AudioQuality.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Divider()

                // Advanced options section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Localized.string("advance_options", lang: viewModel.language))
                            .font(.headline)
                        Image(systemName: "oar.2.crossed")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text(Localized.string("filename_template", lang: viewModel.language))
                                .foregroundStyle(.secondary)
                            CustomInputField(placeholder: "%(title)s.%(ext)s", text: $viewModel.filenameTemplate)
                        }
                        VStack(alignment: .leading) {
                            Text(Localized.string("subtitle_langs", lang: viewModel.language))
                                .foregroundStyle(.secondary)
                            CustomInputField(placeholder: "all", text: $viewModel.subtitleLanguage)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text(Localized.string("speed_limit", lang: viewModel.language))
                                .foregroundStyle(.secondary)
                            CustomInputField(placeholder: Localized.string("unlimited", lang: viewModel.language), text: $viewModel.downloadSpeedLimit)
                        }
                        VStack(alignment: .leading) {
                            Text(Localized.string("throttle_rate", lang: viewModel.language))
                                .foregroundStyle(.secondary)
                            CustomInputField(placeholder: Localized.string("none", lang: viewModel.language), text: $viewModel.throttleRate)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // More options (Toggles)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Localized.string("more_options", lang: viewModel.language))
                            .font(.headline)
                        Image(systemName: "gear")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    HStack(spacing:12) {
                        Toggle(Localized.string("embed_subtitles", lang: viewModel.language), isOn: $viewModel.embedSubtitles)
                        Spacer()
                        Toggle(Localized.string("embed_metadata", lang: viewModel.language), isOn: $viewModel.embedMetadata)
                        Spacer()
                        Toggle(Localized.string("skip_existing", lang: viewModel.language), isOn: $viewModel.skipExistingFiles)
                        Spacer()
                        Toggle(Localized.string("auto_open", lang: viewModel.language), isOn: $viewModel.autoOpenFolder)
                    }
                    .toggleStyle(CustomCheckboxStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()

                // Download progress and control
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(Localized.string("download_progress", lang: viewModel.language))
                            .font(.headline)
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    if viewModel.isRunning {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(String(format: Localized.string("item_of", lang: viewModel.language), viewModel.currentItemIndex, viewModel.totalItems))
                                    .bold()
                                Spacer()
                                if !viewModel.currentItemSpeed.isEmpty {
                                    Label(viewModel.currentItemSpeed, systemImage: "bolt.fill")
                                        .foregroundStyle(.orange)
                                }
                                if !viewModel.currentItemETA.isEmpty {
                                    Label(viewModel.currentItemETA, systemImage: "clock.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .font(.caption.monospacedDigit())
                            
                            ProgressView(value: viewModel.currentItemProgress)
                                .progressViewStyle(.linear)
                                .tint(Color.accentColor)
                            
                            HStack {
                                Text("\(Int(viewModel.currentItemProgress * 100))%")
                                    .font(.system(.body, design: .monospaced).bold())
                                Spacer()
                                Button(action: viewModel.cancelDownload) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text(Localized.string("stop", lang: viewModel.language))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.05))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            Button(action: viewModel.startDownload) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text(Localized.string("start_download", lang: viewModel.language))
                                }
                                .font(.headline)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .background(viewModel.dependenciesReady ? Color.accentColor : Color.gray)
                                .cornerRadius(12)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.dependenciesReady)
                            
                            Button(action: viewModel.updateEngine) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(Localized.string("update_engine", lang: viewModel.language))
                                }
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(Color.accentColor)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isSettingUp)
                        }
                    }
                }
                
                Divider()

                // Log output section
                VStack(alignment: .leading) {
                    HStack {
                        Text(Localized.string("logs", lang: viewModel.language))
                            .font(.headline)
                        Image(systemName: "info.circle")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    LogOutputView(logLines: $viewModel.logLines)
                        .frame(idealHeight: 200, maxHeight: .infinity)
                        .scrollIndicators(.hidden)
                }
                
                Divider()
                
                // Footer Credits
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text(Localized.string("credit_text", lang: viewModel.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    Link(destination: URL(string: "https://paypal.me/jmgrepdev")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                            Text(Localized.string("donate_button", lang: viewModel.language))
                                .font(.caption.bold())
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .foregroundStyle(.white)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .scrollIndicators(.automatic) // Hides the main scroll bar
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 550, maxHeight: .infinity)
        .alert(isPresented: $viewModel.showingErrorAlert) {
            Alert(
                title: Text(Localized.string("error", lang: viewModel.language)),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text(Localized.string("ok", lang: viewModel.language)))
            )
        }
        .sheet(isPresented: Binding(
            get: { !viewModel.disclaimerAccepted || showAboutDisclaimer },
            set: { newValue in
                if !newValue {
                    viewModel.disclaimerAccepted = true
                    showAboutDisclaimer = false
                }
            }
        )) {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top)
                
                Text(Localized.string("disclaimer_title", lang: viewModel.language))
                    .font(.title)
                    .bold()
                
                ScrollView {
                    Text(Localized.string("disclaimer_body", lang: viewModel.language))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxHeight: 200)
                
                Button(action: {
                    viewModel.disclaimerAccepted = true
                    showAboutDisclaimer = false
                }) {
                    Text(Localized.string("disclaimer_accept", lang: viewModel.language))
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .foregroundStyle(.white)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.bottom)
            }
            .padding(40)
            .frame(width: 450, height: 500)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(viewModel: viewModel, isPresented: $showHistory)
        }
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: DownloadViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Localized.string("history_title", lang: viewModel.language))
                    .font(.title2.bold())
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            if viewModel.downloadHistory.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(Localized.string("no_history", lang: viewModel.language))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.downloadHistory) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.filename)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(record.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                let path = "\(viewModel.downloadDirectory?.path ?? "")/\(record.filename)"
                                let url = URL(fileURLWithPath: path)
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(Localized.string("show_in_finder", lang: viewModel.language))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.clearHistory()
                    }) {
                        Text(Localized.string("clear_history", lang: viewModel.language))
                            .foregroundStyle(.red)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }
}

// Helper for blur effect in the modal
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
}
