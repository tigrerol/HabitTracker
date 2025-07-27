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

    // Relationships
    @Relationship(deleteRule: .cascade) var habit: Habit?
    @Relationship(deleteRule: .cascade) var conditionalInfo: ConditionalHabitInfo?

    // For connecting nodes in a sequence or branching path
    // This could represent the 'next' node in a linear flow, or the target of an option
    @Relationship var nextNodes: [RoutineNode] = [] // For linear flow or multiple next steps

    init(id: UUID = UUID(), type: NodeType, order: Int = 0, habit: Habit? = nil, conditionalInfo: ConditionalHabitInfo? = nil) {
        self.id = id
        self.type = type
        self.order = order
        self.habit = habit
        self.conditionalInfo = conditionalInfo
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

1.  **Adding New Nodes:**
    *   **Palette:** A sidebar or floating palette containing "new habit" and "new question" buttons, or a list of existing habits/questions that can be dragged onto the canvas.
    *   **Drag & Drop (`DragGesture`, `DropDelegate`):** Users would drag a new node type from the palette onto the canvas. This gesture would trigger the creation of a new `RoutineNode` (and its associated `Habit` or `ConditionalHabitInfo`) in the SwiftData `ModelContext`. The node's initial position would be based on the drop location.

2.  **Connecting Nodes (Defining Relationships):**
    *   **Connection Ports:** Each node would have visual "ports" (e.g., small circles) on its edges.
        *   Habit nodes: An output port for `nextNodes`.
        *   Question nodes: Output ports for each `ConditionalOptionNode`.
        *   All nodes: An input port for incoming connections.
    *   **Drawing Connections (`DragGesture`, `Path`, `Shape`):** Users would drag from an output port of one node to an input port of another. As they drag, a temporary line would be drawn. Upon release, if a valid connection is made, a new relationship would be established in the SwiftData model (e.g., `sourceNode.nextNodes.append(destinationNode)` or `optionNode.nextNodes.append(destinationNode)`). The line would then become permanent.

3.  **Editing Node Content:**
    *   **Tap to Edit:** Tapping a node would present a sheet or popover for editing its details (e.g., changing a habit's name, modifying a question's text, adding/removing/editing options for a question).
    *   **SwiftUI Forms:** Standard SwiftUI forms would be used within these editing sheets, binding directly to the `Habit` or `ConditionalHabitInfo` properties.

4.  **Deleting Nodes and Connections:**
    *   **Context Menu:** A long press or right-click on a node/connection could bring up a context menu with a "Delete" option.
    *   **Dedicated Button:** A selected node could display a small "X" button for deletion.
    *   **SwiftData Cascade Delete:** When a `RoutineNode` is deleted, its associated `Habit` or `ConditionalHabitInfo` (and its `ConditionalOptionNode`s) would be automatically deleted due to the `@Relationship(deleteRule: .cascade)` rule. Deleting a connection would simply remove the `RoutineNode` from the `nextNodes` array of the source.

5.  **Arranging and Layout:**
    *   **Manual Dragging:** Nodes would be freely draggable on the canvas (`DragGesture`). Their `x, y` coordinates could be stored as properties on the `RoutineNode` or in a separate UI state model.
    *   **Automatic Layout (Advanced):** For complex graphs, an automatic layout algorithm (e.g., force-directed graph layout) could be implemented to help organize nodes, though this is a significant undertaking.

### 7.3. SwiftUI Implementation Considerations

*   **`GeometryReader`:** Essential for positioning nodes and drawing connections accurately within the canvas.
*   **`@State` / `@Binding`:** For managing the UI state of individual nodes (e.g., selected, being dragged) and binding to their data.
*   **`@ObservedObject` / `@StateObject` / `@EnvironmentObject`:** For managing view models that provide access to the SwiftData `ModelContext` and handle interactions.
*   **`Canvas` (iOS 15+):** Could be used for more performant and flexible drawing of connections and custom node shapes.
*   **Performance:** For routines with many nodes, optimizing drawing and interaction performance will be crucial. Consider `LazyVGrid`/`LazyHGrid` if nodes are arranged in a grid, or custom `ScrollView` behavior.

### 7.4. Challenges and Considerations

*   **Complexity:** Building a robust visual graph editor is a non-trivial task. It involves complex gesture handling, state management, and potentially custom drawing.
*   **Performance:** As the number of nodes and connections grows, maintaining a smooth user experience (especially during dragging and layout changes) can be challenging.
*   **Undo/Redo:** A critical feature for any editor, adding significant complexity to state management.
*   **Accessibility:** Ensuring the visual builder is usable for users with various accessibility needs.
*   **Data Validation:** Ensuring that connections form a valid routine flow (e.g., preventing cycles if routines are meant to be linear or DAGs).

Implementing a visual routine builder would be a large project in itself, but it would unlock a highly intuitive and powerful way for users to define and manage their habits and routines, fully leveraging the flexibility of the graph-like data structure.