import UIKit
import WordPressAuthenticator

private struct PrepublishingOption {
    let id: PrepublishingIdentifier
    let title: String
    let type: PrepublishingCellType
}

private enum PrepublishingCellType {
    case value
    case textField

    var cellType: UITableViewCell.Type {
        switch self {
        case .value:
            return WPTableViewCell.self
        case .textField:
            return WPTextFieldTableViewCell.self
        }
    }
}

enum PrepublishingIdentifier {
    case title
    case schedule
    case visibility
    case tags
    case categories
}

class PrepublishingViewController: UITableViewController {
    let post: Post

    lazy var header: PrepublishingHeaderView = {
         let header = PrepublishingHeaderView.loadFromNib()
         return header
     }()

    private lazy var publishSettingsViewModel: PublishSettingsViewModel = {
        return PublishSettingsViewModel(post: post)
    }()

    private lazy var presentedVC: DrawerPresentationController? = {
        return (navigationController as? PrepublishingNavigationController)?.presentedVC
    }()

    private let completion: (AbstractPost) -> ()

    private let options: [PrepublishingOption]

    private var didTapPublish = false

    let publishButton: NUXButton = {
        let nuxButton = NUXButton()
        nuxButton.isPrimary = true

        return nuxButton
    }()

    init(post: Post, identifiers: [PrepublishingIdentifier], completion: @escaping (AbstractPost) -> ()) {
        self.post = post
        self.options = identifiers.map { identifier in
            return PrepublishingViewController.option(for: identifier)
        }
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""

        header.delegate = self
        header.configure(post.blog)
        setupPublishButton()
        setupFooterSeparator()

        updatePublishButtonLabel()
        announcePublishButton()

        preferredContentSize = tableView.contentSize
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let isPresentingAViewController = navigationController?.viewControllers.count ?? 0 > 1
        if isPresentingAViewController {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Constants.headerHeight
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let option = options[indexPath.row]

        let cell = dequeueCell(for: option.type, indexPath: indexPath)

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = .zero
        cell.layoutMargins = Constants.cellMargins

        switch option.type {
        case .textField:
            if let cell = cell as? WPTextFieldTableViewCell {
                setupTextFieldCell(cell)
            }
        case .value:
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = option.title
        }

        switch option.id {
        case .title:
            if let cell = cell as? WPTextFieldTableViewCell {
                configureTitleCell(cell)
            }
        case .tags:
            configureTagCell(cell)
        case .visibility:
            configureVisibilityCell(cell)
        case .schedule:
            configureScheduleCell(cell)
        case .categories:
            configureCategoriesCell(cell)
        }

        return cell
    }

    private func dequeueCell(for type: PrepublishingCellType, indexPath: IndexPath) -> WPTableViewCell {
        switch type {
        case .textField:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.textFieldReuseIdentifier) as? WPTextFieldTableViewCell else {
                return WPTextFieldTableViewCell.init(style: .default, reuseIdentifier: Constants.textFieldReuseIdentifier)
            }
            return cell
        case .value:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.reuseIdentifier) as? WPTableViewCell else {
                return WPTableViewCell.init(style: .value1, reuseIdentifier: Constants.reuseIdentifier)
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch options[indexPath.row].id {
        case .title:
            break
        case .tags:
            didTapTagCell()
        case .visibility:
            didTapVisibilityCell()
        case .schedule:
            didTapSchedule(indexPath)
        case .categories:
            didTapCategoriesCell()
        }
    }

    private func reloadData() {
        tableView.reloadData()
    }

    private static func option(for identifier: PrepublishingIdentifier) -> PrepublishingOption {
        switch identifier {
        case .title:
            return PrepublishingOption(id: .title, title: Constants.titlePlaceholder, type: .textField)
        case .schedule:
            return PrepublishingOption(id: .schedule, title: Constants.publishDateLabel, type: .value)
        case .categories:
            return PrepublishingOption(id: .categories, title: NSLocalizedString("Categories", comment: "Label for Categories"), type: .value)
        case .visibility:
            return PrepublishingOption(id: .visibility, title: NSLocalizedString("Visibility", comment: "Label for Visibility"), type: .value)
        case .tags:
            return PrepublishingOption(id: .tags, title: NSLocalizedString("Tags", comment: "Label for Tags"), type: .value)
        }
    }

    private func setupTextFieldCell(_ cell: WPTextFieldTableViewCell) {
        WPStyleGuide.configureTableViewTextCell(cell)
        cell.delegate = self
    }

    // MARK: - Titls

    private func configureTitleCell(_ cell: WPTextFieldTableViewCell) {
        cell.textField.text = post.postTitle
        cell.textField.textColor = .text
        cell.textField.placeholder = "Title"
        cell.textField.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    // MARK: - Tags

    private func configureTagCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = post.tags
    }

    private func didTapTagCell() {
        let tagPickerViewController = PostTagPickerViewController(tags: post.tags ?? "", blog: post.blog)

        tagPickerViewController.onValueChanged = { [weak self] tags in
            WPAnalytics.track(.editorPostTagsChanged, properties: Constants.analyticsDefaultProperty)

            self?.post.tags = tags
            self?.reloadData()
        }

        tagPickerViewController.onContentViewHeightDetermined = { [weak self] in
            self?.presentedVC?.containerViewWillLayoutSubviews()
        }

        navigationController?.pushViewController(tagPickerViewController, animated: true)
    }

    private func configureCategoriesCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = post.categories?.array.map { $0.categoryName }.joined(separator: ",")
    }

