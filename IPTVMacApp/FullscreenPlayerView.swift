//
//  FullscreenPlayerView.swift
//  IPTVMacApp
//
//  Created by Iranildo on 01/08/25.
//

import SwiftUI
import AVKit

struct FullscreenPlayerView: View {
    @ObservedObject var controller: PlayerController
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let player = controller.player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Carregando player...")
                    .foregroundColor(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
