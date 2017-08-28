//
//  ViewController.swift
//  Cube5
//
//  Created by 小波 on 2017/7/12.
//  Copyright © 2017年 xiaobo. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController {
    let session = ARSession()
    var dragOnInfinitePlanesEnabled = false
    var screenCenter: CGPoint?
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    var trackingFallbackTimer: Timer?
    // Use average of recent virtual object distances to avoid rapid changes in object scale.
    var recentVirtualObjectDistances = [CGFloat]()
    
    let DEFAULT_DISTANCE_CAMERA_TO_OBJECTS = Float(10)
    @IBOutlet weak var arscnView: ARSCNView!
    // MARK: - Virtual Object Loading
    var virtualObject: VirtualObject? // TODO: Remove this and create an array with virtualobject
    func setupScene() {
        arscnView.setUp(viewController: self, session: session)
        DispatchQueue.main.async {
            self.screenCenter = self.arscnView.bounds.mid
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupFocusSquare()

    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //禁止程序运行时自动锁屏
        UIApplication.shared.isIdleTimerDisabled = true
        restartPlaneDetection()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //在视图即将消失的时候暂停
        session.pause()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - Focus Square
    var focusSquare: FocusSquare?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        //初始化
        focusSquare = FocusSquare()
        arscnView.scene.rootNode.addChildNode(focusSquare!)
        
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        //virtualObject 存在 && 在屏幕里显示时，focusSquare隐藏
        if virtualObject != nil && arscnView.isNode(virtualObject!, insideFrustumOf: arscnView.pointOfView!) {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
            
        }
    }

    // MARK: - Hit Test Visualization
    
    var hitTestVisualization: HitTestVisualization?

//    var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
//        didSet {
//            UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
//            if showHitTestAPIVisualization {
//                hitTestVisualization = HitTestVisualization(sceneView: arscnView)
//            } else {
//                hitTestVisualization = nil
//            }
//        }
//    }

    
    func refreshFeaturePoints() {
        guard showDebugVisuals else {
            return
        }
        
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        DispatchQueue.main.async {
           // self.featurePointCountLabel.text = "Features: \(cloud.__count)".uppercased()
        }
    }
   
    
    
    var isLoadingObject: Bool = false {
        didSet {
            DispatchQueue.main.async {
           
                self.addButton.isEnabled = !self.isLoadingObject
              
            }
        }
    }
    
    @IBOutlet weak var addButton: UIButton!
    
    @IBAction func chooseObject(_ button: UIButton) {
        if isLoadingObject { return }
        
       let rowHeight = 45
       let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObjectSelectionViewController.COUNT_OBJECTS)
    
       let objectViewController = VirtualObjectSelectionViewController(size:popoverSize)
        objectViewController.delegate = self
        objectViewController.modalPresentationStyle = .popover
        objectViewController.popoverPresentationController?.delegate = self
        self.present(objectViewController, animated: true, completion: nil)
        
        objectViewController.popoverPresentationController?.sourceView = button
        objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }
    
    
    // MARK: - Planes
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
       
        
        let plane = Plane(anchor, showDebugVisuals)
        
        planes[anchor] = plane
        node.addChildNode(plane)

        if virtualObject == nil {
           // textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
        }
    }

    
    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
//            featurePointCountLabel.isHidden = !showDebugVisuals
//            debugMessageLabel.isHidden = !showDebugVisuals
//            messagePanel.isHidden = !showDebugVisuals
            planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
            arscnView.debugOptions = []
            if showDebugVisuals {
                arscnView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            }
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }
    
    func restartPlaneDetection() {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
            //planeDetection平面检测：水平面检测
            worldSessionConfig.planeDetection = .horizontal
            arscnView.session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
        
        // reset timer
        if trackingFallbackTimer != nil {
            trackingFallbackTimer!.invalidate()
            trackingFallbackTimer = nil
        }
        
        
    }
}
// MARK: - UIPopoverPresentationControllerDelegate
extension ViewController: UIPopoverPresentationControllerDelegate {
    //在phone端必须要适配设备，要设置下面代理方法：
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        //
    }
}





// MARK: - ARSCNViewDelegate
extension ViewController :ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        refreshFeaturePoints()
        
        DispatchQueue.main.async {
            self.updateFocusSquare()
            //self.hitTestVisualization?.render()
            
            // If light estimation is enabled, update the intensity of the model's lights and the environment map
            if let lightEstimate = self.session.currentFrame?.lightEstimate {
                self.arscnView.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
            } else {
                self.arscnView.enableEnvironmentMapWithIntensity(25)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if let plane = self.planes[planeAnchor] {
                    plane.update(planeAnchor as! ARPlaneAnchor)
                }
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes.removeValue(forKey: planeAnchor) {
                plane.removeFromParentNode()
            }
        }
    }
}



