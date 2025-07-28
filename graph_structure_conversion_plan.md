# Plan for Converting Conditional Habits to a More Graph-Like Structure in SwiftData

## 1. Introduction

Currently, the `ConditionalHabitInfo` and `ConditionalOption` models represent a simple branching logic where a question leads to a set of habits. While functional, this structure can become rigid if more complex, interconnected routines are desired (e.g., a habit leading to another question, or multiple paths converging).

This document explores converting to a more explicit graph-like structure using SwiftData relationships, weighing the pros and cons, and providing example code.

## 2. Current Structure Review

*   **`ConditionalHabitInfo`**:
    ```swift
    public struct ConditionalHabitInfo: Codable, Hashable, Sendable {
        public let question: String
        public let options: [ConditionalOption] // Array of options
    }
    ```
*   **`ConditionalOption`**:
    ```swift
    public struct ConditionalOption: Identifiable, Codable, Hashable, Sendable {
        public let id: UUID
        public var text: String
        public var habits: [Habit] // Array of Habits
    }
    ```
This forms a directed acyclic graph (DAG) where `ConditionalHabitInfo` nodes branch out to `Habit` nodes via `ConditionalOption` edges.

## 3. Proposed Graph-Like Structure using SwiftData

The core idea is to introduce a more generic "Node" concept that can represent either a `Habit` or a `ConditionalHabitInfo` (question). Relationships between these nodes would then be explicitly defined.

### 3.1. New/Modified SwiftData Models

We would introduce a new `RoutineNode` model and modify `Habit` and `ConditionalHabitInfo` to be `Model` objects.

```swift
import Foundation
import SwiftData

// MARK: - RoutineNode (New Model)

@Model
final class RoutineNode {
    var id: UUID
    var type: NodeType // Enum: .habit, .conditionalQuestion
    var order: Int // For sequencing within a routine
    var x: Double = 0.0 // X-coordinate for visual builder
    var y: Double = 0.0 // Y-coordinate for visual builder

    // Relationships
    @Relationship(deleteRule: .cascade) var habit: Habit?
    @Relationship(deleteRule: .cascade) var conditionalInfo: ConditionalHabitInfo?

    // For connecting nodes in a sequence or branching path
    // This could represent the 'next' node in a linear flow, or the target of an option
    @Relationship var nextNodes: [RoutineNode] = [] // For linear flow or multiple next steps

    init(id: UUID = UUID(), type: NodeType, order: Int = 0, habit: Habit? = nil, conditionalInfo: ConditionalHabitInfo? = nil, x: Double = 0.0, y: Double = 0.0) {
        self.id = id
        self.type = type
        self.order = order
        self.habit = habit
        self.conditionalInfo = conditionalInfo
        self.x = x
        self.y = y
    }
}

enum NodeType: Codable {
    case habit
    case conditionalQuestion
}

// MARK: - Habit (Modified Model)

@Model
final class Habit { // Assuming Habit is already a SwiftData Model
    var id: UUID
    var name: String
    // ... other habit properties

    // Back-relationship to RoutineNode if needed, e.g., if a Habit can only exist within one node
    @Relationship(inverse: \RoutineNode.habit) var node: RoutineNode?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - ConditionalHabitInfo (Modified Model)

@Model
final class ConditionalHabitInfo { // Assuming ConditionalHabitInfo is already a SwiftData Model
    var id: UUID
    var question: String

    // Instead of `options: [ConditionalOption]`, we define relationships to `ConditionalOptionNode`
    @Relationship(deleteRule: .cascade) var optionNodes: [ConditionalOptionNode] = []

    // Back-relationship to RoutineNode
    @Relationship(inverse: \RoutineNode.conditionalInfo) var node: RoutineNode?

    init(id: UUID = UUID(), question: String) {
        self.id = id
        self.question = question
    }
}

// MARK: - ConditionalOptionNode (New Model - replaces ConditionalOption struct)

@Model
final class ConditionalOptionNode {
    var id: UUID
    var text: String // The answer text
    
    // Relationship to the ConditionalHabitInfo it belongs to
    @Relationship(inverse: \ConditionalHabitInfo.optionNodes) var parentConditionalInfo: ConditionalHabitInfo?

    // The nodes that follow this option. This allows branching to Habits or other Questions.
    @Relationship var nextNodes: [RoutineNode] = []

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - RoutineTemplate (Modified to use RoutineNode)

@Model
final class RoutineTemplate { // Assuming RoutineTemplate is already a SwiftData Model
    var id: UUID
    var name: String
    // ... other routine properties

    // The starting nodes of this routine
    @Relationship(deleteRule: .cascade) var startNodes: [RoutineNode] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
    }
}
```

