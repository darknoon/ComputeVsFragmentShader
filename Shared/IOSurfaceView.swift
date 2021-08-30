//
//  IOSurfaceView.swift
//  IOSurfaceView
//
//  Created by Andrew Pouliot on 8/27/21.
//

import Foundation
import SwiftUI

#if os(macOS)
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
        let v = NSView(frame: .zero)
        v.wantsLayer = true
        updateNSView(v, context: context)
        return v
    }
    
    func updateNSView(_ v: NSView, context: Context) {
        v.layer?.contents = surface ?? CGColor(red: 0, green: 1, blue: 1, alpha:0)
        v.layer?.transform = CATransform3DMakeScale(1.0001, 1.0001, 1.0)
    }
}

#endif


#if os(iOS)
struct IOSurfaceView: UIViewRepresentable {
    
    
    var surface: IOSurface? = nil
    
    final class Coordinator {
        var layer: CALayer? = nil
        init(){}
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        updateUIView(v, context: context)
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        v.layer.contents = surface ?? CGColor(red: 0, green: 1, blue: 1, alpha:0)
        v.layer.transform = CATransform3DMakeScale(1.0001, 1.0001, 1.0)
    }
}

#endif
