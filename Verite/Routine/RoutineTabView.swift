import SwiftUI
import SwiftData

/// Routine tab: simple, clean skincare management. Morning/evening routines,
/// product tracking, and consistency tracking.
struct RoutineTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var routineItems: [RoutineItem]
    @Query private var products: [Product]
    @State private var showAddItem = false
    @State private var selectedTimeOfDay: TimeOfDay = .am

    private var morningItems: [RoutineItem] {
        routineItems.filter { $0.timeOfDay == .am }.sorted { $0.order < $1.order }
    }

    private var eveningItems: [RoutineItem] {
        routineItems.filter { $0.timeOfDay == .pm }.sorted { $0.order < $1.order }
    }

    private func product(for routineItem: RoutineItem) -> Product? {
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
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Product")
                                .font(.headline.weight(.semibold))
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

#Preview {
    RoutineTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
