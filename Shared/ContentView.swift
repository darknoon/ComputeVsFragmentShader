//
//  ContentView.swift
//  Shared
//
//  Created by Andrew Pouliot on 8/26/21.
//

import SwiftUI

// Pipeline A:
//

struct IOSurfaceView: NSViewRepresentable {
    
    var surface: IOSurface? = nil
    
    final class Coordinator {
        var layer: CALayer? = nil
        init(){}
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        v.wantsLayer = true
        updateNSView(v, context: context)
        return v
    }
    
    func updateNSView(_ v: NSView, context: Context) {
        v.layer?.contents = surface ?? CGColor(red: 0, green: 1, blue: 1, alpha:0)
        v.layer?.transform = CATransform3DMakeScale(1.0001, 1.0001, 1.0)
    }
}

extension MTLCommandBufferDescriptor {
    static let reportError: MTLCommandBufferDescriptor = {
        let errorStatus = MTLCommandBufferDescriptor()
        errorStatus.errorOptions = .encoderExecutionStatus
        return errorStatus
    }()
}

class RenderManager: ObservableObject {
    let q: MTLCommandQueue
    let r: MetalFragmentRenderer
    let scope: MTLCaptureScope

    init() throws /*MetalFailure*/ {
        let r = try MetalFragmentRenderer(shaderName: "fillRedFrag")
        
        guard let q = r.device.makeCommandQueue()
        else { throw MetalFailure.makeQueue }
        
        q.label = "FragmentRendererQ"
        
        let scope = MTLCaptureManager.shared().makeCaptureScope(device: q.device)
        scope.label = "FragmentRenderer"
        self.scope = scope
        
        self.q = q
        self.r = r
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

    // Hold on to renderer
    @StateObject var context = try! RenderManager()

    func render() {
        do {
            let destTexDesc = context.r.makeDestinationTextureDescriptor(width: 256, height: 256)

            guard let renderDest = makeRenderDest(device: context.r.device, descriptor: destTexDesc)
            else { return }
            
            context.scope.begin()
            
            guard let buf = context.q.makeCommandBuffer(descriptor: .reportError)
            else { return }
            
            let (iosurf, tex) = renderDest
            try context.r.enqueue(in: buf, writeTo: tex)


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
