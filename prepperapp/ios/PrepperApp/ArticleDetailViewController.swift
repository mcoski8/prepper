import UIKit
import WebKit

class ArticleDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let articleId: String
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let contentTextView = UITextView()
    
    // MARK: - Initialization
    init(articleId: String) {
        self.articleId = articleId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadArticle()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Background
        view.backgroundColor = .black
        scrollView.backgroundColor = .black
        contentView.backgroundColor = .black
        
        // Configure scroll view
        scrollView.indicatorStyle = .white
        scrollView.alwaysBounceVertical = true
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        
        // Category label
        categoryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        categoryLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        
        // Content text view
        contentTextView.backgroundColor = .black
        contentTextView.textColor = UIColor.white.withAlphaComponent(0.9)
        contentTextView.font = .systemFont(ofSize: 17)
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        contentTextView.textContainer.lineFragmentPadding = 0
        
        // Navigation
        navigationItem.largeTitleDisplayMode = .never
        
        // Emergency mode button
        let emergencyButton = UIBarButtonItem(
            image: UIImage(systemName: "bolt.fill"),
            style: .plain,
            target: self,
            action: #selector(toggleEmergencyMode)
        )
        navigationItem.rightBarButtonItem = emergencyButton
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(contentTextView)
        
        // Disable autoresizing
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Category label
            categoryLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Content text view
            contentTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    private func loadArticle() {
        // Load article from ContentManager
        guard let article = ContentManager.shared.getArticle(id: articleId) else {
            showError()
            return
        }
        
        // Update UI with article data
        titleLabel.text = article.title
        
        // Format category label with priority
        let priorityText = article.priority == 0 ? "CRITICAL" : "PRIORITY \(article.priority)"
        categoryLabel.text = "\(article.category.uppercased()) - \(priorityText)"
        
        // Color code based on priority
        if article.priority == 0 {
            categoryLabel.textColor = .systemRed
        }
        
        // Show time critical info if available
        if let timeCritical = article.timeCritical {
            categoryLabel.text = "\(categoryLabel.text ?? "") - \(timeCritical)"
        }
        
        contentTextView.text = article.content
    }
    
    private func showError() {
        titleLabel.text = "Article Not Found"
        categoryLabel.text = "ERROR"
        contentTextView.text = "The requested article could not be loaded. Please try searching for it instead."
        categoryLabel.textColor = .systemRed
    }
    
    // MARK: - Actions
    @objc private func toggleEmergencyMode() {
        // TODO: Implement emergency mode
        // Strip all non-essential UI elements
        // Increase font size
        // Show only critical information
        
        let alert = UIAlertController(
            title: "Emergency Mode",
            message: "This will optimize the display for emergency situations with larger text and essential info only.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Enable", style: .destructive) { _ in
            // Enable emergency mode
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}