//
//  RenderDestination.swift
//  RenderDestination
//
//  Created by Andrew Pouliot on 8/26/21.
//

import Foundation

import CoreVideo
import IOSurface
import Metal

func makeRenderDest(device: MTLDevice, descriptor: MTLTextureDescriptor) -> (IOSurface, MTLTexture)? {
    let width = descriptor.width
    let height = descriptor.height
    let cvPixFmt = kCVPixelFormatType_64RGBAHalf
    let mtlPixFmt = MTLPixelFormat.rgba16Float
    let outputColorSpaceName = CGColorSpace.extendedLinearDisplayP3
    guard descriptor.pixelFormat == mtlPixFmt else {
        return nil
    }
    
    let bytesPerPixel = (16 / 8) * 4
    
    guard let ioSurf = IOSurface(properties: [
        .bytesPerRow: bytesPerPixel * width,
        .bytesPerElement: bytesPerPixel,
        .width: width,
        .height: height,
        .pixelFormat: cvPixFmt,
    ])
    else { return nil }

    let ioSurfRef = unsafeBitCast(ioSurf, to: IOSurfaceRef.self)
    IOSurfaceSetValue(ioSurfRef, "IOSurfaceColorSpace" as CFString, outputColorSpaceName)

    guard let texture = device.makeTexture(descriptor: descriptor, iosurface: ioSurfRef, plane: 0)
    else { return nil }

    return (ioSurf, texture)
}
