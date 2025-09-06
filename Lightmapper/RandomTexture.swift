//
//  RandomTexture.swift
//  Lightmapper
//
//  Created by Leo Battle on 05/09/2025.
//

import Metal

class RandomTexture {
    public let tex: MTLTexture
    
    init?(device: MTLDevice, width: Int, height: Int) {
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Uint, width: width, height: height, mipmapped: false)
        texDesc.usage = .shaderRead
        texDesc.storageMode = .shared
        
        guard let tex = device.makeTexture(descriptor: texDesc) else {
            return nil
        }
        self.tex = tex
        
        var randomData: [UInt32] = Array(repeating: 0, count: width * height)
        fill_random(&randomData, Int32(randomData.count))
        tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: randomData, bytesPerRow: width * 4)
    }
}
