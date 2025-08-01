//
//  PlayerController.swift
//  IPTVMacApp
//
//  Created by Iranildo on 01/08/25.
//

import AVKit
import Combine

class PlayerController: ObservableObject {
    @Published var player: AVPlayer?
    
    func play(url: String) {
        guard let videoURL = URL(string: url) else { return }
        let newPlayer = AVPlayer(url: videoURL)
        self.player = newPlayer
        newPlayer.play()
    }
    
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
