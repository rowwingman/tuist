import Basic
import Foundation

@testable import TuistCore

public extension TargetNode {
    static func test(project: Project = .test(),
                     target: Target = .test(),
                     dependencies: [GraphNode] = []) -> TargetNode {
        return TargetNode(project: project,
                          target: target,
                          dependencies: dependencies)
    }
}
