import Foundation

/// Translates an AI-authored JSON document into a `RoutineTemplate`.
///
/// The schema is the `RoutineImportDTO` family. The service validates the
/// payload, generates fresh UUIDs, and resolves name collisions by suffixing
/// against a caller-supplied list of existing routine names.
public struct RoutineImportService: Sendable {
    public static let maxHabitsPerRoutine = 100
    public static let maxImportPayloadBytes = 256 * 1024 // 256 KB — generous for AI output, tight enough to reject pasted backups

    public init() {}

    public func importRoutine(
        fromJSON jsonString: String,
        existingTemplateNames: [String]
    ) throws -> RoutineTemplate {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RoutineImportError.emptyInput }

        guard let data = trimmed.data(using: .utf8) else {
            throw RoutineImportError.invalidJSON("Could not read text as UTF-8.")
        }
        guard data.count <= Self.maxImportPayloadBytes else {
            throw RoutineImportError.payloadTooLarge
        }

        let dto: RoutineImportDTO
        do {
            dto = try JSONDecoder().decode(RoutineImportDTO.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw RoutineImportError.invalidJSON("Missing required field: \(key.stringValue).")
        } catch let DecodingError.typeMismatch(_, context) {
            throw RoutineImportError.invalidJSON("Wrong type for field: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch let DecodingError.valueNotFound(_, context) {
            throw RoutineImportError.invalidJSON("Missing value for field: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch let DecodingError.dataCorrupted(context) {
            throw RoutineImportError.invalidJSON(context.debugDescription)
        } catch {
            throw RoutineImportError.invalidJSON(error.localizedDescription)
        }

        return try buildTemplate(from: dto, existingTemplateNames: existingTemplateNames)
    }

    // MARK: - Translation

    private func buildTemplate(
        from dto: RoutineImportDTO,
        existingTemplateNames: [String]
    ) throws -> RoutineTemplate {
        let trimmedName = dto.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw RoutineImportError.missingRoutineName }
        guard !dto.habits.isEmpty else { throw RoutineImportError.emptyHabits }
        guard dto.habits.count <= Self.maxHabitsPerRoutine else {
            throw RoutineImportError.tooManyHabits(count: dto.habits.count, limit: Self.maxHabitsPerRoutine)
        }

        let habits = try dto.habits.enumerated().map { index, habitDTO in
            try buildHabit(from: habitDTO, order: index)
        }

        let color = sanitizedColor(dto.color) ?? "#34C759"
        let uniqueName = uniqueRoutineName(trimmedName, against: existingTemplateNames)

        return RoutineTemplate(
            id: UUID(),
            name: uniqueName,
            description: dto.description?.trimmedToNilIfEmpty,
            habits: habits,
            color: color
        )
    }

    private func buildHabit(from dto: HabitImportDTO, order: Int) throws -> Habit {
        let trimmedName = dto.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RoutineImportError.habitMissingName(habitIndex: order)
        }
        let type = try buildHabitType(from: dto, habitIndex: order)

        return Habit(
            id: UUID(),
            name: trimmedName,
            type: type,
            isOptional: dto.isOptional ?? false,
            notes: dto.notes?.trimmedToNilIfEmpty,
            color: sanitizedColor(dto.color) ?? "#007AFF",
            order: order,
            isActive: true
        )
    }

    private func buildHabitType(from dto: HabitImportDTO, habitIndex: Int) throws -> HabitType {
        switch dto.type {
        case .task:
            let subtasks = (dto.subtasks ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Subtask(name: $0) }
            return .task(subtasks: subtasks, estimatedDuration: dto.estimatedSeconds.flatMap(positiveDuration))

        case .timer:
            guard let timer = dto.timer else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "timer")
            }
            return try buildTimerType(from: timer, habitIndex: habitIndex)

