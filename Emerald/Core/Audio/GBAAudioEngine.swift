//
//  GBAAudioEngine.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import AVFoundation
import OSLog

final class GBAAudioEngine {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "AudioEngine")
    
    private let audioEngine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let playerNode = AVAudioPlayerNode()
    
    // Audio buffer properties
    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 1024
    
    init() throws {
        // Configure audio engine (AVAudioSession is iOS-only, not needed on macOS)
        audioEngine.attach(mixer)
        audioEngine.attach(playerNode)
        
        // Connect nodes
        audioEngine.connect(playerNode, to: mixer, format: nil)
        audioEngine.connect(mixer, to: audioEngine.outputNode, format: nil)
        
        // Start the engine
        try audioEngine.start()
        
        logger.info("Audio engine initialized")
    }
    
    func playAudioBuffer(_ buffer: [Float]) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return
        }
        
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buffer.count / 2)) else {
            return
        }
        
        audioBuffer.frameLength = AVAudioFrameCount(buffer.count / 2)
        
        // Copy stereo samples
        for i in 0..<Int(audioBuffer.frameLength) {
            audioBuffer.floatChannelData?[0][i] = buffer[i * 2]     // Left
            audioBuffer.floatChannelData?[1][i] = buffer[i * 2 + 1] // Right
        }
        
        playerNode.scheduleBuffer(audioBuffer, at: nil, options: [], completionHandler: nil)
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    func setVolume(_ volume: Float) {
        playerNode.volume = volume
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func resume() {
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    func stop() {
        playerNode.stop()
        audioEngine.stop()
    }
}