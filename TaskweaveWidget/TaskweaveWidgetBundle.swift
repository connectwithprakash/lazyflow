import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TaskweaveWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskweaveWidget()
        TaskweaveLiveActivity()
    }
}
