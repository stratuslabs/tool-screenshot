import Foundation
import CoreGraphics
import ImageIO
import AppKit

// MARK: - Models

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

// MARK: - Argument Parsing

struct Arguments {
    var output: String?
    var window: String?
    var region: CGRect?
    var format: String = "png"
    var analyze: String?
    var help: Bool = false
}

func parseArguments(_ args: [String]) -> Arguments {
    var result = Arguments()
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

// MARK: - Screenshot Capture

func captureFullScreen() -> CGImage? {
    guard let displayID = CGMainDisplayID() as CGDirectDisplayID? else {
        return nil
    }
    return CGDisplayCreateImage(displayID)
}

func captureWindow(named windowName: String) -> CGImage? {
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    
    guard let windows = windowList else {
        return nil
    }
    
    // Find window by name (case-insensitive partial match)
    for window in windows {
        if let ownerName = window[kCGWindowOwnerName as String] as? String,
           ownerName.localizedCaseInsensitiveContains(windowName) {
            if let windowID = window[kCGWindowNumber as String] as? CGWindowID {
                let windowImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.bestResolution, .boundsIgnoreFraming]
                )
                return windowImage
            }
        }
        
        // Also check window name/title
        if let windowTitle = window[kCGWindowName as String] as? String,
           windowTitle.localizedCaseInsensitiveContains(windowName) {
            if let windowID = window[kCGWindowNumber as String] as? CGWindowID {
                let windowImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.bestResolution, .boundsIgnoreFraming]
                )
                return windowImage
            }
        }
    }
    
    return nil
}

func captureRegion(_ rect: CGRect) -> CGImage? {
    // Capture full screen first, then crop
    guard let fullScreen = captureFullScreen() else {
        return nil
    }
    
    // Validate region bounds
    let screenHeight = CGFloat(fullScreen.height)
    let screenWidth = CGFloat(fullScreen.width)
    
    guard rect.origin.x >= 0,
          rect.origin.y >= 0,
          rect.origin.x + rect.width <= screenWidth,
          rect.origin.y + rect.height <= screenHeight else {
        return nil
    }
    
    return fullScreen.cropping(to: rect)
}

// MARK: - Image Saving

func saveImage(_ image: CGImage, to path: String, format: String) -> Bool {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, formatUTI(for: format) as CFString, 1, nil) else {
        return false
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

func formatUTI(for format: String) -> String {
    switch format.lowercased() {
    case "jpeg", "jpg":
        return "public.jpeg"
    case "png":
        return "public.png"
    default:
        return "public.png"
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

func showHelp() {
    let help = """
    agent-screenshot - Screen capture tool for AI agents
    
    USAGE:
        agent-screenshot [OPTIONS]
    
    OPTIONS:
        --output, -o <path>           Output file path (default: screenshot.png)
        --window, -w <name>           Capture specific window by name
        --region, -r <x,y,w,h>        Capture region (e.g., 0,0,800,600)
        --format, -f <png|jpeg>       Output format (default: png)
        --analyze, -a <prompt>        Analyze screenshot with vision model (TODO)
        --help, -h                    Show this help message
    
    EXAMPLES:
        # Capture full screen
        agent-screenshot --output screen.png
        
        # Capture Safari window
        agent-screenshot --window "Safari" --output safari.png
        
        # Capture region
        agent-screenshot --region 0,0,800,600 --output region.png
        
        # Capture and analyze (vision API TODO)
        agent-screenshot --analyze "Is there a login form?"
    """
    print(help)
}

// MARK: - Main Logic

let args = Array(CommandLine.arguments.dropFirst())
let arguments = parseArguments(args)

if arguments.help {
    showHelp()
    exit(0)
}

// Determine output path
let outputPath = arguments.output ?? "screenshot.\(arguments.format)"

// Capture image based on mode
var capturedImage: CGImage?
var captureMode = "fullscreen"

if let window = arguments.window {
    capturedImage = captureWindow(named: window)
    captureMode = "window"
    if capturedImage == nil {
        outputError("Window '\(window)' not found. Make sure the window is visible and the app is running.")
    }
} else if let region = arguments.region {
    capturedImage = captureRegion(region)
    captureMode = "region"
    if capturedImage == nil {
        outputError("Failed to capture region. Check bounds: \(region)")
    }
} else {
    capturedImage = captureFullScreen()
    if capturedImage == nil {
        outputError("Failed to capture screen. Check screen recording permissions in System Preferences > Privacy & Security.")
    }
}

guard let image = capturedImage else {
    outputError("Failed to capture screenshot")
}

// Save image
let saved = saveImage(image, to: outputPath, format: arguments.format)
if !saved {
    outputError("Failed to save image to '\(outputPath)'. Check file path and permissions.")
}

// Handle vision analysis if requested
var analysisResult: String? = nil
if let analyzePrompt = arguments.analyze {
    // TODO: Implement vision API integration
    // For now, return a structured placeholder
    analysisResult = "[Vision Analysis TODO] Prompt: '\(analyzePrompt)' - API integration pending"
}

// Output success
let expandedPath = (outputPath as NSString).expandingTildeInPath
outputSuccess(
    path: expandedPath,
    width: image.width,
    height: image.height,
    format: arguments.format,
    analysis: analysisResult
)

exit(0)
