import UIKit

class DownloadManagerViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let storageHeaderView = StorageHeaderView()
    private var downloadTasks: [DownloadTask] = []
    private var progressObservers: [String: Timer] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDownloads()
        updateStorageInfo()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startProgressUpdates()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopProgressUpdates()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Downloads"
        view.backgroundColor = .black
        
        // Configure navigation bar
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        
        // Add download button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(showDownloadOptions)
        )
        
        // Setup table view
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DownloadTaskCell.self, forCellReuseIdentifier: "DownloadTaskCell")
        tableView.tableHeaderView = storageHeaderView
        
        // Layout
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Size header
        storageHeaderView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 120)
    }
    
    // MARK: - Data Loading
    
    private func loadDownloads() {
        downloadTasks = ContentDownloadManager.shared.getAllDownloads()
        tableView.reloadData()
    }
    
    private func updateStorageInfo() {
        storageHeaderView.updateStorage()
    }
    
    // MARK: - Progress Updates
    
    private func startProgressUpdates() {
        // Update every 0.5 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
        progressObservers["main"] = timer
    }
    
    private func stopProgressUpdates() {
        progressObservers.values.forEach { $0.invalidate() }
        progressObservers.removeAll()
    }
    
    private func updateProgress() {
        for (index, task) in downloadTasks.enumerated() {
            if task.status == .downloading {
                if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? DownloadTaskCell {
                    if let progress = ContentDownloadManager.shared.getDownloadProgress(for: task.id) {
                        cell.updateProgress(progress)
                    }
                }
            }
        }
        updateStorageInfo()
    }
    
    // MARK: - Actions
    
    @objc private func showDownloadOptions() {
        let alert = UIAlertController(title: "Download Content", message: "Choose content to download", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Essential Survival (2-3GB)", style: .default) { [weak self] _ in
            self?.startTier1Download()
        })
        
        alert.addAction(UIAlertAction(title: "Browse Modules", style: .default) { [weak self] _ in
            // TODO: Show module browser
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func startTier1Download() {
        ContentDownloadManager.shared.downloadTier1Content(
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.loadDownloads()
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.showAlert(title: "Download Complete", message: "Essential survival content is now available offline")
                    case .failure(let error):
                        self?.showAlert(title: "Download Failed", message: error.localizedDescription)
                    }
                    self?.loadDownloads()
                }
            }
        )
        
        loadDownloads()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension DownloadManagerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadTaskCell", for: indexPath) as! DownloadTaskCell
        let task = downloadTasks[indexPath.row]
        cell.configure(with: task)
        
        if task.status == .downloading,
           let progress = ContentDownloadManager.shared.getDownloadProgress(for: task.id) {
            cell.updateProgress(progress)
        }
        
        cell.onAction = { [weak self] action in
            self?.handleCellAction(action, for: task)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DownloadManagerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Cell Actions

extension DownloadManagerViewController {
    private func handleCellAction(_ action: DownloadTaskCell.Action, for task: DownloadTask) {
        switch action {
        case .pause:
            ContentDownloadManager.shared.pauseDownload(taskId: task.id)
        case .resume:
            ContentDownloadManager.shared.resumeDownload(taskId: task.id)
        case .cancel:
            showCancelConfirmation(for: task)
        }
        
        loadDownloads()
    }
    
    private func showCancelConfirmation(for task: DownloadTask) {
        let alert = UIAlertController(
            title: "Cancel Download?",
            message: "This will delete any partially downloaded content.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel Download", style: .destructive) { [weak self] _ in
            ContentDownloadManager.shared.cancelDownload(taskId: task.id)
            self?.loadDownloads()
        })
        
        alert.addAction(UIAlertAction(title: "Keep Downloading", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - Storage Header View

class StorageHeaderView: UIView {
    private let titleLabel = UILabel()
    private let storageBar = UIProgressView(progressViewStyle: .bar)
    private let detailLabel = UILabel()
    private let freeSpaceLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .black
        
        // Title
        titleLabel.text = "Storage"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        
        // Storage bar
        storageBar.progressTintColor = .systemBlue
        storageBar.trackTintColor = .darkGray
        
        // Detail label
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textColor = .lightGray
        
        // Free space label
        freeSpaceLabel.font = .systemFont(ofSize: 14)
        freeSpaceLabel.textColor = .lightGray
        freeSpaceLabel.textAlignment = .right
        
        // Layout
        [titleLabel, storageBar, detailLabel, freeSpaceLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            storageBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            storageBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            storageBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            storageBar.heightAnchor.constraint(equalToConstant: 8),
            
            detailLabel.topAnchor.constraint(equalTo: storageBar.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            freeSpaceLabel.topAnchor.constraint(equalTo: storageBar.bottomAnchor, constant: 8),
            freeSpaceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    func updateStorage() {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        
        if let storage = getStorageInfo() {
            let usedSpace = storage.totalSpace - storage.availableSpace
            storageBar.progress = Float(usedSpace) / Float(storage.totalSpace)
            
            detailLabel.text = "PrepperApp: \(formatter.string(fromByteCount: storage.usedByApp))"
            freeSpaceLabel.text = "\(formatter.string(fromByteCount: storage.availableSpace)) free"
        }
    }
    
    private func getStorageInfo() -> StorageInfo? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            guard let totalSpace = attributes[.systemSize] as? Int64,
                  let freeSpace = attributes[.systemFreeSize] as? Int64 else {
                return nil
            }
            
            // Calculate app usage (simplified)
            return StorageInfo(
                totalSpace: totalSpace,
                availableSpace: freeSpace,
                usedByApp: 0 // TODO: Calculate actual app usage
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Download Task Cell

class DownloadTaskCell: UITableViewCell {
    enum Action {
        case pause
        case resume
        case cancel
    }
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let sizeLabel = UILabel()
    private let speedLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
    var onAction: ((Action) -> Void)?
    private var currentTask: DownloadTask?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        // Configure labels
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .lightGray
        
        sizeLabel.font = .systemFont(ofSize: 14)
        sizeLabel.textColor = .lightGray
        
        speedLabel.font = .systemFont(ofSize: 14)
        speedLabel.textColor = .lightGray
        speedLabel.textAlignment = .right
        
        // Configure progress view
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = .darkGray
        
        // Configure action button
        actionButton.tintColor = .white
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        
        // Layout
        [titleLabel, statusLabel, progressView, sizeLabel, speedLabel, actionButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            sizeLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            speedLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            speedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionButton.widthAnchor.constraint(equalToConstant: 44),
            actionButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func configure(with task: DownloadTask) {
        currentTask = task
        
        switch task.contentType {
        case .tier1Essential:
            titleLabel.text = "Essential Survival Content"
        case .tier2Module:
            titleLabel.text = "Module Download"
        case .update:
            titleLabel.text = "Content Update"
        }
        
        statusLabel.text = task.status.rawValue.capitalized
        progressView.progress = task.progress
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        let downloaded = Int64(task.progress * Float(task.totalSize))
        sizeLabel.text = "\(formatter.string(fromByteCount: downloaded)) of \(formatter.string(fromByteCount: task.totalSize))"
        
        updateActionButton(for: task.status)
    }
    
    func updateProgress(_ progress: DownloadProgress) {
        progressView.progress = progress.overallProgress
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        sizeLabel.text = "\(formatter.string(fromByteCount: progress.downloadedBytes)) of \(formatter.string(fromByteCount: progress.totalBytes))"
        
        speedLabel.text = progress.formattedSpeed
        if let timeRemaining = progress.formattedTimeRemaining {
            speedLabel.text = "\(progress.formattedSpeed) • \(timeRemaining)"
        }
    }
    
    private func updateActionButton(for status: DownloadStatus) {
        switch status {
        case .downloading:
            actionButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        case .paused:
            actionButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        case .pending, .failed:
            actionButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        case .completed, .verifying:
            actionButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            actionButton.isEnabled = false
        }
    }
    
    @objc private func actionTapped() {
        guard let task = currentTask else { return }
        
        switch task.status {
        case .downloading:
            onAction?(.pause)
        case .paused:
            onAction?(.resume)
        case .pending, .failed:
            onAction?(.cancel)
        default:
            break
        }
    }
}