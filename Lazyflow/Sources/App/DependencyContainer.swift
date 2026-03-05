import Foundation
import LazyflowCore

/// Lightweight composition root that holds service instances.
///
/// In production, uses the shared singletons. In tests, swap in mock implementations
/// by passing protocol-typed instances to the initializer.
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    let persistence: any PersistenceControllerProtocol
    let taskService: any TaskServiceProtocol
    let categoryService: any CategoryServiceProtocol
    let calendarService: CalendarService
    let notificationService: any NotificationServiceProtocol
    let llmService: any LLMServiceProtocol

    init(
        persistence: any PersistenceControllerProtocol = PersistenceController.shared,
        taskService: any TaskServiceProtocol = TaskService.shared,
        categoryService: any CategoryServiceProtocol = CategoryService.shared,
        calendarService: CalendarService = .shared,
        notificationService: any NotificationServiceProtocol = NotificationService.shared,
        llmService: any LLMServiceProtocol = LLMService.shared
    ) {
        self.persistence = persistence
        self.taskService = taskService
        self.categoryService = categoryService
        self.calendarService = calendarService
        self.notificationService = notificationService
        self.llmService = llmService
    }
}
