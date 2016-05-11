//
//  KDDragAndDropManager.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

@objc protocol KDDraggable {
    /**
     点击的部位是否是 item
     
     - parameter point:
     
     - returns:
     */
    func canDragAtPoint(point : CGPoint) -> Bool
    /**
     貌似直接生成 item 图片
     
     - parameter point: point
     
     - returns: image
     */
    func representationImageAtPoint(point : CGPoint) -> UIView?
    func dataItemAtPoint(point : CGPoint) -> AnyObject?
    func dragDataItem(item : AnyObject) -> Void
    /**
     记录item的 indexpath
     
     - parameter point:
     
     - returns:
     */
    optional func startDraggingAtPoint(point : CGPoint) -> Void
    optional func stopDragging() -> Void
}


@objc protocol KDDroppable {
    /**
     拖动的overlapping 是不是和 cell 的重叠
     
     - parameter rect: 目前拖动的坐标
     
     - returns:
     */
    func canDropAtRect(rect : CGRect) -> Bool
    func willMoveItem(item : AnyObject, inRect rect : CGRect) -> Void
    /**
     移动cell，拖动还没离开原cell，不移动
     - parameter item: 原始的item
     - parameter rect: 目前拖动的坐标
     
     - returns:
     */
    func didMoveItem(item : AnyObject, inRect rect : CGRect) -> Void
    /**
     跨collecitonview 移动，需要删除原始的 cell
     
     - parameter item: 原始的 cell
     
     - returns: 
     */
    func didMoveOutItem(item : AnyObject) -> Void
    func dropDataItem(item : AnyObject, atRect : CGRect) -> Void
}

class KDDragAndDropManager: NSObject, UIGestureRecognizerDelegate {
    
    private var canvas : UIView = UIView()
    private var views : [UIView] = []
    private var longPressGestureRecogniser = UILongPressGestureRecognizer()
    
    
    struct Bundle {
        var offset : CGPoint = CGPointZero
        var sourceDraggableView : UIView
        var overDroppableView : UIView?
        var representationImageView : UIView
        var dataItem : AnyObject
    }
    var bundle : Bundle?
    
