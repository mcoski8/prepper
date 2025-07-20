import UIKit
import Combine

class SearchViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let statusLabel = UILabel()
    
    // MARK: - Properties
    
    private let searchManager = SearchManager.shared
    private var searchResults: [SearchResult] = []
    private var cancellables = Set<AnyCancellable>()
    private var searchTimer: Timer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        observeContentState()
        setupSearchController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure search bar is always visible
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        title = "PrepperApp"
        
        // Configure navigation bar
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.isTranslucent = false
        
        // Setup table view
        tableView.backgroundColor = .black
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        // Setup progress view
        progressView.progressTintColor = .systemRed
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressView.isHidden = true
        
        // Setup status label
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        
        // Layout
        view.addSubview(tableView)
        view.addSubview(progressView)
        view.addSubview(statusLabel)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search medical conditions..."
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.barStyle = .black
        searchController.searchBar.delegate = self
        
        // Ensure search bar text is visible
        searchController.searchBar.searchTextField.textColor = .white
        searchController.searchBar.searchTextField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    private func observeContentState() {
        ContentManager.shared.$contentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUIForContentState(state)
            }
            .store(in: &cancellables)
    }
    
    private func updateUIForContentState(_ state: ContentManager.ContentState) {
        switch state {
        case .notExtracted:
            progressView.isHidden = true
            statusLabel.isHidden = false
            statusLabel.text = "Preparing emergency content..."
            searchController.searchBar.isUserInteractionEnabled = false
            
        case .extracting(let progress):
            progressView.isHidden = false
            progressView.progress = progress
            statusLabel.isHidden = false
            statusLabel.text = "Downloading full database: \(Int(progress * 100))%"
            searchController.searchBar.isUserInteractionEnabled = true
            
        case .partial:
            progressView.isHidden = true
            statusLabel.isHidden = false
            statusLabel.text = "Basic content available. Full database downloading..."
            searchController.searchBar.isUserInteractionEnabled = true
            
        case .complete:
            progressView.isHidden = true
            statusLabel.isHidden = true
            searchController.searchBar.isUserInteractionEnabled = true
            
            // Adjust table view constraints when status is hidden
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        }
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        // Cancel previous search
        searchTimer?.invalidate()
        
        // Debounce search by 300ms
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task {
                await self?.executeSearch(query: query)
            }
        }
    }
    
    @MainActor
    private func executeSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        do {
            searchResults = try await searchManager.federatedSearch(query: query)
            tableView.reloadData()
        } catch {
            print("Search error: \(error)")
            searchResults = []
            tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        let result = searchResults[indexPath.row]
        cell.configure(with: result)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false) // No animations
        
        let result = searchResults[indexPath.row]
        let articleVC = ArticleViewController(articleId: result.articleId)
        navigationController?.pushViewController(articleVC, animated: false) // No animations
    }
}

// MARK: - UISearchResultsUpdating

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text else { return }
        performSearch(query: query)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}