// MARK: - VirtualObjectSelectionViewControllerDelegate
extension ViewController :VirtualObjectSelectionViewControllerDelegate {
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject) {
        loadVirtualObject(object: object)
    }
    
    func loadVirtualObject(object: VirtualObject) {
        // Show progress indicator
        let spinner = UIActivityIndicatorView()
        spinner.center = addButton.center
        spinner.bounds.size = CGSize(width: addButton.bounds.width - 5, height: addButton.bounds.height - 5)
        //TODO: update image
        addButton.setImage(#imageLiteral(resourceName: "cup"), for: [])
        arscnView.addSubview(spinner)
        spinner.startAnimating()
        
        DispatchQueue.global().async {
            self.isLoadingObject = true
            object.viewController = self
            self.virtualObject = object
            
            object.loadModel()
            
            DispatchQueue.main.async {
                if let lastFocusSquarePos = self.focusSquare?.lastPosition {
                    self.setNewVirtualObjectPosition(lastFocusSquarePos)
                } else {
                    self.setNewVirtualObjectPosition(SCNVector3Zero)
                }
                
                spinner.removeFromSuperview()
                
                // Update the icon of the add object button
                let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
                let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
                self.addButton.setImage(buttonImage, for: [])
                self.addButton.setImage(pressedButtonImage, for: [.highlighted])
                self.isLoadingObject = false
            }
        }
    }
}


// MARK: Virtual Object Manipulation
extension ViewController {
    func displayVirtualObjectTransform() {
        guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        // Output the current translation, rotation & scale of the virtual object as text.
        let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
        let vectorToCamera = cameraPos - object.position
        
        let distanceToUser = vectorToCamera.length()
        
        var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        let distance = String(format: "%.2f", distanceToUser)
        let scale = String(format: "%.2f", object.scale.x)
        
    }
    
    func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
        
        guard let newPosition = pos else {
            
            // Reset the content selection in the menu only if the content has not yet been initially placed.
            if virtualObject == nil {
                resetVirtualObject()
            }
            return
        }
        
        if instantly {
            setNewVirtualObjectPosition(newPosition)
        } else {
            updateVirtualObjectPosition(newPosition, filterPosition)
        }
    }
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
        
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)
        
        let planeHitTestResults = arscnView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {
            
            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor
            
            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }
        
        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.
        
        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false
        
        let highQualityfeatureHitTestResults = arscnView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
        
        if !highQualityfeatureHitTestResults.isEmpty {
            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }
        
        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).
        
        if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
            
            let pointOnPlane = objectPos ?? SCNVector3Zero
            
            let pointOnInfinitePlane = arscnView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }
        
        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.
        
        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }
        
        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.
        
        let unfilteredFeatureHitTestResults = arscnView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {
            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }
        
        return (nil, nil, false)
    }
    
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
        
        guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        recentVirtualObjectDistances.removeAll()
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        object.position = cameraWorldPos + cameraToPosition
        
        if object.parent == nil {
            arscnView.scene.rootNode.addChildNode(object)
        }
    }
    
    
    
    
    
    func resetVirtualObject() {
        virtualObject?.unloadModel()
        virtualObject?.removeFromParentNode()
        virtualObject = nil
        
        addButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addButton.setImage(#imageLiteral(resourceName: "add"), for: [.highlighted])
    }
    
    func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
        guard let object = virtualObject else {
            return
        }
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        // Compute the average distance of the object from the camera over the last ten
        // updates. If filterPosition is true, compute a new position for the object
        // with this average. Notice that the distance is applied to the vector from
        // the camera to the content, so it only affects the percieved distance of the
        // object - the averaging does _not_ make the content "lag".
        let hitTestResultDistance = CGFloat(cameraToPosition.length())
        
        recentVirtualObjectDistances.append(hitTestResultDistance)
        recentVirtualObjectDistances.keepLast(10)
        
        if filterPosition {
            let averageDistance = recentVirtualObjectDistances.average!
            
            cameraToPosition.setLength(Float(averageDistance))
            let averagedDistancePos = cameraWorldPos + cameraToPosition
            
            object.position = averagedDistancePos
        } else {
            object.position = cameraWorldPos + cameraToPosition
        }
    }
    
    func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
        guard let object = virtualObject, let planeAnchorNode = arscnView.node(for: anchor) else {
            return
        }
        
        // Get the object's position in the plane's coordinate system.
        let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
        
        if objectPos.y == 0 {
            return; // The object is already on the plane
        }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
            return
        }
        
        // Drop the object onto the plane if it is near it.
        let verticalAllowance: Float = 0.03
        if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
            
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            object.position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
}
