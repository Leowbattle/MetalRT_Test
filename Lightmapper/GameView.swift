//
//  GameView.swift
//  Lightmapper
//
//  Created by Leo Battle on 07/09/2025.
//

import Cocoa
import Metal
import MetalKit

protocol GameViewDelegate {
    func keyDown(with event: NSEvent)
    func keyUp(with event: NSEvent)
    func mouseDragged(with event: NSEvent)
}

class GameView : MTKView {
    var inputDelegate: GameViewDelegate?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        inputDelegate?.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) {
        inputDelegate?.keyUp(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        inputDelegate?.mouseDragged(with: event)
    }
}