### 3.2. How it Works

1.  **`RoutineNode` as a Wrapper:** `RoutineNode` acts as a polymorphic wrapper. It can hold either a `Habit` or a `ConditionalHabitInfo`. This allows a single type (`RoutineNode`) to be used in sequences and relationships.
2.  **Explicit Relationships:** Instead of `[Habit]` or `[ConditionalOption]` arrays within structs, we use SwiftData's `@Relationship` to link `RoutineNode`s together.
    *   `RoutineNode.nextNodes`: Defines the sequence or multiple possible next steps after a given node.
    *   `ConditionalHabitInfo.optionNodes`: Links a question to its possible answer options.
    *   `ConditionalOptionNode.nextNodes`: Defines what happens after an option is chosen (can lead to a `Habit` node or another `ConditionalHabitInfo` node).
3.  **Routine Flow:** A `RoutineTemplate` would now contain a collection of `startNodes`. The execution engine would traverse these nodes, following `nextNodes` or the chosen `ConditionalOptionNode.nextNodes`.

## 4. Pros and Cons

### Pros:

*   **Increased Flexibility:**
    *   **Complex Branching:** A habit can lead to a question, a question can lead to another question, or multiple habits.
    *   **Converging Paths:** Different options can lead to the same subsequent habit or question.
    *   **Dynamic Routine Generation:** Easier to build tools that dynamically construct routines based on user input or external factors.
*   **Clearer Data Model for Complex Flows:** Explicit relationships make the routine flow more transparent in the data model itself.
*   **Leverages SwiftData Power:** Fully utilizes SwiftData's relationship management, querying, and potentially CloudKit syncing for the entire routine structure.
*   **Scalability:** Better suited for routines with many interconnected elements.

### Cons:

*   **Significant Refactoring Effort:**
    *   Existing `Habit` and `ConditionalHabitInfo` structs would need to be converted to `Model` classes.
    *   All code that currently creates, reads, updates, or deletes `ConditionalHabitInfo` and `Habit` objects would need to be rewritten to interact with `RoutineNode` and `ConditionalOptionNode` relationships.
    *   The routine execution logic would need a complete overhaul to traverse the graph structure instead of simple arrays.
*   **Increased Complexity (Initial):** The data model becomes more abstract with the introduction of `RoutineNode` and `ConditionalOptionNode`. Junior developers might find it harder to grasp initially.
*   **Migration:** Requires a SwiftData migration plan for existing user data, which can be complex depending on the amount and complexity of existing data.
*   **Overkill for Simple Cases:** If your routines will *always* be a simple question -> habits structure, this might be over-engineering.

## 5. Example Code: Creating a Simple Routine with the New Structure

