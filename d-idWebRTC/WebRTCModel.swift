//
//  WebRTCModel.swift
//  d-idWebRTC
//
//  Created by Robin von Hardenberg on 03.11.23.
//

import Foundation
import WebRTC

enum WebRTCManagerError: Error {
    case failedToCreatePostData
    case invalidURL
    case noData
    case decodingError(Error)
    case peerConnectionNil
    case failedToCreateSDP
    case serverError
}

protocol WebRTCManagerDelegate: AnyObject {
    
    func updateIceGatheringStatus(_ status: RTCIceGatheringState)
    func updateICEConnectionState(_ state: RTCIceConnectionState)
    func updatePeerConnectionStatus(_ status: RTCPeerConnectionState)
    func updateSignalingStatus(_ status: RTCSignalingState)
    func setupRemoteVideoView(view: UIView)
    
}

class WebRTCManager:NSObject {
    
    
   
    
    weak var delegate: WebRTCManagerDelegate?
    
    //define properties
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        videoEncoderFactory.preferredCodec = RTCVideoCodecInfo(name: kRTCVideoCodecVp8Name)
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    var currentStreamResponse: StreamResponse?
    public var sessionID: String?
    let apiKey = "Basic YUdGeVpHVnVZbVZ5WjBCdFlXTXVZMjl0OmRQTnY5dEVEME9mSUU1ZllFOW90Wg=="
    let baseURL = "https://api.d-id.com"
    var peerConnection: RTCPeerConnection?
    var peerConnectionConfig: RTCConfiguration = RTCConfiguration()
    
    let headers = [
        "accept": "application/json",
        "content-type": "application/json",
        "authorization": "Basic YUdGeVpHVnVZbVZ5WjBCdFlXTXVZMjl0OmRQTnY5dEVEME9mSUU1ZllFOW90Wg=="
    ]
    var remoteVideoView: RTCMTLVideoView?
    
    func setupRemoteVideo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let remoteView = RTCMTLVideoView(frame: .zero)
            self.remoteVideoView = remoteView
            delegate?.setupRemoteVideoView(view: remoteView)
        }
    }
        
        
        
        
        func createNewStream(completion: @escaping (Result<StreamResponse, Error>) -> Void) {
            let parameters = ["source_url": "https://www.berlinaugmented.com/wp-content/uploads/2022/11/02ImageTTKurz.jpg"]
            
            print("Parameters: \(parameters)")
            
            guard let postData = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
                completion(.failure(WebRTCManagerError.failedToCreatePostData))
                return
            }
            
            guard let url = URL(string: "\(baseURL)/talks/streams") else {
                completion(.failure(WebRTCManagerError.invalidURL))
                return
            }
            print("Creating new stream with URL: \(url.absoluteString)")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = postData
            
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(WebRTCManagerError.noData))
                    return
                }
                
                do {
                    let streamResponse = try JSONDecoder().decode(StreamResponse.self, from: data)
                    print(streamResponse)
                    completion(.success(streamResponse))
                } catch {
                    print("Decoding error: \(error.localizedDescription)")
                    completion(.failure(WebRTCManagerError.decodingError(error)))
                }
            }
            
            dataTask.resume()
        }
        
        func setRemoteDescriptionAndCreateAnswer(streamResponse: StreamResponse, completion: @escaping (Error?) -> Void) {
            
            // Ensure that the peerConnection is initialized
            guard let peerConnection = self.peerConnection else {
                completion(WebRTCManagerError.peerConnectionNil)
                return
            }
            
            // Set the remote description with the offer from the server
            let remoteSdp = RTCSessionDescription(type: .offer, sdp: streamResponse.offer.sdp)
            peerConnection.setRemoteDescription(remoteSdp, completionHandler: { [weak self] error in
                if let error = error {
                    completion(error)
                    return
                }
                print("Setting remote description with SDP offer: \(streamResponse.offer.sdp)")
                
                // Create an SDP answer
                peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), completionHandler: { sdp, error in
                    guard let sdp = sdp else {
                        completion(error ?? WebRTCManagerError.failedToCreateSDP)
                        return
                    }
                    print("SDP answer successfully created: \(sdp.sdp)")
                    
                    // Set the local description with the answer
                    peerConnection.setLocalDescription(sdp, completionHandler: { error in
                        if let error = error {
                            completion(error)
                            return
                        }
                        
                        // Send the answer back to the server
                        self?.sendSDPAnswer(sdp, forStreamId: streamResponse.id, completion: { result in
                            switch result {
                            case .success:
                                completion(nil) // SDP answer sent successfully
                                
                                
                            case .failure(let sendError):
                                completion(sendError) // Error sending SDP answer
                            }
                        })
                    })
                })
            })
        }
        
        
        // Function to send the SDP answer back to the server
        func sendSDPAnswer(_ sdpAnswer: RTCSessionDescription, forStreamId streamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            // Serialize the SDP answer
            let sdpTypeString = sdpAnswer.type.stringValue
            let answerDict = ["type": sdpTypeString, "sdp": sdpAnswer.sdp]
            
            // Extract session ID from currentStreamResponse
            guard let sessionId = self.currentStreamResponse?.sessionId else {
                completion(.failure(WebRTCManagerError.serverError)) // Assuming serverError to indicate a missing session ID
                return
            }
            
            // Prepare the full payload with the answer and session ID
            let payloadDict: [String: Any] = ["answer": answerDict, "session_id": sessionId]
            // Convert the dictionary to JSON data
            guard let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict, options: []) else {
                completion(.failure(WebRTCManagerError.failedToCreatePostData))
                return
            }
            
            
            print(answerDict)
            // Use the stream ID in the URL to send the answer to the correct session
            guard let url = URL(string: "\(baseURL)/talks/streams/\(streamId)/sdp") else {
                completion(.failure(WebRTCManagerError.invalidURL))
                return
            }
            print("Sending SDP answer to URL: \(url.absoluteString)")
            print("SDP answer body: \(answerDict)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = payloadData
            
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request) { _, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Check the response status code and handle any errors
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    // Handle server error
                    completion(.failure(WebRTCManagerError.serverError))
                }
            }
            
            dataTask.resume()
        }
        
        func configurePeerConnection(with iceServers: [ICEServer]) {
            // Convert ICE servers from the response to RTCIceServer objects
            let rtcIceServers = iceServers.map { RTCIceServer(urlStrings: $0.urls, username: $0.username, credential: $0.credential) }
            // Configure the peer connection with these ICE servers
            peerConnectionConfig.iceServers = rtcIceServers
            // Initialize the peer connection
            peerConnection = WebRTCManager.factory.peerConnection(with: peerConnectionConfig, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self)
        }
    private func sendIceCandidate(_ candidate: RTCIceCandidate, toStreamId streamId: String) {
        let candidateDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "session_id": streamId
        ]
        
        do {
            let candidateData = try JSONSerialization.data(withJSONObject: candidateDict, options: [])
            sendIceData(candidateData, forStreamId: streamId) { result in
                switch result {
                case .success():
                    print("ICE candidate sent successfully")
                case .failure(let error):
                    print("Failed to send ICE candidate: \(error)")
                }
            }
        } catch {
            print("Failed to serialize ICE candidate: \(error)")
        }
    }


    // Helper function to send data to the server
    private func sendIceData(_ data: Data, forStreamId streamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/talks/streams/\(streamId)/ice") else {
            print("Invalid URL for sending ICE data")
            completion(.failure(WebRTCManagerError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = data
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("HTTP request error when sending ICE data: \(error)")
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("Received HTTP response for ICE candidate: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    print("Server returned an error status code: \(httpResponse.statusCode)")
                    completion(.failure(WebRTCManagerError.serverError))
                }
            } else {
                print("Unexpected response type")
                completion(.failure(WebRTCManagerError.serverError))
            }
        }
        
        dataTask.resume()
    }

        // Function to start the media exchange or enable user interaction with the stream
        func startSession() {
            // This method should be called after the peer connection is fully configured
            // It might start the media exchange or enable the user to interact with the stream
        }
        
        // Function to close the peer connection and clean up resources
        func destroySession() {
            // Close the peer connection and clean up resources
        }
    }


    // ... existing delegate