    init(canvas : UIView, collectionViews : [UIView]) {
        
        super.init()
        
        self.canvas = canvas
        
        self.longPressGestureRecogniser.delegate = self
        self.longPressGestureRecogniser.minimumPressDuration = 0.3
        self.longPressGestureRecogniser.addTarget(self, action: #selector(KDDragAndDropManager.updateForLongPress(_:)))
        
        self.canvas.addGestureRecognizer(self.longPressGestureRecogniser)
        self.views = collectionViews
    }
    
    // 手势开始响应
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        
        
        for view in self.views.filter({ v -> Bool in v is KDDraggable})  {
            
                let draggable = view as! KDDraggable
                // collection 上的点
                let touchPointInView = touch.locationInView(view)
            
                if draggable.canDragAtPoint(touchPointInView) == true {
                    
                    if let representation = draggable.representationImageAtPoint(touchPointInView) {
                        // 原来的frame 转到新的 view 里的 frame 坐标位置
                        representation.frame = self.canvas.convertRect(representation.frame, fromView: view)
                        
                        representation.alpha = 0.7
                        // canvas 上的 点
                        let pointOnCanvas = touch.locationInView(self.canvas)
                        
                        let offset = CGPointMake(pointOnCanvas.x - representation.frame.origin.x, pointOnCanvas.y - representation.frame.origin.y)
                        print(pointOnCanvas, representation.frame, touchPointInView)
                        if let dataItem : AnyObject = draggable.dataItemAtPoint(touchPointInView) {
                            
                            self.bundle = Bundle(
                                offset: offset,
                                sourceDraggableView: view,
                                overDroppableView : view is KDDroppable ? view : nil,
                                representationImageView: representation,
                                dataItem : dataItem
                            )
                            
                            return true
                    
                        } // if let dataIte...
                        
                
                    } // if let representation = dragg...
                   
           
            } // if draggable.canDragAtP...
            
        } // for view in self.views.fil...
        
        return false
        
    }
    
    
    
    
    func updateForLongPress(recogniser : UILongPressGestureRecognizer) -> Void {
        
        if let bundl = self.bundle {
            
            let pointOnCanvas = recogniser.locationInView(recogniser.view)
            let sourceDraggable : KDDraggable = bundl.sourceDraggableView as! KDDraggable
            let pointOnSourceDraggable = recogniser.locationInView(bundl.sourceDraggableView)
            
            switch recogniser.state {
                
                
            case .Began :
                print("gesture begin")
                self.canvas.addSubview(bundl.representationImageView)
                sourceDraggable.startDraggingAtPoint?(pointOnSourceDraggable)
                
            case .Changed :
                print("change", pointOnCanvas)
                // Update the frame of the representation image
                var repImgFrame = bundl.representationImageView.frame
                repImgFrame.origin = CGPointMake(pointOnCanvas.x - bundl.offset.x, pointOnCanvas.y - bundl.offset.y);
                bundl.representationImageView.frame = repImgFrame
                
                var overlappingArea : CGFloat = 0.0
                
                var mainOverView : UIView?
                
                for view in self.views.filter({ v -> Bool in v is KDDroppable }) {
                    
                    // 这一句话 纯 忽悠人感觉
                    let viewFrameOnCanvas = self.convertRectToCanvas(view.frame, fromView: view)
                    
                    print("image begin ", NSStringFromCGRect(viewFrameOnCanvas), NSStringFromCGRect(view.frame))
                    
                    /*                ┌────────┐   ┌────────────┐
                    *                 │       ┌┼───│Intersection│
                    *                 │       ││   └────────────┘
                    *                 │   ▼───┘│
                    * ████████████████│████████│████████████████
                    * ████████████████└────────┘████████████████
                    * ██████████████████████████████████████████
                    */
                    // 生成的image 和 collectionview 重合部分 大小
                    let intersectionNew = CGRectIntersection(bundl.representationImageView.frame, viewFrameOnCanvas).size
                    
                    // 又一个貌似没有用的 overlappingArea
                    if (intersectionNew.width * intersectionNew.height) > overlappingArea {
                        print("image new ", NSStringFromCGSize(intersectionNew), view.tag,  overlappingArea)
                        overlappingArea = intersectionNew.width * intersectionNew.width
                        // mainOverView 就是 拖动所在的 collection view
                        mainOverView = view
                    }

                    
                }
                
                
                
                if let droppable = mainOverView as? KDDroppable {
                    
                    let rect = self.canvas.convertRect(bundl.representationImageView.frame, toView: mainOverView)
                    
                    if droppable.canDropAtRect(rect) {
                        // 有没有跨collection view
                        if mainOverView != bundl.overDroppableView { // if it is the first time we are entering
                            
                            (bundl.overDroppableView as! KDDroppable).didMoveOutItem(bundl.dataItem)
                            droppable.willMoveItem(bundl.dataItem, inRect: rect)
                            
                        }
                        
                        // set the view the dragged element is over
                        self.bundle!.overDroppableView = mainOverView
                        
                        droppable.didMoveItem(bundl.dataItem, inRect: rect)
                        
                    }
                    
                    
                }
                
               
            case .Ended :
                print("end")
                if bundl.sourceDraggableView != bundl.overDroppableView { // if we are actually dropping over a new view.
                    
                    print("\(bundl.overDroppableView?.tag)")
                    
                    if let droppable = bundl.overDroppableView as? KDDroppable {
                        
                        sourceDraggable.dragDataItem(bundl.dataItem)
                        
                        let rect = self.canvas.convertRect(bundl.representationImageView.frame, toView: bundl.overDroppableView)
                        
                        droppable.dropDataItem(bundl.dataItem, atRect: rect)
                        
                    }
                }
                
                
                bundl.representationImageView.removeFromSuperview()
                sourceDraggable.stopDragging?()
                
            default:
                break
                
            }
            
            
        } // if let bundl = self.bundle ...
        
        
        
    }
    
    // MARK: Helper Methods 
    func convertRectToCanvas(rect : CGRect, fromView view : UIView) -> CGRect {
        
        var r : CGRect = rect
        
        var v = view
        
        while v != self.canvas {
            
            if let sv = v.superview {
                
                r.origin.x += sv.frame.origin.x
                r.origin.y += sv.frame.origin.y
                
                v = sv
                
                continue
            }
            break
        }
        
        return r
    }
   
}
