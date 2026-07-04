import SwiftUI
import SwiftData

/// Routine tab: simple, clean skincare management. Morning/evening routines,
/// product tracking, irritation warnings, and consistency tracking.
/// Minimalist, controlled, and easy to maintain.
struct RoutineTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var routineItems: [RoutineItem]
    @Query private var products: [Product]
    @State private var showAddItem = false
    @State private var selectedTimeOfDay: TimeOfDay = .am

    var morningItems: [RoutineItem] {
        routineItems.filter { $0.timeOfDay == .am }.sorted { $0.order < $1.order }
    }

    var eveningItems: [RoutineItem] {
        routineItems.filter { $0.timeOfDay == .pm }.sorted { $0.order < $1.order }
    }

    func product(for routineItem: RoutineItem) -> Product? {
        products.first(where: { $0.id == routineItem.productID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time of day selector
                    RoutineTimeSelector(selected: $selectedTimeOfDay)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    
                    // Routine items for selected time
                    VStack(spacing: 12) {
                        if selectedTimeOfDay == .am {
                            if morningItems.isEmpty {
                                EmptyRoutineState(timeOfDay: .am) {
                                    showAddItem = true
                                }
                            } else {
                                ForEach(morningItems) { item in
                                    if let product = product(for: item) {
                                        RoutineItemRow(item: item, product: product)
                                    }
                                }
                            }
                        } else {
                            if eveningItems.isEmpty {
                                EmptyRoutineState(timeOfDay: .pm) {
                                    showAddItem = true
                                }
                            } else {
                                ForEach(eveningItems) { item in
                                    if let product = product(for: item) {
                                        RoutineItemRow(item: item, product: product)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                    
                    // Add item button
                    Button(action: { showAddItem = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Product")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(VColor.primary)
                        .padding(.vertical, 12)
                        .background(VColor.bgSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeBright, lineWidth: 1.5))
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                    
                    // Product health section
                    if !routineItems.isEmpty {
                        ProductHealthSection(items: routineItems)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    }
                    
                    // Consistency tracker
                    ConsistencyTrackerSection()
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(VColor.bgBase.ignoresSafeArea())
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddItem) {
                AddRoutineItemView(isPresented: $showAddItem, timeOfDay: selectedTimeOfDay, products: products)
            }
        }
    }
}

// MARK: - Routine Time Selector

private struct RoutineTimeSelector: View {
    @Binding var selected: TimeOfDay

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = time } }) {
                    HStack(spacing: 8) {
                        Image(systemName: time == .am ? "sunrise.fill" : "moon.stars.fill")
                        Text(time == .am ? "Morning" : "Evening")
                            .font(.callout.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == time ? .white : VColor.textPrimary)
                    .padding(.vertical, 10)
                    .background(selected == time ? VColor.primary : VColor.bgSurface)
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Empty Routine State

private struct EmptyRoutineState: View {
    let timeOfDay: TimeOfDay
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: timeOfDay == .am ? "sunrise.fill" : "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(VColor.primary)

            Text("No products yet")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)

            Text("Build your \(timeOfDay == .am ? "morning" : "evening") routine to track usage and see patterns.")
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text("Add First Product")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.primary)
                    .padding(.vertical, 8)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Routine Item Row

private struct RoutineItemRow: View {
    @State private var isCompleted = false
    let item: RoutineItem
    let product: Product

    var statusLabel: String {
        item.proven ? "Proven" : "Testing"
    }

    var statusColor: Color {
        item.proven ? VColor.success : VColor.warning
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { isCompleted.toggle() } }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? VColor.success : VColor.textTertiary)
            }

            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                    .strikethrough(isCompleted, color: VColor.textSecondary)

                Text(product.brand)
                    .font(.caption)
                    .foregroundStyle(VColor.textTertiary)
            }

            Spacer()

            // Status badge
            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
        .opacity(isCompleted ? 0.6 : 1)
    }
}


// MARK: - Product Health Section

private struct ProductHealthSection: View {
    let items: [RoutineItem]
    
    var workingProducts: Int { items.filter { $0.status == "Works" }.count }
    var irritatingProducts: Int { items.filter { $0.status == "Irritating" }.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Status")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            HStack(spacing: 12) {
                ProductStatusCard(
                    icon: "checkmark.circle.fill",
                    label: "Working",
                    value: workingProducts,
                    color: VColor.success
                )
                
                ProductStatusCard(
                    icon: "exclamationmark.circle.fill",
                    label: "Irritating",
                    value: irritatingProducts,
                    color: VColor.danger
                )
                
                ProductStatusCard(
                    icon: "hourglass.circle.fill",
                    label: "Testing",
                    value: items.filter { $0.status == "Testing" }.count,
                    color: VColor.warning
                )
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

private struct ProductStatusCard: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(VColor.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(VColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Consistency Tracker Section

private struct ConsistencyTrackerSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day < 5 ? VColor.success : VColor.strokeSubtle)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(day < 5 ? "✓" : "")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(day < 5 ? .white : VColor.textTertiary)
                            )
                        
                        Text(["M", "T", "W", "T", "F", "S", "S"][day])
                            .font(.caption2)
                            .foregroundStyle(VColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Add Routine Item View

private struct AddRoutineItemView: View {
    @Binding var isPresented: Bool
    let timeOfDay: TimeOfDay
    let products: [Product]

    @State private var selectedProduct: Product?

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Product") {
                    if products.isEmpty {
                        Text("No products available. Add one first.")
                            .foregroundStyle(VColor.textSecondary)
                    } else {
                        Picker("Product", selection: $selectedProduct) {
                            Text("Choose a product").tag(nil as Product?)
                            ForEach(products) { product in
                                Text("\(product.name) - \(product.brand)")
                                    .tag(product as Product?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        isPresented = false
                    }
                    .disabled(selectedProduct == nil)
                }
            }
        }
    }
}

#Preview {
    RoutineTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
