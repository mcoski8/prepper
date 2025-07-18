import UIKit

class SearchResultCell: UITableViewCell {
    
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let summaryLabel = UILabel()
    private let priorityIndicator = UIView()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Cell background
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        
        // Category label  
        categoryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        categoryLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        
        // Summary label
        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        summaryLabel.numberOfLines = 2
        
        // Priority indicator
        priorityIndicator.layer.cornerRadius = 2
        
        // Add subviews
        contentView.addSubview(priorityIndicator)
        contentView.addSubview(titleLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(summaryLabel)
        
        // Disable autoresizing
        priorityIndicator.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Selection style
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        selectedBackgroundView = selectedView
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Priority indicator
            priorityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            priorityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 4),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 40),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: categoryLabel.leadingAnchor, constant: -8),
            
            // Category label
            categoryLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            categoryLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Summary label
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            summaryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        // Set content hugging and compression resistance
        categoryLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    
    // MARK: - Configuration
    func configure(with result: SearchResultItem) {
        titleLabel.text = result.title
        categoryLabel.text = result.category.uppercased()
        summaryLabel.text = result.summary
        
        // Set priority indicator color based on priority level
        switch result.priority {
        case 5:
            priorityIndicator.backgroundColor = UIColor.systemRed
        case 4:
            priorityIndicator.backgroundColor = UIColor.systemOrange
        case 3:
            priorityIndicator.backgroundColor = UIColor.systemYellow
        default:
            priorityIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        }
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        categoryLabel.text = nil
        summaryLabel.text = nil
        priorityIndicator.backgroundColor = .clear
    }
}