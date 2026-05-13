import Foundation

enum DependencyError: Error {
    case appNameNotFound
    case downloadFailed(URL, Int)
    case unzipFailed(URL)
    case permissionFailed(String)
}

class DependencyManager {
    static let shared = DependencyManager()
    
    private init() {}
    
    func getAppSupportDirectory() throws -> URL {
        guard let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            throw DependencyError.appNameNotFound
        }
        
        let appSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fullPath = appSupportURL.appendingPathComponent(appName)
        
        if !FileManager.default.fileExists(atPath: fullPath.path) {
            try FileManager.default.createDirectory(at: fullPath, withIntermediateDirectories: true, attributes: nil)
        }
        return fullPath
    }
    
    func checkDependencies() throws -> (ytDlp: String, ffmpeg: String, ffprobe: String)? {
        let dir = try getAppSupportDirectory()
        let ytDlp = dir.appendingPathComponent("yt-dlp").path
        let ffmpeg = dir.appendingPathComponent("ffmpeg").path
        let ffprobe = dir.appendingPathComponent("ffprobe").path
        
        if FileManager.default.fileExists(atPath: ytDlp) &&
           FileManager.default.fileExists(atPath: ffmpeg) &&
           FileManager.default.fileExists(atPath: ffprobe) {
            return (ytDlp, ffmpeg, ffprobe)
        }
        return nil
    }
    
    func downloadFile(from url: URL, to destinationURL: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DependencyError.downloadFailed(url, (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    
    func unzip(file source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", source.path, "-d", destination.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw DependencyError.unzipFailed(source)
        }
    }
    
    func makeExecutable(at path: String) throws {
        var permissions = try FileManager.default.attributesOfItem(atPath: path)
        permissions[.posixPermissions] = 0o755 // rwxr-xr-x
        try FileManager.default.setAttributes(permissions, ofItemAtPath: path)
    }
}
