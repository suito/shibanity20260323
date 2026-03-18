import SwiftUI
import ARKit
import SceneKit

struct CameraPreviewView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.showsStatistics = false
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
