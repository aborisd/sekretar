import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject var viewModel: TaskListViewModel
    @State private var quickText = ""
    @State private var showingNewTask = false
    @State private var draftTask: TaskEntity? = nil
    // Navigation state for editor
    @State private var showEditor = false
    @State private var selectedTaskID: NSManagedObjectID?
    @FocusState private var quickFieldFocused: Bool

    @FetchRequest private var tasks: FetchedResults<TaskEntity>
    // Без режима множественного редактирования

    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let sort: [NSSortDescriptor] = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "updatedAt", ascending: false)
        ]
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date()) as NSDate
        let cutoff = cal.date(byAdding: .day, value: -60, to: cal.startOfDay(for: Date()))! as NSDate
        let predicate = NSPredicate(format: "isCompleted == NO AND (dueDate == nil OR dueDate >= %@) AND createdAt >= %@", startOfToday, cutoff)

        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.sortDescriptors = sort
        request.predicate = predicate
        request.fetchBatchSize = 30
        request.fetchLimit = 150
        _tasks = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                quickTaskHeader
                tasksList
            }
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {}
            .onAppear { cleanupEmptyDraftTasks() }
            .onDisappear {
                quickFieldFocused = false
                dismissKeyboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissKeyboard)) { _ in
                quickFieldFocused = false
                dismissKeyboard()
            }
            .sheet(isPresented: $showingNewTask, onDismiss: { draftTask = nil }) {
                if let task = draftTask {
                    TaskEditorView(task: task)
                } else {
                    Text("Черновик не создан")
                }
            }
            .navigationDestination(isPresented: $showEditor) {
                if let id = selectedTaskID,
                   let task = try? context.existingObject(with: id) as? TaskEntity {
                    TaskEditorView(task: task)
                } else {
                    Text("Задача не найдена")
                }
            }
        }
    }
    
    private var quickTaskHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TextField("Быстрая задача…", text: $quickText)
                    .textFieldStyle(.roundedBorder)
                    .focused($quickFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addTask() }

                Button("Добавить") { addTask() }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button("Новая задача") {
                if draftTask == nil { draftTask = createNewTask() }
                showingNewTask = true
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    private var tasksList: some View {
        List {
            ForEach(tasks, id: \.objectID) { task in
                taskRow(for: task, onEdit: { openEditor(task) })
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(task) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func openEditor(_ task: TaskEntity) {
        selectedTaskID = task.objectID
        showEditor = true
    }
    
    private func taskRow(for task: TaskEntity, onEdit: @escaping () -> Void = {}) -> some View {
        HStack(spacing: 12) {
            Button(action: { Task { await viewModel.toggle(task) } }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }.buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(task.title ?? "").strikethrough(task.isCompleted)
                if let due = task.dueDate {
                    Text("до ") + Text(due, style: .date)
                }
            }
            
            Spacer()
            
            if task.priority > 0 {
                Text("P\(task.priority)")
                    .font(.caption2)
                    .padding(4)
                    .background(.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6)) 
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .imageScale(.medium)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func addTask() {
        Task { 
            await viewModel.addQuickTask(title: quickText)
            quickText.removeAll() 
            quickFieldFocused = false
            dismissKeyboard()
        }
    }
    
    private func createNewTask() -> TaskEntity {
        let newTask = TaskEntity(context: context)
        newTask.id = UUID()
        newTask.title = ""
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        newTask.isCompleted = false
        newTask.priority = 1
        return newTask
    }

    private func cleanupEmptyDraftTasks() {
        let fr: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fr.predicate = NSPredicate(format: "title == nil OR title == ''")
        fr.fetchLimit = 200
        if let drafts = try? context.fetch(fr), !drafts.isEmpty {
            for d in drafts { context.delete(d) }
            try? context.save()
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
