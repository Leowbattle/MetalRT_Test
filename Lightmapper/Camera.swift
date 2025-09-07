//
//  Camera.swift
//  Lightmapper
//
//  Created by Leo Battle on 05/09/2025.
//

import AppKit
import Foundation
import simd

// MARK: - Camera Protocol

protocol Camera {
    var viewMatrix: simd_float4x4 { get }
    func update(keys: Set<String>, dt: Float)
    func mouseDragged(dx: Float, dy: Float)
}

// Default empty implementations so subclasses can ignore what they don't need
extension Camera {
    func update(keys: Set<String>, dt: Float) {}
    func mouseDragged(dx: Float, dy: Float) {}
}

// MARK: - First-Person Camera

class FirstPersonCamera: Camera {
    var pos = SIMD3<Float>(0, 0, 0)
    var forward = SIMD3<Float>(0, 0, 0)
    var right = SIMD3<Float>(0, 0, 0)
    var up = SIMD3<Float>(0, 0, 0)
    
    /// yaw = rotation around Y, pitch = rotation around X
    var yaw: Float = 0
    var pitch: Float = 0
    
    var speed: Float = 1
    
    var viewMatrix: simd_float4x4 {
        simd_float4x4(lookAt: pos, center: pos + forward, up: up)
    }
    
    func update(keys: Set<String>, dt: Float) {
        // 1️⃣ Update orientation first
        forward = simd_normalize(SIMD3<Float>(
            cos(pitch) * sin(yaw),
            sin(pitch),
            cos(pitch) * cos(yaw)
        ))
        
        right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        up = simd_cross(right, forward)
        
        let forwardXZ = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
        let velocity = speed * dt
        
        // 2️⃣ Apply movement
        if keys.contains("w") { pos += forwardXZ * velocity }
        if keys.contains("s") { pos -= forwardXZ * velocity }
        if keys.contains("a") { pos -= right * velocity }
        if keys.contains("d") { pos += right * velocity }
        if keys.contains("q") { pos.y += velocity }
        if keys.contains("e") { pos.y -= velocity }
    }
    
    func mouseDragged(dx: Float, dy: Float) {
        yaw   -= dx * 0.01
        pitch -= dy * 0.01
        pitch = max(-.pi/2 + 0.01, min(.pi/2 - 0.01, pitch)) // Clamp pitch
    }
}

// MARK: - simd_float4x4 LookAt Extension

extension simd_float4x4 {
    /// Right-handed look-at matrix (OpenGL style)
    init(lookAt eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) {
        let f = simd_normalize(center - eye)           // forward
        let s = simd_normalize(simd_cross(f, up))      // right
        let u = simd_cross(s, f)                       // corrected up
        
        self.init(columns: (
            SIMD4<Float>( s.x,  u.x, -f.x, 0),
            SIMD4<Float>( s.y,  u.y, -f.y, 0),
            SIMD4<Float>( s.z,  u.z, -f.z, 0),
            SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        ))
    }
}
