import UIKit

class BrowseViewController: UIViewController {
    
    // MARK: - UI Elements
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // MARK: - Data
    private var categories: [String] = []
    private var articlesByCategory: [String: [Article]] = [:]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCategories()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Browse"
        view.backgroundColor = .black
        
        // Table view
        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.2)
        tableView.indicatorStyle = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCategories() {
        categories = ContentManager.shared.availableCategories
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension BrowseViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        
        // Configure cell
        let category = categories[indexPath.row]
        cell.textLabel?.text = category.capitalized
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        
        // Add icon based on category
        let icon: String
        switch category.lowercased() {
        case "medical":
            icon = "🏥"
        case "water":
            icon = "💧"
        case "shelter":
            icon = "🏠"
        case "signaling":
            icon = "📡"
        case "navigation":
            icon = "🧭"
        case "preparation":
            icon = "📦"
        case "immediate_dangers":
            icon = "⚠️"
        default:
            icon = "📁"
        }
        
        cell.imageView?.image = UIImage(systemName: "folder.fill")
        cell.imageView?.tintColor = .systemGray
        
        // Style
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.accessoryType = .disclosureIndicator
        
        // Selection style
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        cell.selectedBackgroundView = selectedView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Categories"
    }
}

// MARK: - UITableViewDelegate
extension BrowseViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let category = categories[indexPath.row]
        let categoryVC = CategoryArticlesViewController(category: category)
        navigationController?.pushViewController(categoryVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .systemGray
        }
    }
}

// MARK: - Category Articles View Controller
class CategoryArticlesViewController: UIViewController {
    
    private let tableView = UITableView()
    private let category: String
    private var articles: [Article] = []
    
    init(category: String) {
        self.category = category
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = category.capitalized
        view.backgroundColor = .black
        
        setupTableView()
        loadArticles()
    }
    
    private func setupTableView() {
        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.2)
        tableView.indicatorStyle = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ArticleCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadArticles() {
        // In a real implementation, ContentManager would have a method for this
        // For now, we'll search for the category
        articles = ContentManager.shared.search(query: category, limit: 100)
            .map { $0.article }
            .filter { $0.category.lowercased() == category.lowercased() }
        
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension CategoryArticlesViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleCell", for: indexPath)
        
        let article = articles[indexPath.row]
        cell.textLabel?.text = article.title
        cell.textLabel?.textColor = .white
        cell.textLabel?.numberOfLines = 2
        
        // Priority indicator
        if article.priority == 0 {
            cell.textLabel?.textColor = .systemRed
        }
        
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator
        
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        cell.selectedBackgroundView = selectedView
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension CategoryArticlesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let article = articles[indexPath.row]
        let detailVC = ArticleDetailViewController(articleId: article.id)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}