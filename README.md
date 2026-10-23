# Articles

An iOS / iPadOS app that lists articles from an API, displays detailed reading views, supports offline saving, pagination, and an interactive home screen widget with deep linking. Built for the Magycal iOS Technical Challenge (Part 1 & Part 2).

- **UIKit + Storyboards + XIBs**, MVC, with a modern **SwiftUI** widget and state components embedded via `UIHostingController`
- **iPhone and iPad** (`UISplitViewController` on iPad), deployment target **iOS 18.0**
- Works **offline**, survives **broken data**, supports **Dynamic Type**, adopts **Liquid Glass**, implements a **50 MB oldest-saved-first offline budget**, **Infinite Scroll**, and an **Interactive WidgetKit Extension**

---

## Requirements

| Tool | Version |
| --- | --- |
| Xcode | 16.0 or newer |
| iOS Deployment Target | 18.0 |
| CocoaPods | 1.16 or newer |
| Swift | 5.0 |

---

## Setup and Run

```bash
git clone https://github.com/Jay2809Praj/articles-ios-challenge.git
cd articles-ios-challenge
git checkout part-2
pod install
open Articles.xcworkspace
```

1. Select the **Articles** scheme in Xcode.
2. Choose an iOS Simulator (e.g. `iPhone 16 Pro` or `iPhone 17 Pro`) or a physical device.
3. Press **⌘R** to run. Always open the **`.xcworkspace`**, not the `.xcodeproj`.

### Running Unit Tests

Press **⌘U** in Xcode, or execute from the terminal:

```bash
xcodebuild test -workspace Articles.xcworkspace -scheme Articles \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

*All 58 unit tests pass with zero failures (`** TEST SUCCEEDED **`).*

---

## What is Implemented

| Area | Implementation |
| --- | --- |
| **Article List** | Storyboard scene, `UICollectionView` with XIB cells, list and grid layouts, inline search, and pull-to-refresh. |
| **Article Detail** | Storyboard scene following the Figma frame, favourite/save toggle, opens full article in `SFSafariViewController`. |
| **Save for Later (Feature 1)** | Dedicated Saved list, offline text and image persistence across app restarts, and 50 MB oldest-saved-first storage budget management with async re-enforcement. |
| **Infinite Scroll (Feature 2 - Option A)** | Simulated 10-article pagination behind `ArticlePaginator`, seamless automatic loading on scroll, and native footer indicator. |
| **Interactive Widget (Feature 2 - Option B)** | WidgetKit extension with `.systemSmall`, `.systemMedium`, `.systemLarge` sizes, real API data, magazine photo layout, interactive AppIntents (Next/Prev cycling), and deep linking (`articles://open?url=...`). |
| **SwiftUI Integration** | `ContentStateView` (loading skeleton, offline, error, empty, no results, iPad placeholder) hosted via `UIHostingController`. |
| **iPad Layout** | `UISplitViewController`, list and detail side-by-side; collapses to a navigation stack in compact widths. |
| **Dynamic Type** | Every font scaled through `UIFontMetrics`; cells self-size; card footers stack vertically at accessibility sizes. |
| **Liquid Glass** | Detail back button, floating "Read Full Article" button, and status banner adapt glass effects on supported versions. |
| **Interactivity** | Zoom transition from card image to detail image, interactive dismiss, and animated layout switches. |
| **Networking & Logging** | Alamofire with custom mapper to `NetworkError`; structured logging via `XCGLogger`. |
| **Dependency Injection** | Swinject container in `AppDelegate`; view controllers receive injected managers. |
| **Cache & Offline Sync** | Cache persistence for last-known articles; Reachability monitoring with automatic refresh on connection recovery. |
| **Data Robustness** | Lenient decoding of all fields, lossy array decoding, URL sanitisation, and error handling for malformed JSON. |

---

## Part 2 Deep Dive

### Feature 1: Save for Later (Offline Reading & 50 MB Budget)