```swift
import SwiftData
import Foundation

// Assume ModelContainer is set up in your App entry point

func createSampleRoutine(modelContext: ModelContext) {
    // 1. Create Habits
    let habit1 = Habit(name: "Drink Water")
    let habit2 = Habit(name: "Meditate for 10 mins")
    let habit3 = Habit(name: "Go for a walk")
    let habit4 = Habit(name: "Read a book")

    // 2. Create ConditionalHabitInfo (Question)
    let question1 = ConditionalHabitInfo(question: "How are you feeling today?")

    // 3. Create ConditionalOptionNodes
    let optionNode1 = ConditionalOptionNode(text: "Great!")
    let optionNode2 = ConditionalOptionNode(text: "Okay")
    let optionNode3 = ConditionalOptionNode(text: "Not so good")

    // 4. Create RoutineNodes for Habits
    let habitNode1 = RoutineNode(type: .habit, order: 1, habit: habit1)
    let habitNode2 = RoutineNode(type: .habit, order: 2, habit: habit2)
    let habitNode3 = RoutineNode(type: .habit, order: 3, habit: habit3)
    let habitNode4 = RoutineNode(type: .habit, order: 4, habit: habit4)

    // 5. Create RoutineNode for the Question
    let questionNode1 = RoutineNode(type: .conditionalQuestion, order: 1, conditionalInfo: question1)

    // 6. Define Relationships
    // Link options to their next habits/questions
    optionNode1.nextNodes = [habitNode1, habitNode2] // Great -> Drink Water, Meditate
    optionNode2.nextNodes = [habitNode3]             // Okay -> Go for a walk
    optionNode3.nextNodes = [habitNode4]             // Not so good -> Read a book

    // Link question to its options
    question1.optionNodes = [optionNode1, optionNode2, optionNode3]

    // Define the flow of the routine
    // Start with the question
    let routine = RoutineTemplate(name: "Morning Check-in Routine")
    routine.startNodes = [questionNode1]

    // Example of a linear flow after a question (if all options lead to the same next step)
    // questionNode1.nextNodes = [someCommonNextNode] // Not used in this branching example

    // 7. Insert into ModelContext
    modelContext.insert(habit1)
    modelContext.insert(habit2)
    modelContext.insert(habit3)
    modelContext.insert(habit4)
    modelContext.insert(question1)
    modelContext.insert(optionNode1)
    modelContext.insert(optionNode2)
    modelContext.insert(optionNode3)
    modelContext.insert(habitNode1)
    modelContext.insert(habitNode2)
    modelContext.insert(habitNode3)
    modelContext.insert(habitNode4)
    modelContext.insert(questionNode1)
    modelContext.insert(routine)

    do {
        try modelContext.save()
        print("Sample routine created successfully!")
    } catch {
        print("Error saving sample routine: \(error)")
    }
}

// Example of traversing the graph (simplified)
func executeRoutine(routine: RoutineTemplate) {
    guard let currentNode = routine.startNodes.first else { return }

    if currentNode.type == .habit, let habit = currentNode.habit {
        print("Executing habit: \(habit.name)")
        // ... logic to mark habit complete
        // Then move to nextNodes if any
        for nextNode in currentNode.nextNodes {
            executeRoutine(routine: RoutineTemplate(name: "", startNodes: [nextNode])) // Recursive call for simplicity
        }
    } else if currentNode.type == .conditionalQuestion, let questionInfo = currentNode.conditionalInfo {
        print("Question: \(questionInfo.question)")
        for optionNode in questionInfo.optionNodes {
            print("  Option: \(optionNode.text)")
            // User selects an option, then traverse its nextNodes
            // For example, if user selects optionNode1:
            // for nextNode in optionNode1.nextNodes {
            //     executeRoutine(routine: RoutineTemplate(name: "", startNodes: [nextNode]))
            // }
        }
    }
}
```

## 6. Conclusion: Is this something worth tackling?

**Short Answer: Probably not right now, unless your requirements explicitly demand more complex routine flows.**

**Detailed Reasoning:**

The current array-based structure for conditional habits is simple, effective, and directly addresses the stated requirement of "running routines that have already been built on the phone" where questions lead to a set of habits.

**The proposed graph-like structure offers significant flexibility but comes at a very high cost in terms of refactoring effort and initial complexity.**

**When it *would* be worth tackling:**

*   **New Feature Requirements:** If future features explicitly require:
    *   A habit leading to a question.
    *   Multiple questions in a sequence, where answers to one question influence subsequent questions.
    *   The ability for different answer paths to converge back to a common habit or question.
    *   A visual routine builder on the phone that benefits from a true graph representation.
*   **Scalability of Routine Complexity:** If you anticipate routines becoming extremely intricate with many interconnected decisions and actions.

**Why it's likely *not* worth tackling now:**

