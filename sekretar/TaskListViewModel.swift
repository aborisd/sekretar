import Foundation
import CoreData

@MainActor
final class TaskListViewModel: ObservableObject {
    private let repo: TaskRepository
    init(repo: TaskRepository) { self.repo = repo }

    @Published var errorMessage: String?
    @Published var isShowingError = false
    
    func addQuickTask(title: String) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { 
            _ = try await repo.create(title: title, notes: nil, dueDate: nil, priority: 1) 
        } catch { 
            await showError("Failed to add task: \(error.localizedDescription)")
        }
    }

    func toggle(_ task: TaskEntity) async {
        do { 
            try await repo.toggleComplete(task) 
        } catch { 
            await showError("Failed to update task: \(error.localizedDescription)")
        }
    }

    func delete(_ task: TaskEntity) async { 
        do { 
            try await repo.delete(task) 
        } catch { 
            await showError("Failed to delete task: \(error.localizedDescription)")
        } 
    }

    func bulkComplete(_ tasks: [TaskEntity]) async {
        guard !tasks.isEmpty else { return }
        do { try await repo.bulkComplete(tasks) }
        catch { await showError("Failed to complete tasks: \(error.localizedDescription)") }
    }

    func bulkDelete(_ tasks: [TaskEntity]) async {
        guard !tasks.isEmpty else { return }
        do { try await repo.bulkDelete(tasks) }
        catch { await showError("Failed to delete tasks: \(error.localizedDescription)") }
    }
    
    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
