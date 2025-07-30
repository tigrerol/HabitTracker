import SwiftUI

/// Context dimension types for the coverage heatmap
enum ContextDimension: String, CaseIterable, Identifiable {
    case timeSlot = "time_slot"
    case location = "location"
    case dayCategory = "day_category"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .timeSlot: return "Time Slot"
        case .location: return "Location"
        case .dayCategory: return "Day Category"
        }
    }
    
    var icon: String {
        switch self {
        case .timeSlot: return "clock"
        case .location: return "location"
        case .dayCategory: return "calendar"
        }
    }
}

/// Heatmap visualization showing routine coverage across configurable context dimensions
public struct ContextCoverageView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(DayCategoryManager.self) private var dayCategoryManager
    
    @State private var xAxisDimension: ContextDimension = .timeSlot
    @State private var yAxisDimension: ContextDimension = .location
    @State private var filterDimension: ContextDimension = .dayCategory
    
    @State private var selectedFilterValue: Any = DayCategory.weekday
    @State private var showingRoutineDetails = false
    @State private var selectedCellRoutines: [RoutineTemplate] = []
    @State private var selectedContext: (x: Any, y: Any, filter: Any) = (TimeSlot.morning, ExtendedLocationType.builtin(.home), DayCategory.weekday)
    @State private var customLocations: [CustomLocation] = []
    
    private var availableDayCategories: [DayCategory] {
        dayCategoryManager.getAllCategories()
    }
    
    private var availableLocations: [ExtendedLocationType] {
        var locations: [ExtendedLocationType] = LocationType.allCases.map { .builtin($0) }
        locations.append(contentsOf: customLocations.map { .custom($0.id) })
        return locations
    }
    
    private var availableTimeSlots: [TimeSlot] {
        TimeSlot.allCases
    }
    
    private var xAxisItems: [Any] {
        switch xAxisDimension {
        case .timeSlot: return availableTimeSlots
        case .location: return availableLocations
        case .dayCategory: return availableDayCategories
        }
    }
    
    private var yAxisItems: [Any] {
        switch yAxisDimension {
        case .timeSlot: return availableTimeSlots
        case .location: return availableLocations
        case .dayCategory: return availableDayCategories
        }
    }
    
    private var filterItems: [Any] {
        switch filterDimension {
        case .timeSlot: return availableTimeSlots
        case .location: return availableLocations
        case .dayCategory: return availableDayCategories
        }
    }
    
    private var availableDimensions: [ContextDimension] {
        ContextDimension.allCases
    }
    
    public init() {
        _selectedFilterValue = State(initialValue: DayCategory.weekday)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                axisConfigurationSection
                
                filterSection
                
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    coverageGrid
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Coverage Overview")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingRoutineDetails) {
                routineDetailsSheet
            }
        }
        .onAppear {
            updateFilterValueIfNeeded()
            loadCustomLocations()
        }
        .onChange(of: xAxisDimension) { updateDimensionsAndFilter() }
        .onChange(of: yAxisDimension) { updateDimensionsAndFilter() }
    }
    
    private var axisConfigurationSection: some View {
        HStack(spacing: 12) {
            // X-Axis
            VStack(spacing: 4) {
                Text("X-Axis")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(availableDimensions) { dimension in
                        Button {
                            xAxisDimension = dimension
                        } label: {
                            Label(dimension.displayName, systemImage: dimension.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: xAxisDimension.icon)
                            .font(.caption)
                        Text(xAxisDimension.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Y-Axis
            VStack(spacing: 4) {
                Text("Y-Axis")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(availableDimensions) { dimension in
                        Button {
                            yAxisDimension = dimension
                        } label: {
                            Label(dimension.displayName, systemImage: dimension.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: yAxisDimension.icon)
                            .font(.caption)
                        Text(yAxisDimension.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Filter
            VStack(spacing: 4) {
                Text("Filter")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(availableDimensions) { dimension in
                        Button {
                            filterDimension = dimension
                        } label: {
                            Label(dimension.displayName, systemImage: dimension.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterDimension.icon)
                            .font(.caption)
                        Text(filterDimension.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filterItems.enumerated()), id: \.offset) { index, item in
                    Button {
                        selectedFilterValue = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconForItem(item))
                                .font(.caption2)
                            Text(displayNameForItem(item))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelectedFilterValue(item) ? 
                                colorForItem(item) : Color(.systemGray6),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            isSelectedFilterValue(item) ? 
                                .white : .primary
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    
    private var coverageGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with X-axis items
            HStack(spacing: 4) {
                // Y-axis column header
                Text(yAxisDimension.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                ForEach(Array(xAxisItems.enumerated()), id: \.offset) { index, xItem in
                    VStack(spacing: 2) {
                        Image(systemName: iconForItem(xItem))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(displayNameForItem(xItem))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(width: 60)
                }
            }
            
            // Grid rows for each Y-axis item
            ForEach(Array(yAxisItems.enumerated()), id: \.offset) { yIndex, yItem in
                HStack(spacing: 4) {
                    // Y-axis label
                    HStack(spacing: 4) {
                        Image(systemName: iconForItem(yItem))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(displayNameForItem(yItem))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    // Coverage cells
                    ForEach(Array(xAxisItems.enumerated()), id: \.offset) { xIndex, xItem in
                        let routines = getRoutinesForDynamicContext(
                            xAxisItem: xItem,
                            yAxisItem: yItem,
                            filterItem: selectedFilterValue
                        )
                        
                        Button {
                            selectedCellRoutines = routines
                            selectedContext = (xItem, yItem, selectedFilterValue)
                            showingRoutineDetails = true
                        } label: {
                            CoverageCell(
                                routineCount: routines.count,
                                firstRoutine: routines.first
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var routineDetailsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Context header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Context")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: xAxisDimension.icon)
                                .foregroundStyle(.secondary)
                            Text("\(xAxisDimension.displayName): \(displayNameForItem(selectedContext.x))")
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: yAxisDimension.icon)
                                .foregroundStyle(.secondary)
                            Text("\(yAxisDimension.displayName): \(displayNameForItem(selectedContext.y))")
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: filterDimension.icon)
                                .foregroundStyle(.secondary)
                            Text("\(filterDimension.displayName): \(displayNameForItem(selectedContext.filter))")
                                .fontWeight(.medium)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Routines list
                if selectedCellRoutines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        Text("No routines for this context")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("This combination of time, location, and day category doesn't have any matching routines.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(selectedCellRoutines) { routine in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(routine.swiftUIColor)
                                .frame(width: 4, height: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 8) {
                                    Text("\(routine.activeHabitsCount) habits")
                                    Text("•")
                                    Text(routine.formattedDuration)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Routine Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingRoutineDetails = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func getRoutinesForContext(
        timeSlot: TimeSlot,
        location: ExtendedLocationType,
        dayCategory: DayCategory
    ) -> [RoutineTemplate] {
        return routineService.templates.filter { template in
            guard let rule = template.contextRule else { return false }
            
            // Check time slot match
            let timeSlotMatches = rule.timeSlots.contains(timeSlot)
            
            // Check day category match
            let dayCategoryMatches = rule.dayCategoryIds.contains(dayCategory.id)
            
            // Check location match
            let locationMatches: Bool
            switch location {
            case .builtin(let builtinType):
                locationMatches = rule.locationIds.contains(builtinType.rawValue)
            case .custom(let customLocationId):
                locationMatches = rule.locationIds.contains(customLocationId.uuidString)
            }
            
            return timeSlotMatches && dayCategoryMatches && locationMatches
        }
        .sorted { $0.contextRule?.priority ?? 0 > $1.contextRule?.priority ?? 0 }
    }
    
    private func getRoutinesForDynamicContext(
        xAxisItem: Any,
        yAxisItem: Any,
        filterItem: Any
    ) -> [RoutineTemplate] {
        // Create context from the three items based on dimension assignments
        var timeSlot: TimeSlot?
        var location: ExtendedLocationType?
        var dayCategory: DayCategory?
        
        // Assign values based on which dimension is on which axis
        let items = [
            (xAxisDimension, xAxisItem),
            (yAxisDimension, yAxisItem),
            (filterDimension, filterItem)
        ]
        
        for (dimension, item) in items {
            switch dimension {
            case .timeSlot:
                timeSlot = item as? TimeSlot
            case .location:
                location = item as? ExtendedLocationType
            case .dayCategory:
                dayCategory = item as? DayCategory
            }
        }
        
        // Return empty if any required context is missing
        guard let timeSlot = timeSlot,
              let location = location,
              let dayCategory = dayCategory else {
            return []
        }
        
        return getRoutinesForContext(
            timeSlot: timeSlot,
            location: location,
            dayCategory: dayCategory
        )
    }
    
    private func loadCustomLocations() {
        if let data = UserDefaults.standard.data(forKey: "CustomLocations"),
           let locations = try? JSONDecoder().decode([UUID: CustomLocation].self, from: data) {
            customLocations = Array(locations.values)
        }
    }
    
    private func updateFilterValueIfNeeded() {
        guard let firstFilter = filterItems.first else { return }
        selectedFilterValue = firstFilter
    }
    
    private func updateDimensionsAndFilter() {
        // Ensure no dimension appears twice
        let usedDimensions = Set([xAxisDimension, yAxisDimension])
        if usedDimensions.contains(filterDimension) {
            if let unusedDimension = ContextDimension.allCases.first(where: { !usedDimensions.contains($0) }) {
                filterDimension = unusedDimension
            }
        }
        updateFilterValueIfNeeded()
    }
    
    // MARK: - Helper Methods for Any Type
    
    private func iconForItem(_ item: Any) -> String {
        switch item {
        case let timeSlot as TimeSlot:
            return timeSlot.icon
        case let location as ExtendedLocationType:
            return location.icon
        case let dayCategory as DayCategory:
            return dayCategory.icon
        default:
            return "questionmark"
        }
    }
    
    private func displayNameForItem(_ item: Any) -> String {
        switch item {
        case let timeSlot as TimeSlot:
            return timeSlot.displayName
        case let location as ExtendedLocationType:
            return location.displayName
        case let dayCategory as DayCategory:
            return dayCategory.name
        default:
            return "Unknown"
        }
    }
    
    private func colorForItem(_ item: Any) -> Color {
        switch item {
        case let dayCategory as DayCategory:
            return dayCategory.color
        default:
            return .blue
        }
    }
    
    private func isSelectedFilterValue(_ item: Any) -> Bool {
        switch (selectedFilterValue, item) {
        case (let selected as TimeSlot, let item as TimeSlot):
            return selected == item
        case (let selected as ExtendedLocationType, let item as ExtendedLocationType):
            return selected == item
        case (let selected as DayCategory, let item as DayCategory):
            return selected.id == item.id
        default:
            return false
        }
    }
}

/// Individual cell in the coverage grid
struct CoverageCell: View {
    let routineCount: Int
    let firstRoutine: RoutineTemplate?
    
    private var cellColor: Color {
        switch routineCount {
        case 0:
            return Color(.systemRed).opacity(0.2)
        case 1:
            return Color(.systemGreen).opacity(0.6)
        case 2...3:
            return Color(.systemOrange).opacity(0.6)
        default:
            return Color(.systemBlue).opacity(0.6)
        }
    }
    
    private var textColor: Color {
        routineCount == 0 ? .secondary : .white
    }
    
    var body: some View {
        VStack(spacing: 2) {
            if let routine = firstRoutine {
                RoundedRectangle(cornerRadius: 3)
                    .fill(routine.swiftUIColor)
                    .frame(width: 16, height: 3)
            } else {
                Spacer()
                    .frame(height: 3)
            }
            
            Text("\(routineCount)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(textColor)
        }
        .frame(width: 60, height: 44)
        .background(cellColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

#Preview {
    ContextCoverageView()
        .environment(RoutineService())
        .environment(DayCategoryManager.shared)
}