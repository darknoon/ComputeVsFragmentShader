//
//  Render.swift
//  Render
//
//  Created by Andrew Pouliot on 8/26/21.
//

import Foundation
import CoreImage
import IOSurface
import CoreImage.CIFilterBuiltins

#if false
// render CVPixelBuffer
func renderFrameToIOSurface(frame: CVPixelBuffer) -> IOSurface? {
    var options: [CIImageOption : Any] = [:]
    options[.applyOrientationProperty] = true
    let im = CIImage(cvPixelBuffer: frame, options: options)

    // Filter image
    let f = CIFilter.gaussianBlur()
    f.inputImage = im
    f.radius = 3.0
    let outputImage = f.outputImage!
    
    let cvWidth = CVPixelBufferGetWidth(frame)
    let cvHeight = CVPixelBufferGetHeight(frame)
    let cvPixFmt = kCVPixelFormatType_64RGBAHalf
    let mtlPixFmt = MTLPixelFormat.rgba16Float
    let outputColorSpaceName = CGColorSpace.itur_2100_HLG
    let bytesPerPixel = (16 / 8) * 4
    
    guard let ioSurf = IOSurface(properties: [
        .bytesPerRow: bytesPerPixel * cvWidth,
        .bytesPerElement: bytesPerPixel,
        .width: cvWidth,
        .height: cvHeight,
        .pixelFormat: cvPixFmt,
    ]) else { return nil }
    IOSurfaceSetValue(ioSurf as IOSurfaceRef, "IOSurfaceColorSpace" as CFString, outputColorSpaceName)
    
    let d = MTLTextureDescriptor()
    d.storageMode = .shared
    d.usage = [.shaderWrite]
    d.width = cvWidth
    d.height = cvHeight
    d.pixelFormat = mtlPixFmt
    
    guard let texture = device.makeTexture(descriptor: d, iosurface: ioSurf, plane: 0) else { return nil }

    context.render(outputImage, to: texture, commandBuffer: nil, bounds: im.extent, colorSpace: outputColorSpace)
    
    return ioSurf
}

#endif
