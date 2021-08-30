//
//  ContentView.swift
//  Shared
//
//  Created by Andrew Pouliot on 8/26/21.
//

import SwiftUI
import MetalKit

extension MTLCommandBufferDescriptor {
    static let reportError: MTLCommandBufferDescriptor = {
        let errorStatus = MTLCommandBufferDescriptor()
        errorStatus.errorOptions = .encoderExecutionStatus
        return errorStatus
    }()
}

enum Strategy {
    case singlePassFragment
    case multiPassFragment
    case compute
}

struct Images {
    static let img_2118_crop: URL = Bundle.main.url(forResource: "IMG_2118_cropped_2048", withExtension: "tiff")!
}

class RenderManager: ObservableObject {
    let q: MTLCommandQueue
    let multiPass: MetalFragmentRenderer
    let singlePass: MetalFragmentRenderer
    let compute: MetalComputeRenderer
    let scope: MTLCaptureScope
    
    let inputTexture: MTLTexture
    
    init() throws /*MetalFailure, MTKTextureLoaderError? */ {
        let multi = try MetalFragmentRenderer(shaderNames: ["fragmentShader0", "fragmentShader1", "fragmentShader2"])
        let single = try MetalFragmentRenderer(shaderNames: ["fragmentShader012"])
        let compute = try MetalComputeRenderer(shaderNames: ["computeShader012"])
        
        let device = multi.device

        let loader = MTKTextureLoader(device: device)
        inputTexture = try loader.newTexture(URL: Images.img_2118_crop, options: [.textureStorageMode: MTLStorageMode.private.rawValue])

        guard let q = device.makeCommandQueue()
        else { throw MetalFailure.makeQueue }
        
        let scope = MTLCaptureManager.shared().makeCaptureScope(device: q.device)
        scope.label = "ImageRenderer"
        self.scope = scope
        
        self.q = q
        self.multiPass = multi
        self.singlePass = single
        self.compute = compute
    }
}

extension NumberFormatter {
    static var ms: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = 4
        n.minimumFractionDigits = 4
        return n
    }()
}

struct ContentView: View {
    struct ExecutionInfo {
        var gpuTime: Double
        var kernelTime: Double
    }
    
    @State var displaySurface: IOSurface? = nil
    @State var error: Error? = nil
    @State var gpuInfo: ExecutionInfo? = nil

    @State var strategy: Strategy = .singlePassFragment

    // Hold on to renderer
    @StateObject var context = try! RenderManager()

    func render() {
        do {
            let inputTexture = context.inputTexture
//            let sourceSize = (width: 2048, height: 2048)
            let sourceSize = (width: inputTexture.width, height: inputTexture.height)

            let destTexDesc: MTLTextureDescriptor
            switch strategy {
            case .singlePassFragment:
                destTexDesc = context.singlePass.makeDestinationTextureDescriptor(width: sourceSize.width, height: sourceSize.height)
            case .multiPassFragment:
                destTexDesc = context.multiPass.makeDestinationTextureDescriptor(width: sourceSize.width, height: sourceSize.height)
            case .compute:
                destTexDesc = context.compute.makeDestinationTextureDescriptor(width: sourceSize.width, height: sourceSize.height)

            }


            guard let renderDest = makeIOSurfaceRenderDest(device: context.multiPass.device, descriptor: destTexDesc)
            else { return }
            
            context.scope.begin()
            
            guard let buf = context.q.makeCommandBuffer(descriptor: .reportError)
            else { return }
            
            let (iosurf, tex) = renderDest
            switch strategy {
            case .singlePassFragment:
                try context.singlePass.enqueue(in: buf, from: inputTexture,  writeTo: tex)
            case .multiPassFragment:
                try context.multiPass.enqueue(in: buf, from: inputTexture, writeTo: tex)
            case .compute:
                try context.compute.enqueue(in: buf, from: inputTexture, writeTo: tex)
            }


            buf.addCompletedHandler{buf in
                print("Completed buffer \(buf)")
                if let error = buf.error {
                    print("Buffer error \(error)")
                } else {
                    gpuInfo = ExecutionInfo(
                        gpuTime: buf.gpuEndTime - buf.gpuStartTime,
                        kernelTime: buf.kernelEndTime - buf.kernelStartTime
                    )
                }
                displaySurface = iosurf
            }
            
            buf.commit()
            context.scope.end()

        } catch {
            print("Error")
        }
    }
    func ms(_ seconds: Double) -> String {
        guard let f = NumberFormatter.ms.string(from: seconds * 1000 as NSNumber)
        else { return "" }
        return "\(f)ms"
    }
    
    var body: some View {
        IOSurfaceView(surface: displaySurface)
            .frame(width: 256, height: 256)
        Button("Render") {
            render()
        }
        Picker("Stratgey", selection: $strategy) {
            Text("Single-pass")
                .tag(Strategy.singlePassFragment)
            Text("Multi-pass")
                .tag(Strategy.multiPassFragment)
            Text("Compute")
                .tag(Strategy.compute)
        }
        if let gpuInfo = gpuInfo {
            Text("GPU: \(ms(gpuInfo.gpuTime))")
            Text("Kernel: \(ms(gpuInfo.kernelTime))")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
