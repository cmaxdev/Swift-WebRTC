//
//  File.swift
//  d-idWebRTC
//
//  Created by Robin von Hardenberg on 03.11.23.
//

import Foundation
import WebRTC

struct StreamResponse: Codable {
    let id: String
    let offer: SDPOffer
    let iceServers: [ICEServer]
    let sessionId: String

    // Define the mapping between the JSON keys and the property names
    enum CodingKeys: String, CodingKey {
        case id             // No custom raw value needed; the JSON key is "id"
        case offer          // No custom raw value needed; the JSON key is "offer"
        case iceServers = "ice_servers"  // Custom raw value; the JSON key is "ice_servers"
        case sessionId = "session_id"    // Custom raw value; the JSON key is "session_id"
    }
}

struct SDPOffer: Codable {
    let type: String
    let sdp: String
}

struct ICEServer: Codable {
    let urls: [String]
    let username: String?
    let credential: String?
    
    // Custom init to handle the single URL or array of URLs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let singleURL = try? container.decode(String.self, forKey: .urls) {
            urls = [singleURL]
        } else if let multipleURLs = try? container.decode([String].self, forKey: .urls) {
            urls = multipleURLs
        } else {
            urls = []
        }
        username = try container.decodeIfPresent(String.self, forKey: .username)
        credential = try container.decodeIfPresent(String.self, forKey: .credential)
    }
    
    // CodingKeys to map the JSON keys to struct properties
    enum CodingKeys: String, CodingKey {
        case urls
        case username
        case credential
    }
}
