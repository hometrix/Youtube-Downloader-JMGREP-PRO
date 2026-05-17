import Foundation
import SwiftUI
import UserNotifications
import AppKit

// MARK: - Enums for Download Options
enum VideoContainer: String, CaseIterable, Identifiable {
    case mp4, mkv, webm, flv, avi
    var id: Self { self }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case q144p = "144p", q240p = "240p", q360p = "360p", q480p = "480p"
    case q720p = "720p", q1080p = "1080p", q1440p = "1440p", q2160p = "2160p"
    var id: Self { self }
    var pixelValue: Int { Int(rawValue.dropLast()) ?? 0 }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3, m4a, wav, flac, opus, vorbis
    var id: Self { self }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case k64 = "64k", k128 = "128k", k192 = "192k", k256 = "256k", k320 = "320k"
    var id: Self { self }
}

enum DownloadFormat: String, CaseIterable, Identifiable {
    case best = "Best Quality (auto)"
    case video = "Best Video"
    case audio = "Best Audio"
    var id: Self { self }
}

// MARK: - Download View Model
@MainActor
class DownloadViewModel: ObservableObject {
    
    // MARK: - User Input Properties
    @Published var singleURL = ""
    @Published var batchURLs = ""
    @Published var isBatchMode = false
    @Published var downloadDirectory: URL?
    
    // Format Selection
    @Published var selectedFormat: DownloadFormat = .best
    @Published var videoContainer: VideoContainer = .mp4
    @Published var videoQuality: VideoQuality = .q1080p
    @Published var audioFormat: AudioFormat = .mp3
    @Published var audioQuality: AudioQuality = .k128
    
    // Advanced Options
    @Published var embedSubtitles = false
    @Published var embedMetadata = false
    @Published var skipExistingFiles = false
    @Published var autoOpenFolder = false
    @Published var subtitleLanguage = "all"
    @Published var filenameTemplate = "%(title)s.%(ext)s"
    @Published var downloadSpeedLimit = ""
    @Published var throttleRate = ""
    @Published var language: AppLanguage = .spanish // Default to Spanish as requested
    @Published var disclaimerAccepted: Bool {
        didSet {
            UserDefaults.standard.set(disclaimerAccepted, forKey: "disclaimerAccepted")
        }
    }
    
    // MARK: - State Properties
    @Published var logLines: [String] = []
    @Published var isRunning = false
    @Published var dependenciesReady = false
    @Published var isSettingUp = false
    @Published var setupStatusMessage = ""
    
    // Progress
    @Published var currentItemProgress: Double = 0.0
    @Published var currentItemSpeed: String = ""
    @Published var currentItemETA: String = ""
    @Published var currentFilename: String = ""
    
    // MARK: - History
    struct DownloadRecord: Identifiable, Codable {
        var id = UUID()
        let filename: String
        let url: String
        let date: Date
    }
    @Published var downloadHistory: [DownloadRecord] = []
    @Published var currentItemIndex = 0
    @Published var totalItems = 0
    
