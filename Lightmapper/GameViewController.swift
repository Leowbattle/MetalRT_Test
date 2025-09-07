//
//  GameViewController.swift
//  Lightmapper
//
//  Created by Leo Battle on 04/09/2025.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController, RendererDelegate, GameViewDelegate {
    func frameWillRender(renderer: Renderer) {
        camera.update(keys: keys, dt: 1 / 60)
        
        renderer.viewMatrix = camera.viewMatrix
    }
    
    func frameRendered(renderer: Renderer) {
        
    }
    

    var renderer: Renderer!
    var mtkView: MTKView!
    
    var camera: FirstPersonCamera!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? GameView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        mtkView.inputDelegate = self
        renderer.delegate = self
        
        camera = FirstPersonCamera()
        camera.yaw = .pi
        camera.pos = simd_float3(0, 0.5, 1)
    }
    
    var keys: Set<String> = Set()
    
    override func keyDown(with event: NSEvent) {
        keys.insert(event.charactersIgnoringModifiers!)
    }
    
    override func keyUp(with event: NSEvent) {
        keys.remove(event.charactersIgnoringModifiers!)
    }
    
    override func mouseDragged(with event: NSEvent) {
        camera.mouseDragged(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }
}
