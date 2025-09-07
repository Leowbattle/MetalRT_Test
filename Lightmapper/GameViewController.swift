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
        
//        openSwiftUIWindow()
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

import AppKit
import SwiftUI
import Charts

// 1️⃣ Define some SwiftUI content
struct MySwiftUIView: View {
    var body: some View {
        Chart {
            ForEach(Array([0,2,3,4].enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
            }
        }
        .chartXAxisLabel("Samples")
        .chartYAxisLabel("A")
        .frame(height: 200)
        .padding()
    }
}

// 2️⃣ Helper function to open a new window
func openSwiftUIWindow() {
    // Create the SwiftUI view
    let contentView = MySwiftUIView()
    
    // Wrap it in an NSHostingController
    let hostingController = NSHostingController(rootView: contentView)
    
    // Create a window for the controller
    let window = NSWindow(contentViewController: hostingController)
    window.title = "SwiftUI Window"
    window.setContentSize(NSSize(width: 300, height: 200))
    window.styleMask = [.titled, .resizable]
    window.center()
    window.makeKeyAndOrderFront(nil)
}

#Preview {
    MySwiftUIView()
}
