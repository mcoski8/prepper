import UIKit
import WebKit

class ArticleViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let webView = WKWebView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()
    
    // MARK: - Properties
    
    private let articleId: String
    private let databaseManager = DatabaseManager.shared
    
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
        loadArticle()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Configure web view
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = self
        
        // Disable zoom for consistency
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        
        // Configure loading view
        loadingView.color = .white
        loadingView.hidesWhenStopped = true
        
        // Configure error label
        errorLabel.textColor = .white
        errorLabel.font = .systemFont(ofSize: 16)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        
        // Layout
        view.addSubview(webView)
        view.addSubview(loadingView)
        view.addSubview(errorLabel)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add emergency action button for critical articles
        if isEmergencyArticle() {
            addEmergencyButton()
        }
    }
    
    private func isEmergencyArticle() -> Bool {
        return [
            EmergencyArticle.hemorrhageControl,
            EmergencyArticle.cprGuide,
            EmergencyArticle.chokingResponse,
            EmergencyArticle.shockTreatment,
            EmergencyArticle.hypothermia
        ].contains(articleId)
    }
    
    private func addEmergencyButton() {
        let emergencyButton = UIButton(type: .system)
        emergencyButton.setTitle("⚡ QUICK ACTIONS", for: .normal)
        emergencyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        emergencyButton.setTitleColor(.black, for: .normal)
        emergencyButton.backgroundColor = .systemRed
        emergencyButton.layer.cornerRadius = 8
        emergencyButton.addTarget(self, action: #selector(showQuickActions), for: .touchUpInside)
        
        view.addSubview(emergencyButton)
        emergencyButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            emergencyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            emergencyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emergencyButton.widthAnchor.constraint(equalToConstant: 200),
            emergencyButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func showQuickActions() {
        // Show emergency-specific quick actions
        let alert = UIAlertController(title: "Quick Actions", message: nil, preferredStyle: .actionSheet)
        
        switch articleId {
        case EmergencyArticle.hemorrhageControl:
            alert.addAction(UIAlertAction(title: "Call 911", style: .destructive) { _ in
                self.call911()
            })
            alert.addAction(UIAlertAction(title: "Find Nearest Hospital", style: .default) { _ in
                self.findNearestHospital()
            })
            
        case EmergencyArticle.cprGuide:
            alert.addAction(UIAlertAction(title: "Start CPR Timer", style: .destructive) { _ in
                self.startCPRTimer()
            })
            alert.addAction(UIAlertAction(title: "Call 911", style: .destructive) { _ in
                self.call911()
            })
            
        default:
            break
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: false) // No animations
    }
    
    // MARK: - Article Loading
    
    private func loadArticle() {
        loadingView.startAnimating()
        
        Task {
            do {
                guard let article = try await databaseManager.getArticle(id: articleId) else {
                    showError("Article not found")
                    return
                }
                
                await displayArticle(article)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func displayArticle(_ article: Article) async {
        title = article.title
        
        let html = generateHTML(for: article)
        webView.loadHTMLString(html, baseURL: nil)
        loadingView.stopAnimating()
    }
    
    private func generateHTML(for article: Article) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, system-ui;
                    font-size: 17px;
                    line-height: 1.6;
                    color: #FFFFFF;
                    background-color: #000000;
                    padding: 16px;
                    margin: 0;
                }
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 12px;
                }
                h1 { font-size: 28px; }
                h2 { font-size: 24px; }
                h3 { font-size: 20px; }
                p { margin: 16px 0; }
                ul, ol { padding-left: 24px; }
                li { margin: 8px 0; }
                strong { font-weight: 600; }
                em { font-style: italic; }
                
                /* Emergency styling */
                .warning {
                    background-color: #990000;
                    padding: 12px;
                    border-radius: 8px;
                    margin: 16px 0;
                    font-weight: 600;
                }
                .critical {
                    background-color: #CC0000;
                    padding: 12px;
                    border-radius: 8px;
                    margin: 16px 0;
                    font-weight: 600;
                }
                .priority-\(article.priority.rawValue) {
                    border-left: 4px solid \(priorityColor(article.priority));
                    padding-left: 12px;
                }
                
                /* Touch targets */
                a, button {
                    min-height: 44px;
                    min-width: 44px;
                    display: inline-block;
                    padding: 12px;
                }
            </style>
        </head>
        <body>
            <div class="priority-\(article.priority.rawValue)">
                <h1>\(article.title)</h1>
                \(formatContent(article.content))
            </div>
        </body>
        </html>
        """
    }
    
    private func formatContent(_ content: String) -> String {
        // Convert markdown-style content to HTML
        var html = content
        
        // Headers
        html = html.replacingOccurrences(of: "\n### ", with: "\n<h3>")
        html = html.replacingOccurrences(of: "\n## ", with: "\n<h2>")
        html = html.replacingOccurrences(of: "\n# ", with: "\n<h1>")
        
        // Lists
        html = html.replacingOccurrences(of: "\n- ", with: "\n<li>")
        html = html.replacingOccurrences(of: "\n* ", with: "\n<li>")
        
        // Paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        // Bold
        html = html.replacingOccurrences(of: "**", with: "<strong>", options: .regularExpression)
        
        return html
    }
    
    private func priorityColor(_ priority: SearchResult.Priority) -> String {
        switch priority {
        case .p0: return "#FF0000"
        case .p1: return "#FF9900"
        case .p2: return "#FFCC00"
        }
    }
    
    private func showError(_ message: String) {
        loadingView.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
        webView.isHidden = true
    }
    
    // MARK: - Emergency Actions
    
    private func call911() {
        guard let url = URL(string: "tel://911") else { return }
        UIApplication.shared.open(url)
    }
    
    private func findNearestHospital() {
        // In production, would use CoreLocation and Maps
        guard let url = URL(string: "maps://?q=hospital") else { return }
        UIApplication.shared.open(url)
    }
    
    private func startCPRTimer() {
        // Would implement CPR compression timer
        // 100-120 compressions per minute
    }
}

// MARK: - WKNavigationDelegate

extension ArticleViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Prevent navigation to external links
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}