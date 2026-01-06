import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LazyflowWidgetBundle: WidgetBundle {
    var body: some Widget {
        LazyflowWidget()
        LazyflowLiveActivity()
    }
}
