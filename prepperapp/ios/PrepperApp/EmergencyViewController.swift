import UIKit

class EmergencyViewController: UIViewController {
    
    // MARK: - UI Elements
    private let headerLabel = UILabel()
    private let collectionView: UICollectionView
    private let loadingView = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    private var emergencyArticles: [Article] = []
    private var groupedArticles: [String: [Article]] = [:]
    private var categories: [String] = []
    
    // MARK: - Init
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
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
        loadEmergencyContent()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Pure black for OLED
        view.backgroundColor = .black
        
        // Header
        headerLabel.text = "EMERGENCY"
        headerLabel.font = .systemFont(ofSize: 34, weight: .bold)
        headerLabel.textColor = .systemRed
        headerLabel.textAlignment = .center
        
        // Collection view
        collectionView.backgroundColor = .black
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(EmergencyCell.self, forCellWithReuseIdentifier: "EmergencyCell")
        collectionView.register(EmergencySectionHeader.self, 
                              forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                              withReuseIdentifier: "SectionHeader")
        
        // Loading
        loadingView.color = .white
        loadingView.hidesWhenStopped = true
        
        // Add subviews
        view.addSubview(headerLabel)
        view.addSubview(collectionView)
        view.addSubview(loadingView)
        
        // Disable autoresizing
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Collection view
            collectionView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Loading
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Content Loading
    private func loadEmergencyContent() {
        loadingView.startAnimating()
        
        // Get priority 0 articles
        emergencyArticles = ContentManager.shared.getArticlesByPriority(0)
        
        // Group by category
        groupedArticles = Dictionary(grouping: emergencyArticles, by: { $0.category })
        categories = Array(groupedArticles.keys).sorted()
        
        loadingView.stopAnimating()
        collectionView.reloadData()
        
        if emergencyArticles.isEmpty {
            showEmptyState()
        }
    }
    
    private func showEmptyState() {
        let emptyLabel = UILabel()
        emptyLabel.text = "No emergency content available"
        emptyLabel.textColor = .systemGray
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - UICollectionViewDataSource
extension EmergencyViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let category = categories[section]
        return groupedArticles[category]?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmergencyCell", for: indexPath) as! EmergencyCell
        
        let category = categories[indexPath.section]
        if let articles = groupedArticles[category] {
            let article = articles[indexPath.item]
            cell.configure(with: article)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as! EmergencySectionHeader
            header.titleLabel.text = categories[indexPath.section].uppercased()
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension EmergencyViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 44 // 16 + 12 + 16
        let availableWidth = collectionView.frame.width - padding
        let itemWidth = (availableWidth / 2).rounded(.down)
        return CGSize(width: itemWidth, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 40)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let category = categories[indexPath.section]
        if let articles = groupedArticles[category] {
            let article = articles[indexPath.item]
            let detailVC = ArticleDetailViewController(articleId: article.id)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}

// MARK: - Emergency Cell
class EmergencyCell: UICollectionViewCell {
    
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let urgencyBadge = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Cell styling - high contrast
        contentView.backgroundColor = .systemRed
        contentView.layer.cornerRadius = 12
        
        // Icon (using emoji for simplicity)
        iconLabel.font = .systemFont(ofSize: 36)
        iconLabel.textAlignment = .center
        
        // Title
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        
        // Urgency badge
        urgencyBadge.text = "CRITICAL"
        urgencyBadge.font = .systemFont(ofSize: 10, weight: .bold)
        urgencyBadge.textColor = .systemRed
        urgencyBadge.backgroundColor = .white
        urgencyBadge.textAlignment = .center
        urgencyBadge.layer.cornerRadius = 4
        urgencyBadge.clipsToBounds = true
        
        // Add subviews
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(urgencyBadge)
        
        // Layout
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        urgencyBadge.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // Badge
            urgencyBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            urgencyBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            urgencyBadge.widthAnchor.constraint(equalToConstant: 60),
            urgencyBadge.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
    
    func configure(with article: Article) {
        titleLabel.text = article.title.uppercased()
        
        // Set icon based on category
        switch article.category.lowercased() {
        case "medical":
            iconLabel.text = "🏥"
            contentView.backgroundColor = .systemRed
        case "water":
            iconLabel.text = "💧"
            contentView.backgroundColor = .systemBlue
        case "shelter":
            iconLabel.text = "🏠"
            contentView.backgroundColor = .systemOrange
        case "signaling":
            iconLabel.text = "📡"
            contentView.backgroundColor = .systemGreen
        default:
            iconLabel.text = "⚠️"
            contentView.backgroundColor = .systemGray
        }
        
        // Show time critical badge if applicable
        if let timeCritical = article.timeCritical {
            urgencyBadge.text = timeCritical.uppercased()
            urgencyBadge.isHidden = false
        } else {
            urgencyBadge.isHidden = true
        }
    }
}

// MARK: - Section Header
class EmergencySectionHeader: UICollectionReusableView {
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}