    private func didTapCategoriesCell() {
        let categoriesViewController = PostCategoriesViewController(blog: post.blog, currentSelection: post.categories?.array, selectionMode: .post)
        categoriesViewController.delegate = self
        categoriesViewController.onCategoriesChanged = { [weak self] in
            self?.presentedVC?.containerViewWillLayoutSubviews()
            self?.tableView.reloadData()
        }

        categoriesViewController.onTableViewHeightDetermined = { [weak self] in
            self?.presentedVC?.containerViewWillLayoutSubviews()
        }

        navigationController?.pushViewController(categoriesViewController, animated: true)
       }

    // MARK: - Visibility

    private func configureVisibilityCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = post.titleForVisibility
    }

    private func didTapVisibilityCell() {
        let visbilitySelectorViewController = PostVisibilitySelectorViewController(post)

        visbilitySelectorViewController.completion = { [weak self] option in
            self?.reloadData()
            self?.updatePublishButtonLabel()

            WPAnalytics.track(.editorPostVisibilityChanged, properties: Constants.analyticsDefaultProperty)

            // If tue user selects password protected, prompt for a password
            if option == AbstractPost.passwordProtectedLabel {
                self?.showPasswordAlert()
            } else {
                self?.navigationController?.popViewController(animated: true)
            }
        }

        navigationController?.pushViewController(visbilitySelectorViewController, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preferredContentSize = tableView.contentSize
    }

    // MARK: - Schedule

    func configureScheduleCell(_ cell: WPTableViewCell) {
        cell.textLabel?.text = post.shouldPublishImmediately() ? Constants.publishDateLabel : Constants.scheduledLabel
        cell.detailTextLabel?.text = publishSettingsViewModel.detailString
        post.status == .publishPrivate ? cell.disable() : cell.enable()
    }

    func didTapSchedule(_ indexPath: IndexPath) {
        transitionIfVoiceOverDisabled(to: .hidden)
        SchedulingCalendarViewController.present(
            from: self,
            sourceView: tableView.cellForRow(at: indexPath)?.contentView,
            viewModel: publishSettingsViewModel,
            updated: { [weak self] date in
                WPAnalytics.track(.editorPostScheduledChanged, properties: Constants.analyticsDefaultProperty)
                self?.publishSettingsViewModel.setDate(date)
                self?.reloadData()
                self?.updatePublishButtonLabel()
            },
            onDismiss: { [weak self] in
                self?.reloadData()
                self?.transitionIfVoiceOverDisabled(to: .collapsed)
            }
        )
    }

    // MARK: - Publish Button

    private func setupPublishButton() {
        let footer = UIView(frame: Constants.footerFrame)
        footer.addSubview(publishButton)
        footer.pinSubviewToSafeArea(publishButton, insets: Constants.nuxButtonInsets)
        publishButton.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = footer
        publishButton.addTarget(self, action: #selector(publish(_:)), for: .touchUpInside)
        updatePublishButtonLabel()
    }

    private func setupFooterSeparator() {
        guard let footer = tableView.tableFooterView else {
            return
        }

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: footer.topAnchor),
            separator.leftAnchor.constraint(equalTo: footer.leftAnchor),
            separator.rightAnchor.constraint(equalTo: footer.rightAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        WPStyleGuide.applyBorderStyle(separator)
    }

    private func updatePublishButtonLabel() {
        publishButton.isEnabled = post.postTitle?.isEmpty == false
        publishButton.setTitle(post.isScheduled() ? Constants.scheduleNow : Constants.publishNow, for: .normal)
    }

    @objc func publish(_ sender: UIButton) {
        didTapPublish = true
        navigationController?.dismiss(animated: true) {
            WPAnalytics.track(.editorPostPublishNowTapped)
            self.completion(self.post)
        }
    }

    // MARK: - Password Prompt

    private func showPasswordAlert() {
        let passwordAlertController = PasswordAlertController(onSubmit: { [weak self] password in
            guard let password = password, !password.isEmpty else {
                self?.cancelPasswordProtectedPost()
                return
            }

            self?.post.password = password
            self?.navigationController?.popViewController(animated: true)
        }, onCancel: { [weak self] in
            self?.cancelPasswordProtectedPost()
        })

        passwordAlertController.show(from: self)
    }

    private func cancelPasswordProtectedPost() {
        post.status = .publish
        post.password = nil
        reloadData()
    }

    // MARK: - Accessibility

    private func announcePublishButton() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            UIAccessibility.post(notification: .screenChanged, argument: self.publishButton)
        }
    }

    /// Only perform a transition if Voice Over is disabled
    /// This avoids some unresponsiveness
    private func transitionIfVoiceOverDisabled(to position: DrawerPosition) {
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }

        presentedVC?.transition(to: position)
    }

    private enum Constants {
        static let reuseIdentifier = "wpTableViewCell"
        static let textFieldReuseIdentifier = "wpTextFieldCell"
        static let nuxButtonInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        static let cellMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        static let footerFrame = CGRect(x: 0, y: 0, width: 100, height: 80)
        static let publishNow = NSLocalizedString("Publish Now", comment: "Label for a button that publishes the post")
        static let scheduleNow = NSLocalizedString("Schedule Now", comment: "Label for the button that schedules the post")
        static let publishDateLabel = NSLocalizedString("Publish Date", comment: "Label for Publish date")
        static let scheduledLabel = NSLocalizedString("Scheduled for", comment: "Scheduled for [date]")
        static let titlePlaceholder = NSLocalizedString("Title", comment: "Placeholder for title")
        static let headerHeight: CGFloat = 70
        static let analyticsDefaultProperty = ["via": "prepublishing_nudges"]
    }
}

