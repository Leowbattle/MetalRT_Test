//
//  AsyncLightmapRenderer.swift
//  Lightmapper
//
//  Created by Leo Battle on 05/09/2025.
//

import Foundation
import Metal
import MetalKit

// This class renders light maps on a background thread
class AsyncLightmapRenderer: Thread {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let library: MTLLibrary!
    
    let pipeline: MTLRenderPipelineState
    
    let uniformBuffer: MTLBuffer
    
    var tex: [MTLTexture]
    let copyingTexture: MTLTexture
    
    let randomTex: RandomTexture
    
    let mesh: MTKMesh
    let accelerationStructure: MTLAccelerationStructure
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue, size: Int, mesh: MTKMesh, accel: MTLAccelerationStructure) {
        self.device = device
        self.commandQueue = commandQueue
        
        library = device.makeDefaultLibrary()!
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 3 * MemoryLayout<Float>.size
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 6 * MemoryLayout<Float>.size
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 8
        
        let pipeDesc = MTLRenderPipelineDescriptor()
        pipeDesc.vertexFunction = library.makeFunction(name: "lightmap_vertex")!
        pipeDesc.fragmentFunction = library.makeFunction(name: "lightmap_fragment")!
        pipeDesc.colorAttachments[0].pixelFormat = .r32Float
        pipeDesc.vertexDescriptor = vertexDescriptor
        pipeline = try! device.makeRenderPipelineState(descriptor: pipeDesc)
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size)!
        
        let desc = MTLTextureDescriptor()
        desc.width = size
        desc.height = size
        desc.pixelFormat = .r32Float
        desc.usage = [.renderTarget, .shaderRead]
        desc.textureType = .type2D
        desc.storageMode = .private
        
        tex = [
            device.makeTexture(descriptor: desc)!,
            device.makeTexture(descriptor: desc)!
        ]
        
        tex[0].label = "Lightmap Texture 0"
        tex[1].label = "Lightmap Texture 1"
        
        desc.usage = .shaderRead
        copyingTexture = device.makeTexture(descriptor: desc)!
        copyingTexture.label = "Lightmap Copying Texture"
        
        randomTex = RandomTexture(device: device, width: size, height: size)!
        
        self.mesh = mesh
        self.accelerationStructure = accel
    }
    
    override func main() {
        var samples = 0
        while true {
            let commandBuffer = commandQueue.makeCommandBuffer()!
            
            let renderPassDesc = MTLRenderPassDescriptor()
            renderPassDesc.colorAttachments[0].texture = tex[0]
            renderPassDesc.colorAttachments[0].loadAction = .clear
            renderPassDesc.colorAttachments[0].storeAction = .store
            renderPassDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)!
            
            encoder.setRenderPipelineState(pipeline)
            
            let submesh = mesh.submeshes[0]
            encoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
            
            var uniforms = Uniforms()
            uniforms.frameIndex = Int32(samples)
            memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
            
            encoder.setFragmentTexture(randomTex.tex, index: 0)
            encoder.setFragmentTexture(tex[1], index: 1)
            encoder.setFragmentAccelerationStructure(accelerationStructure, bufferIndex: 2)
            encoder.setFragmentBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 3)
            encoder.setFragmentBuffer(submesh.indexBuffer.buffer, offset: 0, index: 4)
            
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
            
            encoder.endEncoding()
            
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
            blitEncoder.copy(from: tex[0], to: copyingTexture)
            blitEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            print("Completed \(samples) samples")
            samples += 1
            
            tex.swapAt(0, 1)
//            Thread.sleep(forTimeInterval: 1)
        }
    }
}
