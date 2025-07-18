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
        // TODO: Load from ZIM file via Kiwix
        // For now, show mock content
        
        titleLabel.text = "Controlling Severe Bleeding"
        categoryLabel.text = "MEDICAL - PRIORITY 5"
        
        let content = """
        IMMEDIATE ACTION REQUIRED
        
        1. APPLY DIRECT PRESSURE
        • Use clean cloth or gauze
        • Press firmly on wound
        • Do not remove cloth if blood soaks through
        • Add more layers on top
        
        2. ELEVATE IF POSSIBLE
        • Raise injured area above heart level
        • Continue applying pressure
        
        3. PRESSURE POINTS
        • Brachial artery (arm wounds): Inside upper arm
        • Femoral artery (leg wounds): Groin area
        • Press firmly against bone
        
        4. TOURNIQUET - LAST RESORT
        • Only if bleeding is life-threatening
        • Apply 2-3 inches above wound
        • Never on a joint
        • Tighten until bleeding stops
        • Write time on tourniquet
        • NEVER loosen once applied
        
        5. SEEK IMMEDIATE MEDICAL HELP
        • Call emergency services
        • Keep victim warm
        • Monitor for shock
        
        WARNING: Uncontrolled bleeding can lead to death in minutes. Act quickly and decisively.
        """
        
        contentTextView.text = content
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