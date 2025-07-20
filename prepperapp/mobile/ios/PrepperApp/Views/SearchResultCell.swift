import UIKit

class SearchResultCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private let priorityIndicator = UIView()
    private let titleLabel = UILabel()
    private let snippetLabel = UILabel()
    private let scoreLabel = UILabel()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .black
        selectionStyle = .none // We'll handle selection visually
        
        // Priority indicator
        priorityIndicator.layer.cornerRadius = 2
        priorityIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priorityIndicator)
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Snippet label
        snippetLabel.font = .systemFont(ofSize: 14)
        snippetLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        snippetLabel.numberOfLines = 2
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(snippetLabel)
        
        // Score label (for debugging, can be hidden in production)
        scoreLabel.font = .systemFont(ofSize: 12)
        scoreLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scoreLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            // Priority indicator
            priorityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            priorityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 4),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 40),
            
            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: scoreLabel.leadingAnchor, constant: -8),
            
            // Snippet label
            snippetLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            snippetLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            snippetLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            snippetLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // Score label
            scoreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scoreLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            scoreLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add separator
        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with result: SearchResult) {
        titleLabel.text = result.title
        snippetLabel.text = result.snippet
        scoreLabel.text = String(format: "%.1f", result.score)
        
        // Color code by priority
        switch result.priority {
        case .p0:
            priorityIndicator.backgroundColor = .systemRed
            titleLabel.textColor = .white
        case .p1:
            priorityIndicator.backgroundColor = .systemOrange
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        case .p2:
            priorityIndicator.backgroundColor = .systemYellow
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        }
        
        // Highlight exact matches
        if result.isExactMatch {
            titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        } else {
            titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        }
    }
    
    // MARK: - Selection
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: false) // No animations
        
        if highlighted {
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        } else {
            contentView.backgroundColor = .clear
        }
    }
}