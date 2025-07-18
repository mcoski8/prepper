import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .frame(height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 80) // Make it look like a line of text
            
            // Summary placeholder (3 lines)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).frame(height: 16)
                RoundedRectangle(cornerRadius: 4).frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .frame(height: 16)
                    .padding(.trailing, 120) // Shorter last line
            }
        }
        .padding()
        .background(Color.black.opacity(0.3)) // Dark gray placeholder on black
        .cornerRadius(12)
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

struct SkeletonListView: View {
    let itemCount: Int
    
    init(itemCount: Int = 3) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                SkeletonView()
            }
        }
    }
}

// MARK: - Preview

struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding()
                
                SkeletonListView(itemCount: 3)
                    .padding()
                
                Spacer()
            }
        }
    }
}