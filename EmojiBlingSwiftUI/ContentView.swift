//
//  ContentView.swift
//  EmojiBlingSwiftUI
//
//  Created by Chu Yong on 2023/8/3.
//
//  https://www.kodeco.com/5491-ar-face-tracking-tutorial-for-ios-getting-started
//

import SwiftUI
import ARKit

struct ContentView: View {
    var body: some View {
        VStack {
            ARViewIndicator()
        }
        .padding()
    }
}

struct ARViewIndicator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return EmojiBlingViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
    
    typealias UIViewControllerType = UIViewController
    
    
}

#Preview {
    ContentView()
}


class EmojiBlingViewController: UIViewController {
    
    var sceneView: ARSCNView = ARSCNView()
    let noseOptions = ["👃", "🐽", "💧", " "]
    let eyeOptions = ["👁", "🌕", "🌟", "🔥", "⚽️", "🔎", " "]
    let mouthOptions = ["👄", "👅", "❤️", " "]
    let hatOptions = ["🎓", "🎩", "🧢", "⛑", "👒", " "]
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard ARFaceTrackingConfiguration.isSupported else { fatalError("Face tracking is not supported on this device") }
        sceneView.delegate = self
        
        // View Constraint, auto layout
        self.view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: self.view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.sceneView.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARFaceTrackingConfiguration()
        
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    // MARK: - functions
    let features = ["nose", "leftEye", "rightEye", "mouth", "hat"]
    let featureIndices = [[9], [1064], [42], [24, 25], [20]]
    
    func updateFeatures(for node: SCNNode, using anchor: ARFaceAnchor) {
        for (feature, indices) in zip(features, featureIndices) {
            
            // 1
            let child = node.childNode(withName: feature, recursively: false) as? EmojiNode
            
            // 2
            let vertices = indices.map { anchor.geometry.vertices[$0] }
            
            // 3
            child?.updatePosition(for: vertices)
            
            switch feature {
            case "leftEye":
                let scaleX = child?.scale.x ?? 1.0
                let eyeBlinkValue = anchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0.0
                child?.scale = SCNVector3(scaleX, 1.0 - eyeBlinkValue, 1.0)
            case "rightEye":
                let scaleX = child?.scale.x ?? 1.0
                let eyeBlinkValue = anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0.0
                child?.scale = SCNVector3(scaleX, 1.0 - eyeBlinkValue, 1.0)
            case "mouth":
                let jawOpenValue = anchor.blendShapes[.jawOpen]?.floatValue ?? 0.2
                child?.scale = SCNVector3(1.0, 0.8 + jawOpenValue, 1.0)
            default:
                break
            }
        }
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, options: nil)
        if let result = results.first,
           let node = result.node as? EmojiNode {
            node.next()
        }
    }
}

// 1 Extension For View Controller
extension EmojiBlingViewController: ARSCNViewDelegate {
    
    // MARK: - Delegate
    // 2 Delegate Function
    func renderer(_ renderer: SCNSceneRenderer,
                  nodeFor anchor: ARAnchor
    ) -> SCNNode? {
        
        // 3
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let device = sceneView.device else { return nil }
        
        // 4
        let faceGeometry = ARSCNFaceGeometry(device: device)
        
        // 5
        let node = SCNNode(geometry: faceGeometry)
        
        // 6
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.geometry?.firstMaterial?.transparency = 0.0
        
        // Node
        let noseNode = EmojiNode(with: noseOptions)
        noseNode.name = "nose"
        node.addChildNode(noseNode)
        
        let leftEyeNode = EmojiNode(with: eyeOptions)
        leftEyeNode.name = "leftEye"
        leftEyeNode.rotation = SCNVector4(0, 1, 0, GLKMathDegreesToRadians(180.0))
        node.addChildNode(leftEyeNode)
        
        let rightEyeNode = EmojiNode(with: eyeOptions)
        rightEyeNode.name = "rightEye"
        node.addChildNode(rightEyeNode)
        
        let mouthNode = EmojiNode(with: mouthOptions)
        mouthNode.name = "mouth"
        node.addChildNode(mouthNode)
        
        let hatNode = EmojiNode(with: hatOptions)
        hatNode.name = "hat"
        node.addChildNode(hatNode)
        
        self.updateFeatures(for: node, using: faceAnchor)
        
        // 7
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer,
                  didUpdate node: SCNNode,
                  for anchor: ARAnchor
    ) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
        
        faceGeometry.update(from: faceAnchor.geometry)
        self.updateFeatures(for: node, using: faceAnchor)
    }
}

import SceneKit

/// 可以加载到 SceneKit 的 Node 节点
class EmojiNode: SCNNode {
    
    var options: [String]
    var index = 0
    
    init(with options: [String], width: CGFloat = 0.06, height: CGFloat = 0.06) {
        self.options = options
        
        super.init()
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = (options.first ?? " ").image()
        plane.firstMaterial?.isDoubleSided = true
        
        geometry = plane
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Custom functions

extension EmojiNode {
    
    func updatePosition(for vectors: [vector_float3]) {
        let newPos = vectors.reduce(vector_float3(), +) / Float(vectors.count)
        position = SCNVector3(newPos)
    }
    
    func next() {
        index = (index + 1) % options.count
        
        if let plane = geometry as? SCNPlane {
            plane.firstMaterial?.diffuse.contents = options[index].image()
            plane.firstMaterial?.isDoubleSided = true
        }
    }
}

import UIKit

extension String {
    
    func image() -> UIImage? {
        
        let size = CGSize(width: 20, height: 22)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.clear.set()
        
        let rect = CGRect(origin: .zero, size: size)
        UIRectFill(CGRect(origin: .zero, size: size))
        
        (self as AnyObject).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}
