//
//  Debugging.swift
//  BlueprintUI
//
//  Created by Kyle Van Essen on 4/18/20.
//

import Foundation


public struct Debugging : Equatable {
    
    public var showElementFrames : ShowElementFrames
    
    public enum ShowElementFrames : Equatable {
        case none
        case all
        case viewBacked
    }
    
    public var longPressForDebugger : Bool
    public var exploreElementHistory : Bool
    
    public init(
        showElementFrames : ShowElementFrames = .none,
        longPressForDebugger : Bool = false,
        exploreElementHistory : Bool = false
    )
    {
        self.showElementFrames = showElementFrames
        self.longPressForDebugger = longPressForDebugger
        self.exploreElementHistory = exploreElementHistory
    }
}

extension Debugging {
    static func viewDescriptionWrapping(other : ViewDescription?, for element : Element, bounds : CGRect) -> ViewDescription {
        
        ViewDescription(DebuggingWrapper.self) {
            $0.builder = {
                DebuggingWrapper(frame: bounds, containing: other, for: element)
            }
            
            $0.contentView = {
                if let other = other, let contained = $0.containedView {
                    return other.contentView(in: contained)
                } else {
                    return $0
                }
            }
            
            $0.apply {
                guard let other = other, let view = $0.containedView else {
                    return
                }

                other.apply(to: view)
            }
        }
    }
    
    final class DebuggingWrapper : UIView {
        
        let elementInfo : ElementInfo
        
        struct ElementInfo {
            var element : Element
            var isViewBacked : Bool
        }
        
        let containedView : UIView?
        
        let longPress : UITapGestureRecognizer
        
        var isSelected : Bool = false{
            didSet {
                guard oldValue != self.isSelected else {
                    return
                }
                
                self.updateIsSelected()
            }
        }
        
        private func updateIsSelected() {
            
            if self.isSelected {
                self.layer.borderWidth = 2.0
                self.layer.cornerRadius = 2.0
                
                self.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                self.layer.borderWidth = 1.0
                self.layer.cornerRadius = 2.0
                
                if self.elementInfo.isViewBacked {
                    self.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
                    self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.10)
                } else {
                    self.layer.borderColor = UIColor.black.withAlphaComponent(0.20).cgColor
                }
            }
        }
        
        init(frame: CGRect, containing : ViewDescription?, for element : Element) {
            
            if let containing = containing {
                let view = containing.build()
                view.frame = CGRect(origin: .zero, size: frame.size)
                
                self.containedView = view
            } else {
                self.containedView = nil
            }
            
            self.elementInfo = ElementInfo(
                element: element,
                isViewBacked: element.backingViewDescription(bounds: frame, subtreeExtent: nil) != nil
            )
            
            self.longPress = UITapGestureRecognizer()
            
            super.init(frame: frame)

            if let view = self.containedView {
                self.addSubview(view)
            }
            
            self.longPress.addTarget(self, action: #selector(didLongPress))
            self.addGestureRecognizer(self.longPress)
            
            self.updateIsSelected()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.containedView?.frame = self.bounds
        }
        
        required init?(coder: NSCoder) { fatalError() }
        
        @objc private func didLongPress() {
            
            guard self.longPress.state == .recognized else {
                return
            }
            
            Self.selectedWrapper = self
        }
        
        private static weak var selectedWrapper : DebuggingWrapper? = nil {
            didSet {
                if let wrapper = self.selectedWrapper, self.selectedWrapper === oldValue {
                    let nav = UINavigationController(rootViewController: DebuggingPreviewViewController(element: wrapper.elementInfo.element))
                    
                    let host = wrapper.window?.rootViewController?.viewControllerToPresentOn
                    
                    host?.present(nav, animated: true)
                } else {
                    oldValue?.isSelected = false
                    self.selectedWrapper?.isSelected = true
                }
            }
        }
    }
}


fileprivate extension UIViewController {
    var viewControllerToPresentOn : UIViewController {
        var toPresentOn : UIViewController = self
        
        repeat {
            if let presented = toPresentOn.presentedViewController {
                toPresentOn = presented
            } else {
                break
            }
        } while true

        return toPresentOn
    }
}


final class DebuggingPreviewViewController : UIViewController {
    
    let element : Element
    
    let blueprintView = BlueprintView()
    
