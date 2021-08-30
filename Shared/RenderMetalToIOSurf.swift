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
    
    let functions: [MTLFunction]
    let device: MTLDevice
    let pipelineStates: [MTLRenderPipelineState]
    let destinationFormat: MTLPixelFormat = .rgba16Float
    
    init(shaderNames: [String]) throws /*MetalFailure*/ {
        guard let device = MTLCreateSystemDefaultDevice(),
              let lib = device.makeDefaultLibrary(),
              let vertexFunc = lib.makeFunction(name: "fullscreenTriangleVertex")
        else {
            throw MetalFailure.createDeviceAndLibrary
        }
        
        let functions = shaderNames.compactMap{lib.makeFunction(name: $0)}
        
        self.device = device
        self.functions = functions
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.colorAttachments[0].pixelFormat = destinationFormat
        pipelineDesc.colorAttachments[1].pixelFormat = destinationFormat
//        pipelineDesc.colorAttachments[2].pixelFormat = destinationFormat
        pipelineDesc.vertexFunction = vertexFunc

        do {
            pipelineStates = try functions.map{
                pipelineDesc.fragmentFunction = $0
                return try device.makeRenderPipelineState(descriptor: pipelineDesc)
            }
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
        // Assert: IOSurface textures must use MTLStorageModeShared
        desc.storageMode = .shared
        return desc
    }
    
    private func makeTempTextureDescriptor(width: Int, height: Int) -> MTLTextureDescriptor {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: destinationFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = .renderTarget
        if device.hasUnifiedMemory {
            desc.storageMode = .memoryless
        }
        return desc
    }

    
    func enqueue(in buf: MTLCommandBuffer, writeTo dest: MTLTexture) throws {
        let width = dest.width
        let height = dest.height
        
        let tempDesc = makeTempTextureDescriptor(width: width, height: height)
        let temp0 = device.makeTexture(descriptor: tempDesc)
        temp0?.label = "temp0"
//        let temp1 = device.makeTexture(descriptor: tempDesc)
//        temp1?.label = "temp1"

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].loadAction = .dontCare
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].texture = dest
        
        passDesc.colorAttachments[1].texture = temp0
        passDesc.colorAttachments[1].loadAction = .dontCare
        passDesc.colorAttachments[1].storeAction = .dontCare
//        passDesc.colorAttachments[2].texture = temp1
//        passDesc.colorAttachments[2].loadAction = .dontCare
//        passDesc.colorAttachments[2].storeAction = .dontCare

        passDesc.renderTargetWidth = dest.width
        passDesc.renderTargetHeight = dest.height
        //  passDesc.threadgroupMemoryLength
        //  passDesc.tileWidth = 32
        //  passDesc.tileHeight = 32
        guard let renderEncoder = buf.makeRenderCommandEncoder(descriptor: passDesc)
        else {
            throw MetalFailure.couldNotBeginRender
        }
//        renderEncoder.setFragmentTexture(inputTexture, index: 0)
        for pipelineState in pipelineStates {
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        renderEncoder.endEncoding()
    }
}


struct MetalComputeRenderer {
    
    let functions: [MTLFunction]
    let device: MTLDevice
    let pipelineStates: [MTLComputePipelineState]
    let destinationFormat: MTLPixelFormat = .rgba16Float
    
    init(shaderNames: [String]) throws /*MetalFailure*/ {
        guard let device = MTLCreateSystemDefaultDevice(),
              let lib = device.makeDefaultLibrary()
        else {
            throw MetalFailure.createDeviceAndLibrary
        }
        
        let functions = shaderNames.compactMap{lib.makeFunction(name: $0)}
        
        self.device = device
        self.functions = functions
        
        do {
            pipelineStates = try functions.map{
                try device.makeComputePipelineState(function: $0)
            }
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
        desc.usage = .shaderWrite
        // Assert: IOSurface textures must use MTLStorageModeShared
        desc.storageMode = .shared
        return desc
    }
    
//    private func makeTempTextureDescriptor(width: Int, height: Int) -> MTLTextureDescriptor {
//        let desc = MTLTextureDescriptor.texture2DDescriptor(
//            pixelFormat: destinationFormat,
//            width: width,
//            height: height,
//            mipmapped: false
//        )
//        desc.usage = .renderTarget
//        if device.hasUnifiedMemory {
//            desc.storageMode = .memoryless
//        }
//        return desc
//    }
//
    
    func enqueue(in buf: MTLCommandBuffer, writeTo dest: MTLTexture) throws {
        let width = dest.width
        let height = dest.height
        
//        let tempDesc = makeTempTextureDescriptor(width: width, height: height)
//        let temp0 = device.makeTexture(descriptor: tempDesc)
//        temp0?.label = "temp0"
//        let temp1 = device.makeTexture(descriptor: tempDesc)
//        temp1?.label = "temp1"

        guard let computeEncoder = buf.makeComputeCommandEncoder()
        else {
            throw MetalFailure.couldNotBeginRender
        }
//        renderEncoder.setFragmentTexture(inputTexture, index: 0)
        for pipelineState in pipelineStates {
            computeEncoder.setTexture(dest, index: 1)
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.dispatchThreads(
                MTLSize(width: width, height: height, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1)
            )
        }
        computeEncoder.endEncoding()
    }
}
