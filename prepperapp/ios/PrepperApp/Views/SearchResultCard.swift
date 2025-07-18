import SwiftUI

struct SearchResultCard: View {
    let result: SearchResult
    let onTap: () -> Void
    
    // Map module to priority for color coding
    private var priorityColor: Color {
        // Assuming priority is encoded in the result somehow
        // For now, using module name as a proxy
        switch result.module {
        case "critical", "emergency":
            return .red
        case "important", "core":
            return .yellow
        default:
            return .gray
        }
    }
    
    // Determine if this is high priority based on score
    private var isHighPriority: Bool {
        result.score > 0.8
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Priority Indicator
                Rectangle()
                    .fill(priorityColor)
                    .frame(width: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title with large, bold font
                    Text(result.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Summary with good contrast
                    Text(result.summary)
                        .font(.body)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Module/Category indicator
                    HStack {
                        Text(result.module.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(priorityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        // Relevance score indicator (for debugging)
                        #if DEBUG
                        Text(String(format: "%.2f", result.score))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        #endif
                    }
                }
                
                // Chevron for navigation hint
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .imageScale(.small)
            }
            .padding(.leading, 0)
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .frame(minHeight: 100) // Large tap target
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            .contentShape(Rectangle()) // Make entire area tappable
        }
        .buttonStyle(EmergencyButtonStyle())
    }
}

// Custom button style for emergency use
struct EmergencyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Supporting Views

struct SearchResultsList: View {
    let results: [SearchResult]
    let onSelectResult: (SearchResult) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(results) { result in
                    SearchResultCard(result: result) {
                        onSelectResult(result)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

struct SearchResultCard_Previews: PreviewProvider {
    static let sampleResults = [
        SearchResult(
            doc_id: "1",
            title: "Severe Bleeding Control",
            summary: "Apply direct pressure to the wound immediately. Use a tourniquet if bleeding cannot be controlled with direct pressure. Call emergency services...",
            score: 0.95,
            module: "critical"
        ),
        SearchResult(
            doc_id: "2",
            title: "Hypothermia Treatment",
            summary: "Move to warm shelter. Remove wet clothing. Insulate the entire body. Give warm beverages if conscious. Seek medical attention...",
            score: 0.87,
            module: "important"
        ),
        SearchResult(
            doc_id: "3",
            title: "Water Purification Methods",
            summary: "Boil water for at least 1 minute. Use water purification tablets. Filter through clean cloth and sand. UV sterilization in clear bottles...",
            score: 0.72,
            module: "core"
        )
    ]
    
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            SearchResultsList(results: sampleResults) { result in
                print("Selected: \(result.title)")
            }
        }
    }
}