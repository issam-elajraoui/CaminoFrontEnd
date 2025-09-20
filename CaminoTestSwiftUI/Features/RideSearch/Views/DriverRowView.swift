import SwiftUI

// MARK: - Vue ligne conducteur
struct DriverRowView: View {
    let driver: Driver
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("★")
                        .foregroundColor(.orange)
                    Text("\(driver.rating, specifier: "%.1f")")
                        .font(.caption)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(driver.eta)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(driver.price)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

