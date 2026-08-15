import Foundation

/// Expands a wrapper routine's `includes` into a flat, runnable template.
///
/// Composition is deliberately **one level deep**: a routine that includes
/// others cannot itself be included. That single rule removes cycle detection,
/// recursive expansion, and the "which copy am I editing?" confusion, while
/// still covering the real case — "Morning Vacation" = Core Morning + a couple
/// of holiday habits.
///
/// Everything downstream (session, pause snapshots, streaks, widget) keeps
/// seeing one flat habit array, exactly as before.
public enum RoutineComposer {

    /// Flatten `template` by splicing in the habits of every routine it includes.
    ///
    /// - Own habits and included blocks interleave by their shared `order`.
    /// - Habits from an include carry `blockName` so execution can label them.
    /// - Includes that are inactive, unresolvable, self-referential, or repeated
    ///   are skipped; the result never contains duplicate habit ids.
    /// - The returned template keeps its own id, so callers can still look it up.
    @MainActor
    public static func resolve(_ template: RoutineTemplate, in allTemplates: [RoutineTemplate]) -> RoutineTemplate {
        guard !template.includes.isEmpty else { return template }

        let byId = Dictionary(allTemplates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // (order, habits) pairs, later flattened by the shared ordering space.
        var groups: [(order: Int, habits: [Habit])] = template.habits.map { ($0.order, [$0.withBlockName(template.name)]) }

        var expandedTemplateIds: Set<UUID> = []
        for include in template.includes.sorted(by: { $0.order < $1.order }) {
            guard include.isActive,
                  include.templateId != template.id,
                  !expandedTemplateIds.contains(include.templateId),
                  let source = byId[include.templateId]
            else {
                if include.isActive, byId[include.templateId] == nil {
                    LoggingService.shared.error(
                        "Routine include points at a missing routine — skipping block",
                        category: .routine,
                        metadata: ["template": template.name, "missingTemplateId": include.templateId.uuidString]
                    )
                }
                continue
            }
            expandedTemplateIds.insert(include.templateId)

            // One level only: the source's own includes are ignored on purpose.
            let blockHabits = source.habits
                .filter(\.isActive)
                .sorted { $0.order < $1.order }
                .map { $0.withBlockName(source.name) }

            groups.append((include.order, blockHabits))
        }

        var seenHabitIds: Set<UUID> = []
        var flattened: [Habit] = []
        for group in groups.sorted(by: { $0.order < $1.order }) {
            for habit in group.habits where !seenHabitIds.contains(habit.id) {
                seenHabitIds.insert(habit.id)
                var ordered = habit
                ordered.order = flattened.count
                flattened.append(ordered)
            }
        }

        var resolved = template
        resolved.habits = flattened
        resolved.includes = [] // The resolved copy is inert — nothing left to expand.
        return resolved
    }

    /// Whether `candidate` may be included into `template`.
    ///
    /// Blocks self-inclusion, duplicates, and — enforcing the one-level rule —
    /// any routine that is itself a wrapper.
    public static func canInclude(_ candidate: RoutineTemplate, into template: RoutineTemplate) -> Bool {
        candidate.id != template.id
            && candidate.includes.isEmpty
            && !template.includes.contains { $0.templateId == candidate.id }
    }

    /// Routines that include `templateId` — used to warn before deleting a block.
    public static func templatesIncluding(_ templateId: UUID, in allTemplates: [RoutineTemplate]) -> [RoutineTemplate] {
        allTemplates.filter { template in
            template.includes.contains { $0.templateId == templateId }
        }
    }
}

private extension Habit {
    /// Tag a habit with the routine it is running as part of.
    func withBlockName(_ name: String) -> Habit {
        var copy = self
        copy.blockName = name
        return copy
    }
}