    // Error Handling
    @Published var showingErrorAlert = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var activeProcess: Process?
    private let maxLogLines = 1000
    private let progressRegex = try! NSRegularExpression(pattern: #"\[download\]\s+([0-9.]+)%(?:\s+of\s+\S+)?(?:\s+at\s+([^\s]+))?(?:\s+ETA\s+([^\s]+))?"#)
    private let destinationRegex = try! NSRegularExpression(pattern: #"(?:\[download\] Destination: |\[Merger\] Merging formats into ")([^"]+)"?"#)
    
    private var ytDlpPath: String?
    private var ffmpegPath: String?
    private var ffprobePath: String?
    
    // MARK: - Initialization
    init() {
        self.disclaimerAccepted = UserDefaults.standard.bool(forKey: "disclaimerAccepted")
        Task {
            await locateOrDownloadDependencies()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted.")
            }
        }
        
        loadHistory()
    }
    
    // MARK: - Dependency Management
    
    private func locateOrDownloadDependencies() async {
        do {
            if let existing = try DependencyManager.shared.checkDependencies() {
                addLog("✅ All dependencies found locally.")
                self.ytDlpPath = existing.ytDlp
                self.ffmpegPath = existing.ffmpeg
                self.ffprobePath = existing.ffprobe
                self.dependenciesReady = true
                return
            }
            
            isSettingUp = true
            let dir = try DependencyManager.shared.getAppSupportDirectory()
            
            // Paths
            let ytDlpDest = dir.appendingPathComponent("yt-dlp")
            let ffmpegDest = dir.appendingPathComponent("ffmpeg")
            let ffprobeDest = dir.appendingPathComponent("ffprobe")
            
            // 1. yt-dlp
            if !FileManager.default.fileExists(atPath: ytDlpDest.path) {
                setupStatusMessage = "Downloading yt-dlp..."
                addLog(setupStatusMessage)
                let url = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
                try await DependencyManager.shared.downloadFile(from: url, to: ytDlpDest)
                try DependencyManager.shared.makeExecutable(at: ytDlpDest.path)
            }
            
            // 2. ffmpeg
            if !FileManager.default.fileExists(atPath: ffmpegDest.path) {
                setupStatusMessage = "Downloading ffmpeg..."
                addLog(setupStatusMessage)
                let url = URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!
                let zipPath = dir.appendingPathComponent("ffmpeg.zip")
                try await DependencyManager.shared.downloadFile(from: url, to: zipPath)
                try DependencyManager.shared.unzip(file: zipPath, to: dir)
                try DependencyManager.shared.makeExecutable(at: ffmpegDest.path)
                try? FileManager.default.removeItem(at: zipPath)
            }
            
            // 3. ffprobe
            if !FileManager.default.fileExists(atPath: ffprobeDest.path) {
                setupStatusMessage = "Downloading ffprobe..."
                addLog(setupStatusMessage)
                let url = URL(string: "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip")!
                let zipPath = dir.appendingPathComponent("ffprobe.zip")
                try await DependencyManager.shared.downloadFile(from: url, to: zipPath)
                try DependencyManager.shared.unzip(file: zipPath, to: dir)
                try DependencyManager.shared.makeExecutable(at: ffprobeDest.path)
                try? FileManager.default.removeItem(at: zipPath)
            }
            
            self.ytDlpPath = ytDlpDest.path
            self.ffmpegPath = ffmpegDest.path
            self.ffprobePath = ffprobeDest.path
            self.dependenciesReady = true
            addLog(Localized.string("setup_ready", lang: language))
            
        } catch {
            showError(String(format: Localized.string("setup_failed", lang: language), error.localizedDescription))
            self.dependenciesReady = false
        }
        
        isSettingUp = false
        setupStatusMessage = ""
    }
    
    func updateEngine() {
        guard !isSettingUp && !isRunning else { return }
        isSettingUp = true
        setupStatusMessage = Localized.string("updating", lang: language)
        addLog(setupStatusMessage)
        
        Task {
            do {
                let dir = try DependencyManager.shared.getAppSupportDirectory()
                let ytDlpDest = dir.appendingPathComponent("yt-dlp")
                
                // Remove existing if any
                if FileManager.default.fileExists(atPath: ytDlpDest.path) {
                    try FileManager.default.removeItem(at: ytDlpDest)
                }
                
                let url = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
                try await DependencyManager.shared.downloadFile(from: url, to: ytDlpDest)
                try DependencyManager.shared.makeExecutable(at: ytDlpDest.path)
                
                DispatchQueue.main.async {
                    self.addLog(Localized.string("update_success", lang: self.language))
                    self.isSettingUp = false
                    self.setupStatusMessage = ""
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(String(format: Localized.string("setup_failed", lang: self.language), error.localizedDescription))
                    self.isSettingUp = false
                    self.setupStatusMessage = ""
                }
            }
        }
    }
    
    // MARK: - User Actions
    
    func selectDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            self.downloadDirectory = url
            addLog(String(format: Localized.string("location_set", lang: language), url.path))
        }
    }
    
    func openDownloadDirectory() {
        guard let dir = downloadDirectory else { return }
        NSWorkspace.shared.open(dir)
    }
    
    func startDownload() {
        guard dependenciesReady else {
            showError(Localized.string("deps_not_ready", lang: language))
            return
        }
        guard let outputDir = downloadDirectory else {
            showError(Localized.string("choose_folder_err", lang: language))
            return
        }
        
        let urls = isBatchMode ? batchURLs.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } : [singleURL]
        
        guard !urls.isEmpty, !urls[0].trimmingCharacters(in: .whitespaces).isEmpty else {
            showError(isBatchMode ? Localized.string("no_urls_err", lang: language) : Localized.string("enter_url_err", lang: language))
            return
        }
        
        isRunning = true
        resetProgress()
        totalItems = urls.count
        logLines = [Localized.string("starting_download", lang: language)]
        
        Task {
            for (index, url) in urls.enumerated() {
                if !isRunning { break }
                currentItemIndex = index + 1
                currentItemProgress = 0.0
                currentItemSpeed = ""
                currentItemETA = ""
                addLog(String(format: Localized.string("downloading_item", lang: language), currentItemIndex, totalItems, url))
                await runYtDlp(for: url, in: outputDir)
            }
            
            if isRunning {
                addLog(Localized.string("all_complete", lang: language))
                self.sendNotification(title: Localized.string("app_title", lang: language), body: Localized.string("all_complete", lang: language))
                if autoOpenFolder { openDownloadDirectory() }
            }
            isRunning = false
        }
    }
    
    func cancelDownload() {
        guard isRunning else { return }
        addLog(Localized.string("cancelled_user", lang: language))
        isRunning = false
        activeProcess?.terminate()
        activeProcess = nil
        resetProgress()
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Core Download Logic
    
    private func buildArguments(for url: String, in directory: URL) -> [String]? {
        guard let ffmpegBinaryPath = self.ffmpegPath else { return nil }
        let ffmpegDir = (ffmpegBinaryPath as NSString).deletingLastPathComponent
        
        let template = filenameTemplate.trimmingCharacters(in: .whitespaces).isEmpty ? "%(title)s.%(ext)s" : filenameTemplate
        let outputPath = isBatchMode ? "\(directory.path)/%(playlist_index)s-%(id)s-\(template)" : "\(directory.path)/\(template)"
        
        var args = [
            url,
            "--newline",
            "--no-warnings",
            "--progress",
            "--ffmpeg-location", ffmpegDir,
            "-o", outputPath
        ]
        
        switch selectedFormat {
        case .best:
            args += ["-f", "bv*+ba/b"]
        case .video:
            args += ["-f", "bestvideo[height<=\(videoQuality.pixelValue)]+bestaudio/best", "--merge-output-format", videoContainer.rawValue]
        case .audio:
            args += ["-f", "bestaudio/best", "--extract-audio", "--audio-format", audioFormat.rawValue, "--audio-quality", audioQuality.rawValue]
        }
        
        if embedSubtitles { args += ["--write-sub", "--embed-subs", "--sub-langs", subtitleLanguage.isEmpty ? "all" : subtitleLanguage] }
        if embedMetadata { args += ["--embed-metadata", "--embed-thumbnail"] }
        if skipExistingFiles { args += ["--no-overwrites"] }
        if !downloadSpeedLimit.isEmpty { args += ["-r", downloadSpeedLimit] }
        if !throttleRate.isEmpty { args += ["--throttled-rate", throttleRate] }
        
        return args
    }
    
    private func runYtDlp(for url: String, in directory: URL) async {
        guard isRunning, let ytdlpPath = self.ytDlpPath, let arguments = buildArguments(for: url, in: directory) else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let process = Process()
            self.activeProcess = process
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                    DispatchQueue.main.async { self.processOutputLine(line) }
                }
            }
            
            process.terminationHandler = { p in
                DispatchQueue.main.async {
                    self.activeProcess = nil
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if p.terminationStatus != 0 && self.isRunning {
                        self.addLog(String(format: Localized.string("download_error", lang: self.language), "Status \(p.terminationStatus)"))
                    } else if p.terminationStatus == 0 {
                        // Success - append to history
                        let record = DownloadRecord(filename: self.currentFilename.isEmpty ? url : self.currentFilename, url: url, date: Date())
                        self.downloadHistory.insert(record, at: 0) // Most recent first
                        self.saveHistory()
                    }
                    continuation.resume()
                }
            }
            
            DispatchQueue.main.async { self.currentFilename = "" }
            
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    self.addLog(String(format: Localized.string("download_error", lang: self.language), error.localizedDescription))
                    continuation.resume()
                }
            }
        }
    }
    
    private func processOutputLine(_ output: String) {
        output.enumerateLines { line, _ in
            self.addLog(line)
            
            if let match = self.destinationRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let r = Range(match.range(at: 1), in: line) {
                    self.currentFilename = String(line[r])
                }
            }
            
            if let match = self.progressRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                // Progress
                if let progressRange = Range(match.range(at: 1), in: line),
                   let progressValue = Double(line[progressRange]) {
                    self.currentItemProgress = progressValue / 100.0
                }
                
                // Speed
                if match.numberOfRanges > 2, let speedRange = Range(match.range(at: 2), in: line) {
                    self.currentItemSpeed = String(line[speedRange])
                }
                
                // ETA
                if match.numberOfRanges > 3, let etaRange = Range(match.range(at: 3), in: line) {
                    self.currentItemETA = String(line[etaRange])
                }
            }
        }
    }
    
    private func addLog(_ message: String) {
        logLines.append(message)
        if logLines.count > maxLogLines { logLines.removeFirst() }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
        isRunning = false
        addLog("❌ ERROR: \(message)")
    }
    
    private func resetProgress() {
        currentItemProgress = 0.0
        currentItemSpeed = ""
        currentItemETA = ""
        currentItemIndex = 0
        totalItems = 0
    }
    
    // MARK: - History Methods
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "downloadHistory"),
           let decoded = try? JSONDecoder().decode([DownloadRecord].self, from: data) {
            self.downloadHistory = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(downloadHistory) {
            UserDefaults.standard.set(encoded, forKey: "downloadHistory")
        }
    }
    
    func clearHistory() {
        downloadHistory.removeAll()
        saveHistory()
    }
}