*   **"Only run routines" constraint:** The current requirement is to *run* existing routines, not build complex new ones on the watch. The existing structure is sufficient for execution.
*   **Junior Developer Onboarding:** Introducing a complex graph data model and traversal logic would significantly increase the learning curve and implementation burden for a junior developer, especially when they are also learning watchOS, WatchConnectivity, and SwiftData.
*   **Refactoring Risk:** A large-scale refactoring of core data models carries a high risk of introducing bugs and delaying development, especially if the existing system is stable.
*   **"You Ain't Gonna Need It" (YAGNI):** This principle suggests not implementing functionality until it's actually needed. The current structure works for the stated requirements. Over-engineering now could lead to wasted effort if the anticipated complex features never materialize or change significantly.

**Recommendation:**

Stick with the current `ConditionalHabitInfo` and `ConditionalOption` array-based structure for now. It's simpler to implement, understand, and debug for the current requirements.

**If and when new features explicitly demand a more complex, interconnected routine flow, then revisit this plan.** At that point, the benefits of a true graph structure would likely outweigh the significant refactoring costs. Focus on getting the watchOS app working with the existing, simpler data model first.

## 7. Implementing a Visual Routine Builder (Assuming Graph Structure Adoption)

If the decision is made to adopt the more flexible graph-like data structure, a powerful visual routine builder becomes a feasible and highly valuable feature. This section outlines the approach to building such a tool.

### 7.1. Core Concepts

*   **Nodes:** Each `RoutineNode` (representing either a `Habit` or a `ConditionalHabitInfo`) would be visually represented as a distinct, draggable UI element (e.g., a card or a box).
    *   **Habit Node:** Displays the habit's name, perhaps an icon, and a completion status.
    *   **Question Node:** Displays the question text and distinct "output ports" for each `ConditionalOptionNode`.
*   **Edges (Connections):** The relationships between `RoutineNode`s (`nextNodes`) and from `ConditionalHabitInfo` to `ConditionalOptionNode`s, and then from `ConditionalOptionNode`s to `RoutineNode`s, would be represented by lines or arrows connecting the nodes.
*   **Canvas/Workspace:** A scrollable and zoomable area where users can place, arrange, and connect these nodes.

### 7.2. Key UI Interactions and Implementation

To manage the state of the builder, we'll use a `RoutineBuilderViewModel` that interacts with the SwiftData `ModelContext`.

