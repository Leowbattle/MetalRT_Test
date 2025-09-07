//
//  Camera.swift
//  Lightmapper
//
//  Created by Leo Battle on 05/09/2025.
//

import AppKit
import Foundation

protocol Camera {
    var viewMatrix: simd_float4x4 { get }
    
    func update(keys: Set<String>, dt: Float)
    func mouseDragged(dx: Float, dy: Float)
}

extension Camera {
    func update(keys: Set<String>, dt: Float) {}
    func mouseDragged(dx: Float, dy: Float) {}
}

class OrbitalCamera : Camera {
    var viewMatrix: simd_float4x4 {
        return simd_float4x4()
    }
}
