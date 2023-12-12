//
//  ViewController.swift
//  d-idWebRTC
//
//  Created by Robin von Hardenberg on 03.11.23.
//

import UIKit
import WebRTC

class ViewController: UIViewController {
    
    var webRTCManager = WebRTCManager()
    
    @IBOutlet weak var videoContainerView: UIView!
    
    
    @IBAction func CreateNewSession(_ sender: UIButton) {
        webRTCManager.createNewStream { [weak self] result in
            switch result {
            case .success(let streamResponse):
                // Store the streamResponse for potential future use
                self?.webRTCManager.currentStreamResponse = streamResponse
                print("Stream created with ID: \(streamResponse.id)")
                
                // Step 2: Configure Peer Connection with ICE servers from the response
                self?.webRTCManager.configurePeerConnection(with: streamResponse.iceServers)
                
                // Step 3: Set Remote Description and Create/Send SDP Answer
                self?.webRTCManager.setRemoteDescriptionAndCreateAnswer(streamResponse: streamResponse, completion: { error in
                    if let error = error {
                        print("Failed to set remote description and create/send answer: \(error.localizedDescription)")
                    } else {
                        print("SDP Answer created and sent successfully.")
                        // At this point, the SDP exchange is complete.
                        // You can now proceed to step 4, which is typically handled by the WebRTCManager.
                    }
                })
                
            case .failure(let error):
                print("Failed to create stream: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func StartNewSession(_ sender: UIButton) {
        
    }
    
    
    @IBAction func DestroySession(_ sender: UIButton) {
    }
    
    
    @IBOutlet weak var IceGatheringLabel: UILabel!
    
    
    @IBOutlet weak var ICEstatusLabel: UILabel!
    
    
    @IBOutlet weak var PeerConnectionLabel: UILabel!
    
    
    @IBOutlet weak var SignallingLabel: UILabel!
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webRTCManager.delegate = self
        // Do any additional setup after loading the view.
    }
    
    
}


extension ViewController: RTCVideoViewDelegate, WebRTCManagerDelegate {
 
    
     func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
       
     }
     
    func setupRemoteVideoView(view: UIView) {
        videoContainerView.addSubview(view)
        view.frame = videoContainerView.bounds
    }
    
    func updateIceGatheringStatus(_ state: RTCIceGatheringState) {
        // Convert the RTCIceGatheringState to a readable string
        let stateDescription: String
        switch state {
        case .new:
            stateDescription = "New"
        case .gathering:
            stateDescription = "Gathering"
        case .complete:
            stateDescription = "Complete"
        @unknown default:
            stateDescription = "Unknown"
        }
        print(stateDescription)
        DispatchQueue.main.async {
            self.IceGatheringLabel.text = stateDescription
        }
    }

    

    func updateICEConnectionState(_ state: RTCIceConnectionState) {
        // Convert the RTCIceConnectionState to a readable string
        let stateDescription: String
        switch state {
        case .new:
            stateDescription = "New"
        case .checking:
            stateDescription = "Checking"
        case .connected:
            stateDescription = "Connected"
        case .completed:
            stateDescription = "Completed"
        case .failed:
            stateDescription = "Failed"
        case .disconnected:
            stateDescription = "Disconnected"
        case .closed:
            stateDescription = "Closed"
        case .count:
            stateDescription = "Count"
        @unknown default:
            stateDescription = "Unknown"
        }
        print(stateDescription)
        DispatchQueue.main.async{
            self.ICEstatusLabel.text = stateDescription
        }
    }

    func updatePeerConnectionStatus(_ state: RTCPeerConnectionState) {
        // Convert the RTCPeerConnectionState to a readable string
        let stateDescription: String
        switch state {
        case .new:
            stateDescription = "New"
        case .connecting:
            stateDescription = "Connecting"
        case .connected:
            stateDescription = "Connected"
        case .disconnected:
            stateDescription = "Disconnected"
        case .failed:
            stateDescription = "Failed"
        case .closed:
            stateDescription = "Closed"
        @unknown default:
            stateDescription = "Unknown"
        }
        print(stateDescription)
        DispatchQueue.main.async {
            self.PeerConnectionLabel.text = stateDescription
        }
    }
    
    func updateSignalingStatus(_ state: RTCSignalingState) {
        // Convert the RTCSignalingState to a readable string
        let stateDescription: String
        switch state {
        case .stable:
            stateDescription = "Stable"
        case .haveLocalOffer:
            stateDescription = "Local Offer"
        case .haveLocalPrAnswer:
            stateDescription = "Local PrAnswer"
        case .haveRemoteOffer:
            stateDescription = "Remote Offer"
        case .haveRemotePrAnswer:
            stateDescription = "Remote PrAnswer"
        case .closed:
            stateDescription = "Closed"
        @unknown default:
            stateDescription = "Unknown"
        }
        print(stateDescription)
        DispatchQueue.main.async {
            self.SignallingLabel.text = stateDescription
        }
    }

}








