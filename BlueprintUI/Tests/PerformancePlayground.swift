//
//  PerformancePlayground.swift
//  BlueprintUI-Unit-Tests
//
//  Created by Kyle Van Essen on 6/23/20.
//

import XCTest
@testable import BlueprintUI


class PerformancePlayground : XCTestCase
{
    override func invokeTest() {
        // Uncomment this line to run performance metrics, eg in Instruments.app.
        // super.invokeTest()
    }
    
    func test_repeated_layouts()
    {
        let element = Column { col in
            for index in 1...1000 {
                col.add(child: TestLabel(text: "This is test label number #\(index)"))
            }
        }
        
        let view = BlueprintView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 500.0))
        
        self.determineAverage(for: 10.0) {
            view.element = element
            view.layoutIfNeeded()
        }
    }
    
    func test_deep_element_hierarchy()
    {
        let elements = [
            TestLabel(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit."),
            TestLabel(text: "Integer molestie et felis at sodales."),
            TestLabel(text: "Donec varius, orci vel suscipit hendrerit, risus massa ornare dui, at gravida elit sapien at lorem."),
            TestLabel(text: "Nunc in ipsum porttitor, tincidunt est eu, euismod odio."),
            TestLabel(text: "Duis posuere nunc sed mi auctor, in dictum elit iaculis."),
            TestLabel(text: "Ut vel varius est. Duis efficitur vel lorem quis tempor."),
            TestLabel(text: "Nulla porttitor, mi nec posuere bibendum, turpis ipsum ultrices tortor, a placerat sapien augue quis sem."),
            TestLabel(text: "Cras volutpat nisl vitae elit convallis, quis tempor massa faucibus."),
        ]
        
        let stack = Column { col in
            let row = Row { row in
                let col = Column { col in
                    elements.forEach {
                        col.add(child: $0)
                    }
                }
                
                for _ in 1...10 {
                    row.add(child: col)
                }
            }
            
            for _ in 1...10 {
                col.add(child: row)
            }
        }
        
        let view = BlueprintView()
        view.frame.size = CGSize(width: 1000.0, height: 10000)
                
        self.determineAverage(for: 10.0) {
            view.element = stack
            view.layoutIfNeeded()
        }
    }
    
    func determineAverage(for seconds : TimeInterval, using block : () -> ()) {
        let start = Date()
        
        var iterations : Int = 0
        
        repeat {
            let iterationStart = Date()
            block()
            let iterationEnd = Date()
            let duration = iterationEnd.timeIntervalSince(iterationStart)
            
            iterations += 1

            print("Iteration: \(iterations), Duration : \(duration)")
            
        } while Date() < start + seconds
        
        let end = Date()
        
        let duration = end.timeIntervalSince(start)
        let average = duration / TimeInterval(iterations)
        
        print("Iterations: \(iterations), Average Time: \(average)")
    }
}


fileprivate struct TestLabel : UIViewElement
{
    var text : String
    
    // MARK: UIViewElement
    
    typealias UIViewType = UILabel
    
    static func makeUIView() ->  UILabel {
        UILabel()
    }
    
    var measurementCacheKey: AnyHashable? {
        self.text
    }
    
    func updateUIView(_ view:  UILabel) {
        view.numberOfLines = 0
        view.text = self.text
    }
}
