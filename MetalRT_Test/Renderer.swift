//
//  Renderer.swift
//  MetalRT_Test
//
//  Created by Leo Battle on 02/09/2025.
//

import Metal
import MetalKit
import simd

enum RenderMode {
    case Rasterize
    case RayTrace
}

class Renderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let library: MTLLibrary!
    
    var size: CGSize = CGSize()
    
    var vertexBuffer: MTLBuffer!

    var tex: MTLTexture!
    
    var renderMode: RenderMode = .RayTrace
    var rasterPipe: MTLRenderPipelineState!
    var copyPipe: MTLRenderPipelineState!
    var rtPipe: MTLComputePipelineState!
    
    var accelerationStructure: MTLAccelerationStructure!
    
    func buildAccelerationStructure() {
        let triDesc = MTLAccelerationStructureTriangleGeometryDescriptor()
        triDesc.label = "Triangle Acceleration Structure"
        triDesc.triangleCount = 1
        triDesc.vertexBuffer = vertexBuffer
        triDesc.vertexStride = 3 * MemoryLayout<Float>.size
        triDesc.vertexFormat = .float3
        let primDesc = MTLPrimitiveAccelerationStructureDescriptor()
        primDesc.geometryDescriptors = [triDesc]
        
        let size = device.accelerationStructureSizes(descriptor: primDesc)
        let scratch = device.makeBuffer(length: size.buildScratchBufferSize)!
        
        accelerationStructure = device.makeAccelerationStructure(size: size.accelerationStructureSize)
        accelerationStructure.label = "Acceleration Structure"
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
        encoder.build(accelerationStructure: accelerationStructure, descriptor: primDesc, scratchBuffer: scratch, scratchBufferOffset: 0)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    @MainActor
    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        library = device.makeDefaultLibrary()!
        
        super.init()
        
        var data: [Float] = [
            -0.5, -0.5, 0.0,
             0.0, 0.5, 0.0,
             0.5, -0.5, 0.0
        ]
        
        vertexBuffer = device.makeBuffer(bytes: &data, length: MemoryLayout<Float>.size * data.count)!
        vertexBuffer.label = "Vertex Buffer"
        
        let vertexDesc = MTLVertexDescriptor()
        vertexDesc.attributes[0].format = .float3
        vertexDesc.attributes[0].offset = 0
        vertexDesc.attributes[0].bufferIndex = 0
        vertexDesc.layouts[0].stride = 3 * MemoryLayout<Float>.size
        
        let rasterDesc = MTLRenderPipelineDescriptor()
        rasterDesc.label = "Raster Pipeline"
        rasterDesc.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        rasterDesc.vertexFunction = library.makeFunction(name: "vertex_main")
        rasterDesc.fragmentFunction = library.makeFunction(name: "fragment_main")
        rasterDesc.vertexDescriptor = vertexDesc
        rasterDesc.vertexBuffers[0].mutability = .immutable
        rasterPipe = try! device.makeRenderPipelineState(descriptor: rasterDesc)
        
        let copyPipeDesc = MTLRenderPipelineDescriptor()
        copyPipeDesc.vertexFunction = library.makeFunction(name: "copyVertex")!
        copyPipeDesc.fragmentFunction = library.makeFunction(name: "copyFragment")!
        copyPipeDesc.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        copyPipe = try! device.makeRenderPipelineState(descriptor: copyPipeDesc)
        
        rtPipe = try! device.makeComputePipelineState(function: library.makeFunction(name: "rt_main")!)
        
        buildAccelerationStructure()
    }

    func draw(in view: MTKView) {
        view.clearColor = .init(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        switch renderMode {
        case .Rasterize:
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            renderEncoder.setRenderPipelineState(rasterPipe)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            
            renderEncoder.endEncoding()
            
        case .RayTrace:
            let compEnc = commandBuffer.makeComputeCommandEncoder()!
            
            compEnc.setComputePipelineState(rtPipe)
            compEnc.setTexture(tex, index: 0)
            compEnc.setAccelerationStructure(accelerationStructure, bufferIndex: 0)
            
            let threadsPerThreadgroup = MTLSizeMake(8, 8, 1);
            let threadgroups = MTLSizeMake((Int(size.width)  + threadsPerThreadgroup.width  - 1) / threadsPerThreadgroup.width,
                                           (Int(size.height) + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                                               1);
            compEnc.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            
            compEnc.endEncoding()
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            renderEncoder.setRenderPipelineState(copyPipe)
            renderEncoder.setFragmentTexture(tex, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.size = size
        let width = Int(size.width)
        let height = Int(size.height)
        
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        texDesc.usage = .shaderRead.union(.shaderWrite)
        tex = device.makeTexture(descriptor: texDesc)!
    }
}