Users can save articles to read offline from both the list card and the detail screen.

- **Offline Persistence**: Both article metadata and images are stored locally using `FavoritesManager`. When offline, saved articles load instantly with full text and cached images, even after a cold app relaunch.
- **Dedicated Saved Area**: Accessible via the navigation bar bookmark icon on the home screen, presenting saved articles in a dedicated collection.
- **50 MB Storage Budget Decision**:
  - The brief dictates that saved content is limited to **50 MB**.
  - **Eviction Strategy**: Implemented an **oldest-saved-first** eviction policy in `FavoritesManager`.
  - When the cumulative size of saved articles and images reaches or exceeds 50 MB (50,000,000 bytes), saving a new article automatically evicts the oldest saved article and deletes its cached image from disk until the total size is back within the safe budget.
  - **Async Image Re-enforcement**: Because image downloads complete asynchronously after an article is saved, the storage budget is **re-enforced whenever image sizes are updated**. This prevents the total from silently exceeding 50 MB when large images finish downloading.
  - **Single Article Exceeding Limit**: If a single article's total size (metadata + image) exceeds the entire 50 MB budget, it is automatically removed from saved storage to prevent permanently consuming the budget.
  - The behavior is covered by automated unit tests (`test50MBStorageLimitEvictsOldestArticleWhenExceeded`, `testAsyncImageSizeUpdateReEnforcesStorageLimit`, `testSingleArticleExceedingBudgetIsEvicted`).

---

### Feature 2: Both Options Implemented

To provide a complete, industry-grade implementation, both optional features were engineered:

#### Option A: Infinite Scroll & Pagination
- The mock API delivers all articles in a single payload.
- `ArticlePaginator` simulates server-side pagination with **10 articles per page**.
- As the user scrolls near the bottom of the feed (threshold-based trigger), the next page is loaded with a native UI activity indicator footer.
- When searching, pagination cleanly resets to page 1 for filtered results.

#### Option B: Home Screen Widget with Photos & Deep Linking
- **Target**: `ArticlesWidget` extension built using **WidgetKit**, **SwiftUI**, and **AppIntents**.
- **Supported Families**: `.systemSmall`, `.systemMedium`, and `.systemLarge`.
- **Magazine-Grade Design**:
  - **Medium**: Split layout featuring a high-resolution 112 pt rounded article thumbnail, live source indicator dot, headline, timestamp, and a "Read →" pill.
  - **Small**: Full-bleed cover photo with a cinematic dark gradient overlay, glassmorphism source tag, bold headline, and quick refresh button.
  - **Large**: Prominent hero banner image, headline, excerpt metadata, and direct action button.
- **Interactive Browsing (AppIntents)**:
  - Users can tap **Next (`>`)** or **Previous (`<`)** directly on the home screen widget to flip through articles without launching the app.
  - Runs in-process via `NextArticleIntent` and `PreviousArticleIntent`.
- **Deep Linking**:
  - Tapping an article or the "Read" button sends `articles://open?url=...`.
  - `SceneDelegate` parses incoming URL contexts and instructs `AppRouter` to navigate directly to the article's detail view.

---

## Architecture

The project adheres to strict protocol-oriented boundaries. Each layer depends only on the layer immediately below it via abstractions:

```
ViewControllers  →  Managers  →  ProviderProtocols  ←  Providers  →  Alamofire / Reachability
                         ↓
                   Cache / Store
```

