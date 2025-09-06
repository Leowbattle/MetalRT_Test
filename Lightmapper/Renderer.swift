//
//  Renderer.swift
//  Lightmapper
//
//  Created by Leo Battle on 04/09/2025.
//

// Our platform independent renderer class

import Metal
import MetalKit
import ModelIO
import simd

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let depthState: MTLDepthStencilState
    
    var size: CGSize = CGSize()
    
    var aspectRatio: Float {
        return Float(size.width / size.height)
    }
    
    var randomTexture: RandomTexture!
    
    let library: MTLLibrary!
    let pipeline: MTLRenderPipelineState!
    
    let vertexDescriptor: MTLVertexDescriptor
    var mesh: MTKMesh!
    var accelerationStructure: MTLAccelerationStructure!
    let tex: MTLTexture!
    
    let uniformBuffer: MTLBuffer!
    
    var frameIndex: Int32 = 0
    
    var lightmapRenderer: AsyncLightmapRenderer! = nil
    
    fileprivate func loadMesh() {
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        (mdlVertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (mdlVertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (mdlVertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        let modelURL = Bundle.main.url(forResource: "Duck.obj", withExtension: nil)
        let asset = MDLAsset(url: modelURL, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: bufferAllocator)
        
        let (_, mtkMeshes) = try! MTKMesh.newMeshes(asset: asset, device: device)
        mesh = mtkMeshes[0]
        
        mesh.vertexBuffers[0].buffer.label = "Vertex Buffer"
        mesh.submeshes[0].indexBuffer.buffer.label = "Index Buffer"
    }
    
    func buildAccelerationStructure() {
        let submesh = mesh.submeshes[0]
        
        let indexElementSize = (submesh.indexType == .uint16) ? MemoryLayout<UInt16>.size : MemoryLayout<UInt32>.size;
        
        let triDesc = MTLAccelerationStructureTriangleGeometryDescriptor()
        triDesc.label = "Triangle Acceleration Structure"
        triDesc.triangleCount = submesh.indexBuffer.length / indexElementSize / 3
        triDesc.vertexBuffer = mesh.vertexBuffers[0].buffer
        triDesc.vertexStride = 8 * MemoryLayout<Float>.size
        triDesc.vertexFormat = .float3
        triDesc.indexBuffer = submesh.indexBuffer.buffer
        triDesc.indexType = submesh.indexType
        triDesc.indexBufferOffset = submesh.indexBuffer.offset
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
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDescriptor)!
        
        library = device.makeDefaultLibrary()!
        
        vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 3 * MemoryLayout<Float>.size
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 6 * MemoryLayout<Float>.size
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 8
        
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        desc.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        desc.vertexDescriptor = vertexDescriptor
        desc.vertexFunction = library.makeFunction(name: "vert_main")
        desc.fragmentFunction = library.makeFunction(name: "frag_main")
        
        pipeline = try! device.makeRenderPipelineState(descriptor: desc)
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .cpuCacheModeWriteCombined)!
        
        let texSize = 1024
        
        let texDesc = MTLTextureDescriptor()
        texDesc.width = texSize
        texDesc.height = texSize
        texDesc.pixelFormat = .r8Unorm
        texDesc.usage = .renderTarget.union(.shaderRead)
        texDesc.storageMode = .shared
        texDesc.textureType = .type2D
        tex = device.makeTexture(descriptor: texDesc)!
        
        var texData: [UInt8] = Array(repeating: 0, count: texSize * texSize)
        for i in 0..<texSize {
            for j in 0..<texSize {
                texData[i * texSize + j] = UInt8(truncatingIfNeeded: i ^ j)
            }
        }
        
        tex.replace(region: MTLRegion(origin: MTLOrigin(), size: MTLSize(width: texSize, height: texSize, depth: 1)), mipmapLevel: 0, withBytes: texData, bytesPerRow: texSize)
        
        super.init()
        
        loadMesh()
        buildAccelerationStructure()
        
        lightmapRenderer = AsyncLightmapRenderer(device: device, commandQueue: commandQueue, size: 1024, mesh: mesh, accel: accelerationStructure)
        lightmapRenderer.start()
    }

    var angle: Float = 0.0
    func draw(in view: MTKView) {
        view.clearColor = .init(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        angle += 90 * .pi / 180 / 60
        
        var uniforms = Uniforms()
        uniforms.frameIndex = frameIndex
        let proj = matrix_perspective_right_hand(fovyRadians: 90 * .pi / 180, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 50)
        var viewMat = matrix4x4_translation(0, -0.5, -1)
        viewMat = viewMat * matrix4x4_rotation(radians: angle, axis: simd_float3(0, 1, 0))
        uniforms.viewProj = proj * viewMat
        uniforms.view = viewMat
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        let submesh = mesh.submeshes[0]
        
        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(submesh.indexBuffer.buffer, offset: 0, index: 2)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(lightmapRenderer.copyingTexture, index: 0)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        
        frameIndex += 1
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.size = size
        let width = Int(size.width)
        let height = Int(size.height)
        
        randomTexture = RandomTexture(device: device, width: width, height: height)!
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
