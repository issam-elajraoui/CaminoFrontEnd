import SwiftUI

// MARK: - Vue des résultats conducteurs
struct DriverResultsView: View {
    let drivers: [Driver]
    let onDriverSelected: (Driver) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(drivers) { driver in
                DriverRowView(driver: driver) {
                    onDriverSelected(driver)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Available Drivers")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