```
Articles/
├── Models/
│   ├── ProviderProtocols/   ArticlesProviderProtocol, ReachabilityProviderProtocol, NetworkClientProtocol
│   └── Entities/            Article, ArticleSource, ArticlesResponse, CachedArticles (Codable), LossyArray
├── Provider/
│   ├── Client/              NetworkClient, NetworkError (+ mapper), NetworkEventLogger, ReachabilityProvider, Endpoint
│   └── Core/                ArticlesProvider
├── Managers/
│   ├── Client/              SharedArticleStore, Cache/ (ArticlesCache), Constants/, Utilities/
│   └── Core/                ArticlesManager, ConnectivityManager, FavoritesManager (+ protocols), ArticlePaginator
├── ViewControllers/
│   ├── Client/              AppRouter, ViewControllerFactory, BannerPresenter, GlassHelper, ArticleDisplay
│   ├── Core/                ArticleListViewController, ArticleDetailViewController
│   └── Cells/               ArticleCardCell, ArticleGridCell
├── Views/
│   ├── XIBs/                Cells, list header, status banner
│   ├── Storyboards/         ArticleList, ArticleDetail
│   └── SwiftUI/             ContentStateView
├── ArticlesWidget/          ArticlesWidget, ArticlesWidgetBundle, Info.plist
├── Assets.xcassets          Icons, colors, and graphics
└── AppDelegate.swift        App entry point & Swinject container setup
```

---

## Handling Bad Data and Network Scenarios

The feed contains 79 articles with deliberate edge cases, all gracefully handled:

| Feed Issue | Application Behavior |
| --- | --- |
| `title` missing | Falls back to `description`; displays "Untitled article" if both are missing. |
| `description` missing | Falls back to `content`, or "No preview is available for this article." |
| `author` is `null` | Displays publisher/source name; byline omitted if neither exists. |
| `urlToImage` is `null` or missing | Displays the design placeholder image. |
| Image fails to load | Automatically retries once, then displays placeholder. |
| Invalid / non-HTTP(S) link | "Read Full Article" button is disabled and clearly labeled. |
| Field type mismatch | Lenient decoding ignores corrupt fields while preserving the article. |
| Malformed array elements | Skipped losslessly using `LossyArray`. |
| Invalid JSON response | Displays cached articles with notice, or full error state with Retry. |

| Network Situation | Application Behavior |
| --- | --- |
| Offline with cache | Displays cached articles with pinned "You're offline" banner. |
| Offline with empty cache | Displays full-screen offline illustration with Retry action. |
| Request failure while online | Displays cache with toast notice, or error state with Retry. |
| Connection restored | Automatically dismisses offline banner and refreshes list. |

---

## Automated Unit Testing

The test suite covers **58 unit tests** with 100% pass rate:

- **`ArticlePresentationTests`** (22 tests): Date parsing, link validation, lossy decoding, paginator math, page limits, widget shared store serialization, deep link URL query parameter construction, and interactive cycling.
- **`ArticlesManagerTests`** (6 tests): Cache hit/miss fallbacks, network success caching, error propagation, and widget sync triggers.
- **`ArticlesProviderTests`** (5 tests): Endpoint security, empty article filtering, and network error handling.
- **`ConnectivityManagerTests`** (3 tests): Reachability state changes, observation unregistering, and debounce logic.
- **`FavoritesManagerTests`** (14 tests): Full model persistence, 50 MB storage budget eviction, async image size re-enforcement, single-article-over-budget handling, image cleanup on deletion, concurrent thread safety, and ordering.

---

## Third-Party Libraries

Required by the brief and integrated via CocoaPods:

- **Alamofire**: Robust networking and request management.
- **XCGLogger**: Structured, level-based console logging.
- **Swinject**: Pure dependency injection container.
- **ReachabilitySwift**: Real-time network transition monitoring.
- **Kingfisher**: Asynchronous image downloading, memory/disk caching, and downsampling.
- **Cache**: Fast, typed disk and memory storage for article feeds.

---

## With More Time

1. **Snapshot Testing**: Integrate point-free `swift-snapshot-testing` across iPhone and iPad sizes at different Dynamic Type scales.
2. **Widget Configurable Topics**: Add a SiriKit / AppIntent configuration parameter allowing users to select their favorite news category directly in the widget edit mode.
3. **CI/CD Automation**: GitHub Actions workflow running `xcodebuild test` and SwiftLint checks on every pull request.
