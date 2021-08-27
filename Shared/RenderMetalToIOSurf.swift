//
//  RenderMetalToIOSurf.swift
//  RenderMetalToIOSurf
//
//  Created by Andrew Pouliot on 8/26/21.
//

import Foundation
import Metal

enum MetalFailure: Error {
    case makeQueue
    case createDeviceAndLibrary
    case pipelineCreation(underlying: Error)
    case couldNotBeginRender
}

struct MetalFragmentRenderer {
    
    let function: MTLFunction
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState
    let destinationFormat: MTLPixelFormat = .rgba16Float
    
    init(shaderName: String) throws /*MetalFailure*/ {
        guard let device = MTLCreateSystemDefaultDevice(),
              let lib = device.makeDefaultLibrary(),
              let function = lib.makeFunction(name: shaderName),
              let vertexFunc = lib.makeFunction(name: "fullscreenTriangleVertex")
        else {
            throw MetalFailure.createDeviceAndLibrary
        }
        self.device = device
        self.function = function
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.colorAttachments[0].pixelFormat = destinationFormat
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = function

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            throw MetalFailure.pipelineCreation(underlying: error)
        }
    }
    
    func makeDestinationTextureDescriptor(width: Int, height: Int) -> MTLTextureDescriptor {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: destinationFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = .renderTarget
        return desc
    }
    
    func enqueue(in buf: MTLCommandBuffer, writeTo dest: MTLTexture) throws {
        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].loadAction = .dontCare
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].texture = dest
        passDesc.renderTargetWidth = dest.width
        passDesc.renderTargetHeight = dest.height
        //  passDesc.threadgroupMemoryLength
        //  passDesc.tileWidth = 32
        //  passDesc.tileHeight = 32
        guard let renderEncoder = buf.makeRenderCommandEncoder(descriptor: passDesc)
        else {
            throw MetalFailure.couldNotBeginRender
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
    }
}
