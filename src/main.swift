import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

// MARK: - Models

struct CaptureCommand: Codable {
    let command: String
    let args: CaptureArgs
}

struct CaptureArgs: Codable {
    let output: String?
    let window: String?
    let region: RegionSpec?
    let format: String?
    let analyze: String?
}

struct RegionSpec: Codable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

struct SuccessResponse: Codable {
    let success: Bool
    let path: String
    let width: Int
    let height: Int
    let format: String
    let analysis: String?
}

struct ErrorResponse: Codable {
    let success: Bool
    let error: String
}

// MARK: - CLI Argument Parsing

struct CLIArguments {
    var output: String?
    var window: String?
    var region: CGRect?
    var format: String = "png"
    var analyze: String?
    var help: Bool = false
    var jsonInput: Bool = false
}

func parseCLIArguments(_ args: [String]) -> CLIArguments {
    var result = CLIArguments()
    var i = 0
    
    while i < args.count {
        let arg = args[i]
        
        switch arg {
        case "--output", "-o":
            if i + 1 < args.count {
                result.output = args[i + 1]
                i += 1
            }
        case "--window", "-w":
            if i + 1 < args.count {
                result.window = args[i + 1]
                i += 1
            }
        case "--region", "-r":
            if i + 1 < args.count {
                result.region = parseRegion(args[i + 1])
                i += 1
            }
        case "--format", "-f":
            if i + 1 < args.count {
                result.format = args[i + 1].lowercased()
                i += 1
            }
        case "--analyze", "-a":
            if i + 1 < args.count {
                result.analyze = args[i + 1]
                i += 1
            }
        case "--json":
            result.jsonInput = true
        case "--help", "-h":
            result.help = true
        default:
            break
        }
        
        i += 1
    }
    
    return result
}

func parseRegion(_ regionString: String) -> CGRect? {
    let components = regionString.split(separator: ",").compactMap { Double($0) }
    guard components.count == 4 else { return nil }
    return CGRect(x: components[0], y: components[1], width: components[2], height: components[3])
}

// MARK: - Screenshot Capture using ScreenCaptureKit

@available(macOS 14.0, *)
class ScreenshotCapture {
    
    // Capture full screen using ScreenCaptureKit
    static func captureFullScreen() async throws -> CGImage {
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.scalesToFit = false
        config.showsCursor = true
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        return image
    }
    
    // Capture specific window by name
    static func captureWindow(named windowName: String) async throws -> CGImage {
        let content = try await SCShareableContent.current
        
        // Find window by matching app name or window title (case-insensitive)
        let matchingWindow = content.windows.first { window in
            let appName = window.owningApplication?.applicationName ?? ""
            let windowTitle = window.title ?? ""
            return appName.localizedCaseInsensitiveContains(windowName) ||
                   windowTitle.localizedCaseInsensitiveContains(windowName)
        }
        
        guard let window = matchingWindow else {
            throw CaptureError.windowNotFound(windowName)
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2  // Account for retina
        config.height = Int(window.frame.height) * 2
        config.scalesToFit = false
        config.showsCursor = false
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        return image
    }
    
    // Capture specific region
    static func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }
        
        // Validate region bounds
        let displayWidth = CGFloat(display.width)
        let displayHeight = CGFloat(display.height)
        
        guard rect.origin.x >= 0,
              rect.origin.y >= 0,
              rect.origin.x + rect.width <= displayWidth,
              rect.origin.y + rect.height <= displayHeight else {
            throw CaptureError.invalidRegion(rect)
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.scalesToFit = false
        config.showsCursor = true
        
        let fullImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        // Crop to the specified region
        // Note: CGImage coordinates are different from screen coordinates
        let scale = CGFloat(fullImage.width) / displayWidth
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        guard let croppedImage = fullImage.cropping(to: scaledRect) else {
            throw CaptureError.cropFailed
        }
        
        return croppedImage
    }
}

// MARK: - Image Saving

func saveImage(_ image: CGImage, to path: String, format: String) throws -> String {
    let expandedPath = (path as NSString).expandingTildeInPath
    let url = URL(fileURLWithPath: expandedPath)
    
    // Create NSBitmapImageRep from CGImage
    let bitmap = NSBitmapImageRep(cgImage: image)
    
    // Convert to PNG or JPEG data
    let imageData: Data?
    switch format.lowercased() {
    case "jpeg", "jpg":
        imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    case "png":
        imageData = bitmap.representation(using: .png, properties: [:])
    default:
        imageData = bitmap.representation(using: .png, properties: [:])
    }
    
    guard let data = imageData else {
        throw CaptureError.imageEncodingFailed
    }
    
    try data.write(to: url)
    return expandedPath
}

// MARK: - Error Types

enum CaptureError: Error, LocalizedError {
    case noDisplayFound
    case windowNotFound(String)
    case invalidRegion(CGRect)
    case cropFailed
    case imageEncodingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found. Make sure a screen is connected."
        case .windowNotFound(let name):
            return "Window '\(name)' not found. Make sure the window is visible and the app is running."
        case .invalidRegion(let rect):
            return "Invalid region bounds: \(rect). Region must be within screen boundaries."
        case .cropFailed:
            return "Failed to crop image to specified region."
        case .imageEncodingFailed:
            return "Failed to encode image to the specified format."
        case .permissionDenied:
            return "Screen recording permission denied. Grant permission in System Settings > Privacy & Security > Screen Recording."
        }
    }
}