extension WebRTCManager: RTCPeerConnectionDelegate  {
    
    // Called when the ICE gathering state changes
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed to: \(newState.rawValue)")
        DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.updateIceGatheringStatus(newState)
            }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE gathering state changed to: \(newState.rawValue)")
        DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.updateICEConnectionState(newState)
            }
        }
    
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate?) {
        print("ICE candidate generated: \(String(describing: candidate))")
        
        guard let streamId = self.sessionID else { return }
        if let candidate = candidate {
            sendIceCandidate(candidate, toStreamId: streamId)
        } else {
            // End-of-candidates signal
            print("End of ICE candidates")
        }
    }


    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.updatePeerConnectionStatus(newState)
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.updateSignalingStatus(stateChanged)
        }
        
    }

    // Called when the negotiation is needed, but not used in this context
    @objc func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Negotiation needed - not directly used")
    }
    
    
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // Handle added stream
        print("Stream added: \(stream)")
        //Check that ther is at least one video trakc in the stream
        if let videoTrack = stream.videoTracks.first {
            // Create and set up the remote video view
                   setupRemoteVideo()
            
            // Add the video track to the remote video view
                   DispatchQueue.main.async { [weak self] in
                       guard let self = self, let remoteView = self.remoteVideoView else { return }
                       videoTrack.add(remoteView)
            }
        }
    }
    

    // Called when a stream is removed from the connection
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed: \(stream)")
    }

    

    // Called when ICE candidates are removed (not typically used)
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE candidates removed: \(candidates)")
    }

    // Called when a data channel is opened (if used)
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened: \(dataChannel)")
    }

    // ... Other existing methods ...
}
extension RTCSdpType {
    var stringValue: String {
        switch self {
        case .offer: return "offer"
        case .prAnswer: return "prAnswer"
        case .answer: return "answer"
        case .rollback:
            return "rollback"
        @unknown default: return "unknown" // This handles any other cases
        }
    }
}