    init(element : Element) {
        self.element = element
        super.init(nibName: nil, bundle: nil)
        
        self.title = "Inspector"
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func loadView() {
        self.view = self.blueprintView
        //self.blueprintView.debugging.showElementFrames = .viewBacked
        
        self.blueprintView.element = PreviewElement(presenting: self.element)
        self.blueprintView.layoutIfNeeded()
    }
    
    struct PreviewElement : ProxyElement {
        var presenting : Element
        
        var elementRepresentation: Element {
            Box(
                backgroundColor: UIColor(white: 0.90, alpha: 1.0),
                wrapping: ScrollView(wrapping: Content(presenting: self.presenting)) {
                    $0.contentSize = .fittingHeight
                    $0.contentInset = .init(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0)
                }
            )
        }
        
        struct Content : ProxyElement {
            var presenting : Element
            
            static var sideInset : CGFloat = 10.0
            
            var elementRepresentation: Element {
                Column {
                    $0.horizontalAlignment = .fill
                    $0.minimumVerticalSpacing = 10.0
                    
                    $0.add(child: Section(
                        header: "Preview",
                        content: FloatingBox(wrapping: Preview(presenting: self.presenting))
                    ))
                    
                    $0.add(child: Section(
                        header: "Layers",
                        content: FullWidthBox(wrapping: ThreeDVisualization(presenting: self.presenting))
                    ))
                    
                    $0.add(child: Section(
                        header: "Hierarchy",
                        content: FloatingBox(wrapping: ElementInfo(presenting: self.presenting))
                    ))
                }
            }
            
            struct Section : ProxyElement {
                var header : String
                
                var content : Element
                
                var elementRepresentation: Element {
                    Column {
                        $0.horizontalAlignment = .fill
                        
                        $0.add(
                            child: Inset(
                                sideInsets: Content.sideInset,
                                wrapping: Label(text: self.header) {
                                    $0.font = .systemFont(ofSize: 28.0, weight: .bold)
                                }
                            )
                        )
                        
                        $0.add(child: Spacer(size: CGSize(width: 0.0, height: 5.0)))
                        
                        $0.add(child: self.content)
                    }
                }
            }
            
            struct Preview : ProxyElement {
                var presenting : Element
                
                var elementRepresentation: Element {
                    ConstrainedSize(
                        height: .atLeast(100.0),
                        wrapping: Centered(Box(wrapping: self.presenting) {
                            $0.borderStyle = .solid(color: UIColor(white: 0.0, alpha: 0.25), width: 1.0)
                            $0.cornerStyle = .rounded(radius: 4.0)
                        })
                    )
                }
            }
            
            struct ThreeDVisualization : ProxyElement {
                var presenting : Element
                
                var elementRepresentation: Element {
                    let snapshot = FlattenedElementSnapshot(element: self.presenting, sizeConstraint: SizeConstraint(UIScreen.main.bounds.size))
                    
                    return ThreeDElementVisualization(snapshot: snapshot)
                }
            }
            
            struct ElementInfo : ProxyElement {
                var presenting : Element
                
                var elementRepresentation: Element {
                    Column {
                        $0.horizontalAlignment = .fill
                        $0.minimumVerticalSpacing = 10.0
                        
                        let list = self.presenting.recursiveElementList()
                        
                        for element in list {
                            $0.add(child: ElementRow(element: element))
                        }
                    }
                }
                
                struct ElementRow : ProxyElement {
                    fileprivate var element : RecursedElement

                    var elementRepresentation: Element {
                        Row {
                            $0.verticalAlignment = .fill
                            $0.horizontalUnderflow = .growUniformly
                            
                            let spacer = Spacer(size: CGSize(width: CGFloat(element.depth) * 15.0, height: 0.0))
                            $0.add(growPriority: 0.0, shrinkPriority: 0.0, child: spacer)
                            
                            let box = Box(backgroundColor: .init(white: 0.0, alpha: 0.05), wrapping: self.content)
                            
                            $0.add(growPriority: 1.0, shrinkPriority: 1.0, child: box)
                        }
                    }
                    
                    private var content : Element {
                        Row {
                            $0.verticalAlignment = .fill
                            $0.horizontalUnderflow = .justifyToStart
                            
                            $0.add(
                                child: Rule(orientation: .vertical, color: .darkGray, thickness: .points(2.0))
                            )
                            
                            let elementInfo = Column {
                                let elementType = String(describing: type(of:element.element))
                                    
                                $0.add(child: Label(text: elementType) {
                                    $0.font = .systemFont(ofSize: 18.0, weight: .semibold)
                                    $0.color = .systemBlue
                                })
                                
                                $0.add(child: Spacer(size: CGSize(width: 0.0, height: 5.0)))
                                
                                $0.add(child: Box(backgroundColor: .white, wrapping: element.element))
                            }
                            
                            $0.add(
                                child: Inset(uniformInset: 5.0, wrapping: elementInfo)
                            )
                        }
                    }
                }
            }
            
            struct FullWidthBox : ProxyElement {
                var wrapping : Element
                
                var elementRepresentation: Element {
                    Box(
                        wrapping: Inset(
                            insets: UIEdgeInsets(top: 20.0, left: 0.0, bottom: 20.0, right: 0.0),
                            wrapping: self.wrapping
                            )
                        ) { box in
                            box.shadowStyle = .simple(
                                radius: 2.0,
                                opacity: 0.25,
                                offset: CGSize(width: 0.0, height: 1.0),
                                color: .black
                            )
                            box.backgroundColor = .white
                    }
                }
            }
            
            struct FloatingBox : ProxyElement {
                var wrapping : Element
                
                var elementRepresentation: Element {
                    Inset(
                        sideInsets: Content.sideInset,
                        wrapping: Box(
                            wrapping: Inset(
                                uniformInset: 10.0,
                                wrapping: self.wrapping
                                )
                            ) { box in
                                box.shadowStyle = .simple(
                                    radius: 2.0,
                                    opacity: 0.25,
                                    offset: CGSize(width: 0.0, height: 1.0),
                                    color: .black
                                )
                        
                                box.cornerStyle = .rounded(radius: 15.0)
                                box.backgroundColor = .white
                        }
                    )
                }
            }
        }
    }
}

fileprivate struct RecursedElement {
    var element : Element
    var depth : Int
}

fileprivate extension Element {
    
    func recursiveElementList() -> [RecursedElement] {
        var list = [RecursedElement]()
        
        self.appendTo(recursiveElementList: &list, depth: 0)
        
        return list
    }
    
    func appendTo(recursiveElementList list : inout [RecursedElement], depth : Int) {
        list.append(RecursedElement(element: self, depth: depth))
        
        self.content.childElements.forEach {
            $0.appendTo(recursiveElementList: &list, depth: depth + 1)
        }
    }
}

fileprivate struct ThreeDElementVisualization : Element {
    
    var snapshot : FlattenedElementSnapshot
    
    var content: ElementContent {
        ElementContent { constraint in
            
            let scaling = constraint.maximum.width / self.snapshot.size.width
            
            let scaledWidth = self.snapshot.size.width * scaling
            let scaledHeight = self.snapshot.size.height * scaling
            
            return CGSize(
                width: scaledWidth,
                height: scaledHeight
            )
        }
    }
    
    func backingViewDescription(bounds: CGRect, subtreeExtent: CGRect?) -> ViewDescription? {
        ViewDescription(View.self) {
            $0.builder = {
                View(snapshot: self.snapshot)
            }
        }
    }
    
    final class View : UIView {
        private let snapshot : FlattenedElementSnapshot
        private let snapshotHost : HostView
        
        private let rotation : UIPanGestureRecognizer
        private let pan : UIPanGestureRecognizer
        
        private var transformState : TransformState = .standard
        
        struct TransformState : Equatable {
            
            // 1.0 == 180 degrees
            var rotationX : CGFloat
            // 1.0 == 180 degrees
            var rotationY : CGFloat
            var translation : CGPoint
            
            static var standard : TransformState {
                TransformState(
                    rotationX: 45 / CGFloat.pi / 180,
                    rotationY: 0,
                    translation: .zero
                )
            }
            
            func transform(scale : CGFloat? = nil) -> CATransform3D {
                
                var t = CATransform3DIdentity
                
                // https://stackoverflow.com/questions/3881446/meaning-of-m34-of-catransform3d
                t.m34 = -1.0 / 1000.0
                
                if let scale = scale {
                    t = CATransform3DScale(t, scale, scale, scale)
                }
                
                t = CATransform3DTranslate(t, self.translation.x, self.translation.y, 0.0)
                t = CATransform3DRotate(t, self.rotationX * CGFloat.pi, 1.0, 0.0, 0.0)
                t = CATransform3DRotate(t, self.rotationY * CGFloat.pi, 0.0, 1.0, 0.0)
                
                return t
            }
        }
        
        init(snapshot : FlattenedElementSnapshot) {
            
            self.snapshot = snapshot
            self.snapshotHost = HostView(snapshot: self.snapshot)
            
            self.rotation = UIPanGestureRecognizer()
            self.rotation.maximumNumberOfTouches = 1;

            self.pan = UIPanGestureRecognizer()
            self.pan.require(toFail: self.rotation)
            
            super.init(frame: CGRect(origin: .zero, size: self.snapshot.size))
        
            self.addSubview(self.snapshotHost)
            
            self.rotation.addTarget(self, action: #selector(handleRotation))
            self.pan.addTarget(self, action: #selector(handlePan))
            
            self.addGestureRecognizer(self.rotation)
            self.addGestureRecognizer(self.pan)
        }
        
        required init?(coder: NSCoder) { fatalError() }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.snapshotHost.frame.origin = CGPoint(
                x: round((self.bounds.width - self.snapshotHost.frame.width) / 2.0),
                y: round((self.bounds.height - self.snapshotHost.frame.height) / 2.0)
            )
            
            self.updateSublayerTransform(animated: false)
        }
        
        @objc private func handleRotation() {
            
            let dragFactor : CGFloat = 2.0
            
            self.transformState.rotationX -= (self.rotation.translation(in: self).y / self.bounds.size.width) / dragFactor
            self.transformState.rotationY += (self.rotation.translation(in: self).x / self.bounds.size.width) / dragFactor
            
            self.rotation.setTranslation(.zero, in: self)
            
            self.updateSublayerTransform(animated: false)
        }
        
        @objc private func handlePan() {
            
            let dragFactor : CGFloat = 2.0
                        
            self.transformState.translation.x += self.pan.translation(in: self).x / dragFactor
            self.transformState.translation.y += self.pan.translation(in: self).y / dragFactor
            
            self.pan.setTranslation(.zero, in: self)
            
            self.updateSublayerTransform(animated: false)
        }
        
        private func updateSublayerTransform(animated : Bool) {
            // Apply once so that we have the updated frames to use when calculating visible positions.
            self.snapshotHost.layer.sublayerTransform = self.transformState.transform()
            // Now that the transform is applied, update the scale using the visible positions.
            self.snapshotHost.layer.sublayerTransform = self.transformState.transform(scale: self.snapshotHost.scaleToShowAllSubviews(in: self))
        }
        
        final class HostView : UIView {
            private let snapshot : FlattenedElementSnapshot
            
            init(snapshot : FlattenedElementSnapshot) {
                self.snapshot = snapshot
                
                super.init(frame: CGRect(origin: .zero, size: self.snapshot.size))
                
                for view in snapshot.flatHierarchySnapshot {
                    self.addSubview(view.view)
                    view.view.frame = view.frame
                    view.view.layer.zPosition = 10 * CGFloat(view.hierarchyDepth)
                }
            }
            
            required init?(coder: NSCoder) { fatalError() }
            
            override func sizeThatFits(_ size: CGSize) -> CGSize {
                self.snapshot.size
            }
            
            func scaleToShowAllSubviews(in parent : UIView) -> CGFloat {
            
                var union : CGRect = .zero
                
                self.recurse { view in
                    let rect = view.convert(view.bounds, to: parent)
                    union = union.union(rect)
                }
                
                let widthScale = union.width / parent.bounds.width
                let heightScale = union.height / parent.bounds.height
                
                let maxScale = max(widthScale, heightScale)
                
                return 1.0 / maxScale
            }
        }
    }
}

fileprivate struct FlattenedElementSnapshot {
    let element : Element
    let flatHierarchySnapshot : [ViewSnapshot]
    let size : CGSize
    
    init(element : Element, sizeConstraint : SizeConstraint) {
        self.element = element
        
        self.size = self.element.content.measure(in: sizeConstraint)
        
        let view = BlueprintView(frame: CGRect(origin: .zero, size: self.size))
        view.debugging.showElementFrames = .all
        view.element = self.element
        view.layoutIfNeeded()
        
        var snapshot = [ViewSnapshot]()
        
        view.buildFlatHierarchySnapshot(in: &snapshot, rootView: view, depth: 0)
        
        self.flatHierarchySnapshot = snapshot
    }
    
    struct ViewSnapshot {
        var element : Element
        var view : UIView
        var frame : CGRect
        var hierarchyDepth : Int
    }
}

fileprivate extension UIView {
    func recurse(with block : (UIView) -> ()) {
        block(self)
        
        for view in self.subviews {
            view.recurse(with: block)
        }
    }
    
    func buildFlatHierarchySnapshot(in list : inout [FlattenedElementSnapshot.ViewSnapshot], rootView : UIView, depth : Int) {
        
        if let self = self as? Debugging.DebuggingWrapper {
            let snapshot = FlattenedElementSnapshot.ViewSnapshot(
                element: self.elementInfo.element,
                view: self,
                frame: self.convert(self.bounds, to: rootView),
                hierarchyDepth: depth
            )
            
            list.append(snapshot)
        }
        
        for view in self.subviews {
            view.buildFlatHierarchySnapshot(in: &list, rootView: rootView, depth: depth + 1)
        }
        
        if self is Debugging.DebuggingWrapper {
            self.removeFromSuperview()
        }
    }
    
    func toImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        
        return renderer.image {
            self.layer.render(in: $0.cgContext)
        }
    }
}


extension Notification.Name {
    static var BlueprintGlobalDebuggingSettingsChanged = Notification.Name("BlueprintGlobalDebuggingSettingsChanged")
}