import UIKit

class SearchViewController: UIViewController {
    
    // MARK: - UI Elements
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let emptyStateLabel = UILabel()
    
    // MARK: - Data
    private var searchResults: [SearchResultItem] = []
    private var isSearching = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureSearchBar()
        configureTableView()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Pure black background for OLED
        view.backgroundColor = .black
        
        // Navigation title
        title = "PrepperApp"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Search bar styling
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search survival knowledge..."
        searchBar.delegate = self
        searchBar.searchTextField.textColor = .white
        searchBar.searchTextField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        searchBar.tintColor = .white
        
        // Remove search bar borders
        searchBar.backgroundImage = UIImage()
        searchBar.searchTextField.leftView?.tintColor = .white
        
        // Table view styling
        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.2)
        tableView.indicatorStyle = .white
        
        // Empty state
        emptyStateLabel.text = "Search for critical survival information"
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.font = .systemFont(ofSize: 16)
        emptyStateLabel.numberOfLines = 0
        
        // Add subviews
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        
        // Disable autoresizing mask
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Search bar - always at top
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Empty state label
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func configureSearchBar() {
        // Make search bar first responder on launch for quick access
        searchBar.becomeFirstResponder()
    }
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }
    
    // MARK: - Search
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            emptyStateLabel.isHidden = false
            return
        }
        
        isSearching = true
        emptyStateLabel.isHidden = true
        
        Task {
            do {
                // Initialize index if needed
                if !isIndexInitialized {
                    try await TantivyIndexManager.shared.initializeCoreIndex()
                    isIndexInitialized = true
                }
                
                // Perform search
                let results = try await TantivyIndexManager.shared.search(query: query, limit: 20)
                
                // Convert to UI model
                let uiResults = results.map { result in
                    SearchResultItem(
                        id: result.id,
                        title: result.title,
                        category: result.category,
                        summary: result.summary,
                        priority: result.priority,
                        score: result.score
                    )
                }
                
                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = uiResults
                    self.tableView.reloadData()
                    self.emptyStateLabel.isHidden = !uiResults.isEmpty
                }
                
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = []
                    self.tableView.reloadData()
                    self.emptyStateLabel.text = "Search failed. Please try again."
                    self.emptyStateLabel.isHidden = false
                }
            }
        }
    }
    
    private var isIndexInitialized = false
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Debounce search
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearchDebounced), object: nil)
        perform(#selector(performSearchDebounced), with: nil, afterDelay: 0.3)
    }
    
    @objc private func performSearchDebounced() {
        performSearch(query: searchBar.text ?? "")
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        performSearch(query: searchBar.text ?? "")
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        cell.configure(with: searchResults[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let result = searchResults[indexPath.row]
        let detailVC = ArticleDetailViewController(articleId: result.id)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Search Result Model
struct SearchResultItem {
    let id: String
    let title: String
    let category: String
    let summary: String
    let priority: Int
    let score: Float
}