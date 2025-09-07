//
//  MPS_MSE.swift
//  Lightmapper
//
//  Created by Leo Battle on 07/09/2025.
//

import MetalPerformanceShaders

// A filter for calculating the MSE between two images using Metal Performance Shaders
// MSE is undocumented garbage?
class MPS_MSE {
    let device: MTLDevice
    let sub: MPSImageSubtract
    let mul: MPSImageMultiply
    let mean: MPSImageStatisticsMean
    
    init(device: MTLDevice) {
        self.device = device
        sub = MPSImageSubtract(device: device)
        mul = MPSImageMultiply(device: device)
        mean = MPSImageStatisticsMean(device: device)
        
        sub.label = "Sub"
        mul.label = "Mul"
        mean.label = "Mean"
    }
    
    func encode(commandBuffer: MTLCommandBuffer, a: MTLTexture, b: MTLTexture, dest: UnsafeMutablePointer<any MTLTexture>) {
//        mul.encode(commandBuffer: commandBuffer, primaryTexture: a, secondaryTexture: b, destinationTexture: dest.pointee)
        sub.encode(commandBuffer: commandBuffer, primaryTexture: a, secondaryTexture: b, destinationTexture: dest.pointee)
        mul.encode(commandBuffer: commandBuffer, inPlacePrimaryTexture: dest, secondaryTexture: dest.pointee)
        
        mean.clipRectSource = MPSRectNoClip
        mean.encode(commandBuffer: commandBuffer, inPlaceTexture: dest)
    }
}
