import Foundation

// Placeholder executable target so `swift build` succeeds.
// Full screenshot functionality will be implemented in a future phase.

struct ErrorResponse: Codable {
    let success: Bool
    let error: String
}

let response = ErrorResponse(success: false, error: "AgentScreenshot is not implemented yet")
if let data = try? JSONEncoder().encode(response),
   let json = String(data: data, encoding: .utf8) {
    print(json)
} else {
    print("{\"success\":false,\"error\":\"AgentScreenshot is not implemented yet\"}")
}