// MARK: - JSON Output

func outputSuccess(path: String, width: Int, height: Int, format: String, analysis: String? = nil) {
    let response = SuccessResponse(
        success: true,
        path: path,
        width: width,
        height: height,
        format: format,
        analysis: analysis
    )
    
    if let data = try? JSONEncoder().encode(response),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}

func outputError(_ message: String) -> Never {
    let response = ErrorResponse(success: false, error: message)
    
    if let data = try? JSONEncoder().encode(response),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        print("{\"success\":false,\"error\":\"\(message)\"}")
    }
    exit(1)
}

// MARK: - Main Execution

@available(macOS 14.0, *)
@main
struct ScreenshotTool {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let cliArgs = parseCLIArguments(args)
        
        if cliArgs.help {
            showHelp()
            exit(0)
        }
        
        // Determine if we're in JSON input mode
        if cliArgs.jsonInput {
            await executeJSONMode()
        } else {
            await executeCLIMode(cliArgs)
        }
    }
    
    static func showHelp() {
        let help = """
        agent-screenshot - Screen capture tool for AI agents
        
        USAGE:
            agent-screenshot [OPTIONS]
            echo '{"command":"capture","args":{...}}' | agent-screenshot --json
        
        OPTIONS:
            --output, -o <path>           Output file path (default: screenshot.png)
            --window, -w <name>           Capture specific window by name
            --region, -r <x,y,w,h>        Capture region (e.g., 0,0,800,600)
            --format, -f <png|jpeg>       Output format (default: png)
            --analyze, -a <prompt>        Analyze screenshot with vision model (TODO)
            --json                        Accept JSON input from stdin
            --help, -h                    Show this help message
        
        EXAMPLES:
            # Capture full screen
            agent-screenshot --output screen.png
            
            # Capture Safari window
            agent-screenshot --window "Safari" --output safari.png
            
            # Capture region
            agent-screenshot --region 0,0,800,600 --output region.png
            
            # JSON input mode
            echo '{"command":"capture","args":{"output":"/tmp/screen.png"}}' | agent-screenshot --json
            echo '{"command":"capture","args":{"window":"Safari","output":"/tmp/safari.png"}}' | agent-screenshot --json
            echo '{"command":"capture","args":{"region":{"x":0,"y":0,"w":800,"h":600},"output":"/tmp/region.png"}}' | agent-screenshot --json
        
        REQUIREMENTS:
            - macOS 14.0+
            - Screen Recording permission (System Settings > Privacy & Security)
        """
        print(help)
    }
    
    static func executeJSONMode() async {
        // Read JSON from stdin
        var stdinData = Data()
        let handle = FileHandle.standardInput
        
        if let input = try? handle.readToEnd() {
            stdinData = input
        }
        
        guard !stdinData.isEmpty else {
            outputError("No JSON input received on stdin. Use --json flag and pipe JSON data.")
        }
        
        // Parse JSON command
        let decoder = JSONDecoder()
        guard let command = try? decoder.decode(CaptureCommand.self, from: stdinData) else {
            outputError("Invalid JSON format. Expected: {\"command\":\"capture\",\"args\":{...}}")
        }
        
        guard command.command == "capture" else {
            outputError("Unknown command: \(command.command). Only 'capture' is supported.")
        }
        
        let outputPath = command.args.output ?? "screenshot.png"
        let format = command.args.format ?? "png"
        
        await performCapture(
            outputPath: outputPath,
            window: command.args.window,
            region: command.args.region.map { CGRect(x: $0.x, y: $0.y, width: $0.w, height: $0.h) },
            format: format,
            analyze: command.args.analyze
        )
    }
    
    static func executeCLIMode(_ cliArgs: CLIArguments) async {
        let outputPath = cliArgs.output ?? "screenshot.\(cliArgs.format)"
        
        await performCapture(
            outputPath: outputPath,
            window: cliArgs.window,
            region: cliArgs.region,
            format: cliArgs.format,
            analyze: cliArgs.analyze
        )
    }
    
    static func performCapture(
        outputPath: String,
        window: String?,
        region: CGRect?,
        format: String,
        analyze: String?
    ) async {
        do {
            // Capture image based on mode
            let image: CGImage
            
            if let windowName = window {
                image = try await ScreenshotCapture.captureWindow(named: windowName)
            } else if let regionRect = region {
                image = try await ScreenshotCapture.captureRegion(regionRect)
            } else {
                image = try await ScreenshotCapture.captureFullScreen()
            }
            
            // Save the image
            let savedPath = try saveImage(image, to: outputPath, format: format)
            
            // Handle vision analysis if requested
            var analysisResult: String? = nil
            if let analyzePrompt = analyze {
                // TODO: Implement vision API integration
                analysisResult = "[Vision Analysis TODO] Prompt: '\(analyzePrompt)' - API integration pending"
            }
            
            // Output success
            outputSuccess(
                path: savedPath,
                width: image.width,
                height: image.height,
                format: format,
                analysis: analysisResult
            )
            
            exit(0)
            
        } catch let error as CaptureError {
            outputError(error.localizedDescription)
        } catch {
            outputError("Unexpected error: \(error.localizedDescription)")
        }
    }
}