```swift
import SwiftUI
import SwiftData

@Observable
class RoutineBuilderViewModel {
    var routine: RoutineTemplate
    var selectedNode: RoutineNode? { // For editing or connecting
        didSet { // Automatically deselect if a new connection is started
            if selectedNode == nil { connectingFromNode = nil; connectingFromOptionNode = nil }
        }
    }
    var connectingFromNode: RoutineNode? // Source node for a new connection
    var connectingFromOptionNode: ConditionalOptionNode? // Source option for a new connection

    private var modelContext: ModelContext

    init(routine: RoutineTemplate, modelContext: ModelContext) {
        self.routine = routine
        self.modelContext = modelContext
    }

    func addHabitNode(at position: CGPoint) {
        let newHabit = Habit(name: "New Habit")
        let newNode = RoutineNode(type: .habit, habit: newHabit, x: position.x, y: position.y)
        modelContext.insert(newHabit)
        modelContext.insert(newNode)
        routine.startNodes.append(newNode) // For simplicity, add to startNodes. In a real builder, user would connect it.
        try? modelContext.save()
    }

    func addQuestionNode(at position: CGPoint) {
        let newQuestion = ConditionalHabitInfo(question: "New Question?")
        let newNode = RoutineNode(type: .conditionalQuestion, conditionalInfo: newQuestion, x: position.x, y: position.y)
        modelContext.insert(newQuestion)
        modelContext.insert(newNode)
        routine.startNodes.append(newNode) // For simplicity
        try? modelContext.save()
    }

    func deleteNode(_ node: RoutineNode) {
        // Remove all incoming connections to this node first
        for routineNode in routine.allNodes() { // Use allNodes() to find all references
            routineNode.nextNodes.removeAll(where: { $0.id == node.id })
            if routineNode.type == .conditionalQuestion, let question = routineNode.conditionalInfo {
                for optionNode in question.optionNodes {
                    optionNode.nextNodes.removeAll(where: { $0.id == node.id })
                }
            }
        }
        // Remove from startNodes if it's a start node
        routine.startNodes.removeAll(where: { $0.id == node.id })

        // SwiftData's cascade delete on @Relationship will handle associated habit/question/options
        modelContext.delete(node)
        try? modelContext.save()
    }

    func startConnecting(from node: RoutineNode) {
        connectingFromNode = node
        connectingFromOptionNode = nil
        selectedNode = nil // Deselect any node when starting a connection
    }

    func startConnecting(from optionNode: ConditionalOptionNode) {
        connectingFromOptionNode = optionNode
        connectingFromNode = nil
        selectedNode = nil // Deselect any node when starting a connection
    }

    func endConnecting(to targetNode: RoutineNode) {
        if let sourceNode = connectingFromNode {
            sourceNode.nextNodes.append(targetNode)
        } else if let sourceOptionNode = connectingFromOptionNode {
            sourceOptionNode.nextNodes.append(targetNode)
        }
        connectingFromNode = nil
        connectingFromOptionNode = nil
        try? modelContext.save()
    }

    func updateNodePosition(_ node: RoutineNode, newPosition: CGPoint) {
        node.x = newPosition.x
        node.y = newPosition.y
        // No need to save immediately on every drag update, perhaps debounce or save on drag end
    }

    func saveChanges() {
        try? modelContext.save()
    }
}

// Main Canvas View
struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var routine: RoutineTemplate // Load or create a routine
    @State private var viewModel: RoutineBuilderViewModel

    // State for drawing temporary connection line
    @State private var temporaryConnectionEnd: CGPoint? = nil

    init(routine: RoutineTemplate) {
        _routine = State(initialValue: routine)
        _viewModel = State(initialValue: RoutineBuilderViewModel(routine: routine, modelContext: modelContext))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background for drag-and-drop of new nodes
                Color.clear
                    .contentShape(Rectangle())
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        // Handle drop of new node from palette
                        // This is a simplified example, actual implementation would parse the dropped item
                        if let provider = providers.first {
                            _ = provider.loadObject(ofClass: NSString.self) { item, error in
                                DispatchQueue.main.async {
                                    if let type = item as? String {
                                        let dropLocation = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) // Placeholder
                                        if type == "habit" { viewModel.addHabitNode(at: dropLocation) }
                                        else if type == "question" { viewModel.addQuestionNode(at: dropLocation) }
                                    }
                                }
                            }
                        }
                        return true
                    }

                // Drawing connections
                // Iterate through all nodes to draw their outgoing connections
                ForEach(Array(routine.allNodes()), id: \.id) { sourceNode in
                    ConnectionDrawingView(sourceNode: sourceNode, allNodes: routine.allNodes())
                }

                // Draw temporary connection line
                if let startPoint = viewModel.connectingFromNode?.centerPoint(in: geometry) ?? viewModel.connectingFromOptionNode?.centerPoint(in: geometry), let endPoint = temporaryConnectionEnd {
                    Path { path in
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5]))
                }

                // Drawing nodes
                ForEach(Array(routine.allNodes()), id: \.id) { node in
                    NodeView(node: node, viewModel: viewModel)
                        .position(x: node.x, y: node.y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.updateNodePosition(node, newPosition: value.location)
                                    temporaryConnectionEnd = value.location // Update temp line end
                                }
                                .onEnded { value in
                                    viewModel.saveChanges()
                                    // Attempt to end connection if dragging from a port to another node
                                    if viewModel.connectingFromNode != nil || viewModel.connectingFromOptionNode != nil {
                                        // This is where hit-testing for target node would happen
                                        // For now, just reset temporary line
                                        temporaryConnectionEnd = nil
                                    }
                                }
                        )
                        .onTapGesture {
                            viewModel.selectedNode = node
                        }
                        .contextMenu {
                            Button("Delete Node") {
                                viewModel.deleteNode(node)
                            }
                        }
                }

                // Palette for adding new nodes (simplified for example)
                VStack {
                    Text("Drag to add:")
                    Button("Habit") {
                        // This button is for demonstration. Actual drag-and-drop would be better.
                        viewModel.addHabitNode(at: CGPoint(x: 100, y: 100))
                    }
                    Button("Question") {
                        viewModel.addQuestionNode(at: CGPoint(x: 100, y: 200))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            }
            .sheet(item: $viewModel.selectedNode) { node in
                EditNodeView(node: node)
            }
        }
    }
}

// Extension to RoutineTemplate to get all nodes for iteration
extension RoutineTemplate {
    func allNodes() -> Set<RoutineNode> {
        var visited: Set<RoutineNode> = []
        var queue: [RoutineNode] = Array(startNodes)

        while !queue.isEmpty {
            let currentNode = queue.removeFirst()
            if visited.insert(currentNode).inserted {
                // Add next nodes
                for nextNode in currentNode.nextNodes {
                    queue.append(nextNode)
                }
                // If it's a question, add its option nodes' next nodes
                if let questionInfo = currentNode.conditionalInfo {
                    for optionNode in questionInfo.optionNodes {
                        for nextNode in optionNode.nextNodes {
                            queue.append(nextNode)
                        }
                    }
                }
            }
        }
        return visited
    }
}

// Extension to RoutineNode to get its center point for connection drawing
extension RoutineNode {
    // This needs to be calculated relative to the parent GeometryReader
    // For now, it's a placeholder assuming the node's x,y are its top-left corner
    func centerPoint(in geometry: GeometryProxy) -> CGPoint {
        // Assuming a fixed size for the node view (150x100)
        // In a real app, you'd pass the actual size or calculate it dynamically
        return CGPoint(x: x + 75, y: y + 50)
    }
}

// Extension to ConditionalOptionNode to get its center point for connection drawing
extension ConditionalOptionNode {
    // This would need to be calculated relative to its parent ConditionalHabitInfo node's position
    // and its own position within the options stack.
    func centerPoint(in geometry: GeometryProxy) {
        // Placeholder for now
        return CGPoint(x: 0, y: 0)
    }
}

// Individual Node View
struct NodeView: View {
    @Bindable var node: RoutineNode
    @ObservedObject var viewModel: RoutineBuilderViewModel

    // State for drag gesture on connection ports
    @State private var isConnecting = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(node.type == .habit ? Color.blue.opacity(0.7) : Color.purple.opacity(0.7))
            .frame(width: 150, height: 100)
            .overlay(
                VStack {
                    if node.type == .habit, let habit = node.habit {
                        Text(habit.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    } else if node.type == .conditionalQuestion, let question = node.conditionalInfo {
                        Text(question.question)
                            .font(.headline)
                            .foregroundColor(.white)
                        // Display options and their connection points
                        ForEach(question.optionNodes) { option in
                            HStack {
                                Text(option.text)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .background(Capsule().fill(Color.gray.opacity(0.5)))

                                // Connection Port for Option
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 15, height: 15)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                isConnecting = true
                                                viewModel.startConnecting(from: option)
                                                // Update temporary line end in parent view
                                                // This requires a binding or environment object for temporaryConnectionEnd
                                            }
                                            .onEnded { value in
                                                isConnecting = false
                                                // Logic to find target node and create connection
                                                // This would involve hit-testing other nodes on the canvas
                                                // For now, assume endConnecting is called by the canvas view
                                            }
                                    )
                            }
                        }
                    }
                }
            )
            .overlay(
                // Connection Port (Output) for Habit/Question Node
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .offset(x: 75, y: 0) // Right side
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isConnecting = true
                                viewModel.startConnecting(from: node)
                                // Update temporary line end in parent view
                            }
                            .onEnded { value in
                                isConnecting = false
                                // Logic to find target node and create connection
                            }
                    )
                , alignment: .trailing
            )
            .border(viewModel.selectedNode?.id == node.id ? Color.yellow : Color.clear, width: 2)
    }
}

// View for editing node content
struct EditNodeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var node: RoutineNode

    var body: some View {
        NavigationView {
            Form {
                if node.type == .habit, let habit = node.habit {
                    TextField("Habit Name", text: $habit.name)
                } else if node.type == .conditionalQuestion, let question = node.conditionalInfo {
                    TextField("Question", text: $question.question)
                    Section("Options") {
                        ForEach(question.optionNodes) { option in
                            TextField("Option Text", text: $option.text)
                        }
                        .onDelete { indices in
                            question.optionNodes.remove(atOffsets: indices)
                        }
                        Button("Add Option") {
                            let newOption = ConditionalOptionNode(text: "New Option")
                            question.optionNodes.append(newOption)
                            modelContext.insert(newOption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Node")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// View for drawing connections
struct ConnectionDrawingView: View {
    @Bindable var sourceNode: RoutineNode
    var allNodes: Set<RoutineNode>

    var body: some View {
        // Connections from Habit/Question Node directly
        ForEach(sourceNode.nextNodes) { targetNode in
            Path {
                path.move(to: sourceNode.centerPoint(in: .zero)) // Placeholder for actual geometry
                path.addLine(to: targetNode.centerPoint(in: .zero)) // Placeholder
            }
            .stroke(Color.gray, lineWidth: 2)
        }

        // Connections from ConditionalOptionNodes within a Question Node
        if sourceNode.type == .conditionalQuestion, let question = sourceNode.conditionalInfo {
            ForEach(question.optionNodes) { optionNode in
                ForEach(optionNode.nextNodes) { targetNode in
                    Path {
                        // This needs more precise calculation for option node's port position
                        path.move(to: sourceNode.centerPoint(in: .zero)) // Simplified, needs option-specific start
                        path.addLine(to: targetNode.centerPoint(in: .zero))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
    }
}

// Extension to RoutineTemplate to get all nodes for iteration
extension RoutineTemplate {
    func allNodes() -> Set<RoutineNode> {
        var visited: Set<RoutineNode> = []
        var queue: [RoutineNode] = Array(startNodes)

        while !queue.isEmpty {
            let currentNode = queue.removeFirst()
            if visited.insert(currentNode).inserted {
                // Add next nodes
                for nextNode in currentNode.nextNodes {
                    queue.append(nextNode)
                }
                // If it's a question, add its option nodes' next nodes
                if let questionInfo = currentNode.conditionalInfo {
                    for optionNode in questionInfo.optionNodes {
                        for nextNode in optionNode.nextNodes {
                            queue.append(nextNode)
                        }
                    }
                }
            }
        }
        return visited
    }
}

// Extension to RoutineNode to get its center point for connection drawing
extension RoutineNode {
    // This needs to be calculated relative to the parent GeometryReader
    // For now, it's a placeholder assuming the node's x,y are its top-left corner
    func centerPoint(in geometry: GeometryProxy) -> CGPoint {
        // Assuming a fixed size for the node view (150x100)
        // In a real app, you'd pass the actual size or calculate it dynamically
        return CGPoint(x: x + 75, y: y + 50)
    }
}

// Extension to ConditionalOptionNode to get its center point for connection drawing
extension ConditionalOptionNode {
    // This would need to be calculated relative to its parent ConditionalHabitInfo node's position
    // and its own position within the options stack.
    func centerPoint(in geometry: GeometryProxy) {
        // Placeholder for now
        return CGPoint(x: 0, y: 0)
    }
}

## 8. Pre-Development Considerations

Before embarking on the significant task of implementing the graph-like data structure and the visual routine builder, it's crucial to address several pre-development considerations. These aspects, often overlooked in the initial planning phase, can significantly impact the project's success, maintainability, and user experience.

### 8.1. User Experience (UX) Design & User Flows

*   **Detailed Wireframes/Mockups:** Before writing any code, create high-fidelity wireframes or mockups of the visual builder. How will users intuitively add, connect, edit, and delete nodes? What gestures will be used?
*   **User Testing (Early Stage):** Even with mockups, conduct early user testing with non-technical users. Does the interface make sense? Are there any confusing elements or workflows? This can identify major UX flaws before development begins.
*   **Error States & Feedback:** How will the builder communicate invalid connections (e.g., creating a cycle in a DAG if not allowed), unsaved changes, or other errors? Provide clear visual feedback.
*   **Onboarding/Tutorial:** For a complex tool like a visual builder, a clear onboarding process or interactive tutorial will be essential to guide users through its functionality.

### 8.2. Edge Cases & Constraints

*   **Empty Routines:** How does the builder handle a routine with no nodes?
*   **Disconnected Nodes:** Can nodes exist without any connections? How are they managed?
*   **Cycles:** If the routine is intended to be a Directed Acyclic Graph (DAG), how will the builder prevent users from creating cycles? This requires validation logic during connection creation.
*   **Maximum Nodes/Complexity:** What are the practical limits for the number of nodes and connections a routine can have before performance degrades or the UI becomes unmanageable?
*   **Copy/Paste/Duplicate:** Will users be able to copy/paste individual nodes or entire sub-graphs? This adds complexity to data management.
*   **Zooming & Panning:** How will users navigate large routines? Implement intuitive zoom and pan gestures.

### 8.3. Performance Considerations (Deeper Dive)

*   **Rendering Performance:** Drawing many nodes and connections, especially with complex shapes or animations, can be taxing.
    *   **Optimization:** Explore `Canvas` (iOS 15+) for custom drawing, `drawingGroup()` for offscreen rendering, and `matchedGeometryEffect` for smooth transitions.
    *   **Debouncing:** For drag gestures, debounce position updates to SwiftData to avoid excessive writes.
*   **SwiftData Performance:**
    *   **Batch Operations:** When creating or deleting many nodes/connections, use batch operations with `ModelContext` to improve performance.
    *   **Efficient Queries:** Ensure data fetching for the builder is optimized (e.g., using `FetchDescriptor` with predicates and sort descriptors).
*   **Memory Management:** Be mindful of memory usage, especially with large routine graphs. Ensure proper deallocation of views and view models.

### 8.4. Testing Strategy

*   **Unit Tests:**
    *   **ViewModel Logic:** Thoroughly test `RoutineBuilderViewModel` methods (add, delete, connect, update position) to ensure they correctly manipulate the SwiftData models.
    *   **Graph Traversal:** Test the `allNodes()` extension and any other graph traversal logic.
*   **Integration Tests:**
    *   **SwiftData Persistence:** Verify that changes made in the UI are correctly persisted to SwiftData and can be reloaded.
    *   **WatchConnectivity (if applicable):** Test that complex routines created in the builder can be successfully transferred to and executed on the watch.
*   **UI Tests (XCUITest):**
    *   Automate tests for key user flows in the builder (e.g., adding a node, connecting two nodes, editing content).
    *   Verify visual correctness and responsiveness.
*   **Manual Testing:** Extensive manual testing will be required, especially for complex gesture interactions and edge cases.

### 8.5. Future-Proofing & Extensibility

*   **Modular Design:** Keep the UI components (NodeView, ConnectionDrawingView) and the ViewModel separate and modular to allow for easier modifications and extensions.
*   **Node Types:** Consider how easy it would be to introduce new `NodeType`s in the future (e.g., a "Timer Node," a "Notification Node"). The current polymorphic `RoutineNode` is a good start.
*   **Customizable Appearance:** If future requirements include custom colors, icons, or shapes for nodes, design the views with this extensibility in mind.

### 8.6. Collaboration & Version Control

*   **Clear Branching Strategy:** Given the significant refactoring, establish a clear Git branching strategy (e.g., feature branches, develop branch, main branch).
*   **Code Reviews:** Implement rigorous code reviews for all changes related to the graph structure and builder.
*   **Documentation:** Maintain up-to-date documentation for the new data model and builder logic.

### 8.7. Analytics & Monitoring

*   **Usage Tracking:** Consider adding analytics to understand how users interact with the builder (e.g., which node types are most used, how complex are the routines users create).
*   **Performance Monitoring:** Implement performance monitoring to identify bottlenecks in the builder's UI or data operations in a production environment.

By considering these points before development, you can build a more robust, user-friendly, and maintainable visual routine builder.