        case .tracking:
            guard let tracking = dto.tracking else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "tracking")
            }
            return try buildTrackingType(from: tracking, habitIndex: habitIndex)

        case .guidedSequence:
            let steps = dto.steps ?? []
            guard !steps.isEmpty else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "steps")
            }
            return .guidedSequence(steps: steps.map { $0.toSequenceStep() })

        case .website:
            guard let raw = dto.url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "url")
            }
            guard let url = URL(string: raw), let host = url.host, !host.isEmpty else {
                throw RoutineImportError.habitInvalidValue(habitIndex: habitIndex, field: "url", reason: "Not a valid URL.")
            }
            let display = dto.displayName?.trimmedToNilIfEmpty ?? host
            return .action(type: .website, identifier: url.absoluteString, displayName: display, estimatedDuration: dto.estimatedSeconds.flatMap(positiveDuration))

        case .shortcut:
            guard let shortcut = dto.shortcutName?.trimmingCharacters(in: .whitespacesAndNewlines), !shortcut.isEmpty else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "shortcutName")
            }
            let display = dto.displayName?.trimmedToNilIfEmpty ?? shortcut
            return .action(type: .shortcut, identifier: shortcut, displayName: display, estimatedDuration: dto.estimatedSeconds.flatMap(positiveDuration))
        }
    }

    private func buildTimerType(from dto: TimerImportDTO, habitIndex: Int) throws -> HabitType {
        switch dto.style {
        case .down:
            guard let duration = dto.durationSeconds, duration > 0 else {
                throw RoutineImportError.habitInvalidValue(habitIndex: habitIndex, field: "timer.durationSeconds", reason: "Must be > 0 for a countdown timer.")
            }
            return .timer(style: .down, duration: duration)

        case .up:
            let target = dto.targetSeconds.flatMap(positiveDuration)
            return .timer(style: .up, duration: 0, target: target)

        case .multiple:
            let steps = dto.steps ?? []
            guard !steps.isEmpty else {
                throw RoutineImportError.habitInvalidValue(habitIndex: habitIndex, field: "timer.steps", reason: "Multiple-timer style requires at least one step.")
            }
            let repeatCount = dto.repeatCount.map { max(1, $0) }
            return .timer(style: .multiple, duration: 0, steps: steps.map { $0.toSequenceStep() }, repeatCount: repeatCount)
        }
    }

    private func buildTrackingType(from dto: TrackingImportDTO, habitIndex: Int) throws -> HabitType {
        switch dto.kind {
        case .counter:
            let items = (dto.items ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !items.isEmpty else {
                throw RoutineImportError.habitInvalidValue(habitIndex: habitIndex, field: "tracking.items", reason: "Counter tracking needs at least one item.")
            }
            return .tracking(.counter(items: items))

        case .measurement:
            guard let unit = dto.unit?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty else {
                throw RoutineImportError.habitMissingField(habitIndex: habitIndex, field: "tracking.unit")
            }
            return .tracking(.measurement(unit: unit, targetValue: dto.targetValue))
        }
    }

    // MARK: - Helpers

    private func positiveDuration(_ value: Double) -> TimeInterval? {
        value > 0 ? value : nil
    }

    private func sanitizedColor(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let normalized = raw.hasPrefix("#") ? raw : "#\(raw)"
        let hexBody = String(normalized.dropFirst())
        let isValidLength = hexBody.count == 6 || hexBody.count == 8 || hexBody.count == 3
        let isValidChars = hexBody.allSatisfy { $0.isHexDigit }
        guard isValidLength, isValidChars else { return nil }
        return normalized.uppercased()
    }

    private func uniqueRoutineName(_ base: String, against existing: [String]) -> String {
        let existingSet = Set(existing)
        guard existingSet.contains(base) else { return base }

        // Try "<base> (Imported)" first, then "<base> (Imported 2)", ...
        let firstSuffix = "\(base) (Imported)"
        if !existingSet.contains(firstSuffix) { return firstSuffix }

        var counter = 2
        while true {
            let candidate = "\(base) (Imported \(counter))"
            if !existingSet.contains(candidate) { return candidate }
            counter += 1
            if counter > 1000 { return "\(base) \(UUID().uuidString.prefix(8))" }
        }
    }
}

// MARK: - Errors

public enum RoutineImportError: LocalizedError, Equatable {
    case emptyInput
    case payloadTooLarge
    case invalidJSON(String)
    case missingRoutineName
    case emptyHabits
    case tooManyHabits(count: Int, limit: Int)
    case habitMissingName(habitIndex: Int)
    case habitMissingField(habitIndex: Int, field: String)
    case habitInvalidValue(habitIndex: Int, field: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "The pasted text is empty."
        case .payloadTooLarge:
            return "The JSON is too large for a single routine import. Full backups belong under Import Data."
        case .invalidJSON(let detail):
            return "Couldn't parse the JSON. \(detail)"
        case .missingRoutineName:
            return "The routine needs a non-empty \"name\"."
        case .emptyHabits:
            return "The routine needs at least one habit."
        case .tooManyHabits(let count, let limit):
            return "The routine has \(count) habits; the limit is \(limit)."
        case .habitMissingName(let index):
            return "Habit #\(index + 1) is missing a name."
        case .habitMissingField(let index, let field):
            return "Habit #\(index + 1) is missing required field \"\(field)\"."
        case .habitInvalidValue(let index, let field, let reason):
            return "Habit #\(index + 1) has an invalid \"\(field)\": \(reason)"
        }
    }
}

// MARK: - Internal extensions

private extension String {
    var trimmedToNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension SequenceStepImportDTO {
    func toSequenceStep() -> SequenceStep {
        SequenceStep(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: max(1, durationSeconds),
            instructions: instructions?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