extension PrepublishingViewController: PrepublishingHeaderViewDelegate {
    func closeButtonTapped() {
        dismiss(animated: true)
    }
}

extension PrepublishingViewController: PrepublishingDismissible {
    func handleDismiss() {
        guard
            !didTapPublish,
            post.status == .publishPrivate,
            let originalStatus = post.original?.status else {
            return
        }

        post.status = originalStatus
    }
}

extension PrepublishingViewController: WPTextFieldTableViewCellDelegate {
    func cellWants(toSelectNextField cell: WPTextFieldTableViewCell!) {

    }

    func cellTextDidChange(_ cell: WPTextFieldTableViewCell!) {
        WPAnalytics.track(.editorPostTitleChanged, properties: Constants.analyticsDefaultProperty)
        publishButton.isEnabled = true
        post.postTitle = cell.textField.text
        updatePublishButtonLabel()
    }
}

extension PrepublishingViewController: PostCategoriesViewControllerDelegate {
    func postCategoriesViewController(_ controller: PostCategoriesViewController, didUpdateSelectedCategories categories: NSSet) {
        WPAnalytics.track(.editorPostCategoryChanged, properties: ["via": "prepublishing_nudges"])

        // Save changes.
        guard let categories = categories as? Set<PostCategory> else {
             return
        }
        post.categories = categories
        post.save()
    }
}

extension Set {
    var array: [Element] {
        return Array(self)
    }
}
