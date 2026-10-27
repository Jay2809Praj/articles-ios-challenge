# Articles

An iOS / iPadOS app that lists articles from an API, displays detailed reading views, supports offline saving, pagination, and an interactive home screen widget with deep linking. Built for the Magycal iOS Technical Challenge (Part 1 & Part 2).

- **UIKit + Storyboards + XIBs**, MVC, with a modern **SwiftUI** widget and state components embedded via `UIHostingController`
- **iPhone and iPad** (`UISplitViewController` on iPad), deployment target **iOS 18.0**
- Works **offline**, survives **broken data**, supports **Dynamic Type**, adopts **Liquid Glass**, implements a **50 MB oldest-saved-first offline budget**, **Infinite Scroll**, and an **Interactive WidgetKit Extension**

---

## Requirements

| Tool | Version |
| --- | --- |
| Xcode | 26 (built and tested with 26.6; the Liquid Glass APIs need the iOS 26 SDK) |
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

*All 128 unit tests pass with zero failures (`** TEST SUCCEEDED **`).*

---

## What is Implemented

| Area | Implementation |
| --- | --- |
| **Article List** | Storyboard scene, `UICollectionView` with XIB cells, list and grid layouts, inline search, and pull-to-refresh. |
| **Article Detail** | Storyboard scene following the Figma frame, favourite/save toggle, opens full article in `SFSafariViewController`. |
| **Save for Later (Feature 1)** | Dedicated Saved list; article text and image stored by the app itself (images under Application Support, not an image cache) so they survive restarts and cache expiry; 50 MB oldest-saved-first storage budget counted from the real file sizes. |
| **Infinite Scroll (Feature 2 - Option A)** | Pagination simulated inside `ArticlesProvider` (10 articles per page, as if the server paginated); `ArticlesManager` loads the next page on demand, including offline from the cache; the list shows a footer indicator while a page loads. |
| **Interactive Widget (Feature 2 - Option B)** | WidgetKit extension with `.systemSmall`, `.systemMedium`, `.systemLarge` sizes, fed only by the app through an App Group (last opened, saved and latest articles with their images), interactive AppIntents (Next/Prev cycling), and deep linking (`articles://open?id=...`). |
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

- **Offline Persistence**: `FavoritesManager` persists the article record (title, description, content, metadata) with the `Cache` pod and downloads the article's image into the app's own `SavedImageStore` under `Library/Application Support/SavedArticles/Images`. That folder is not purged by the system and has no expiry, unlike Kingfisher's cache (which expires after 7 days and lives in `Caches`). When offline, saved articles open with their text and image, even after a cold relaunch or weeks without using the app.
  - The list and detail screens load a saved article's image from that file first (`RemoteImageView.setImage(with:localFile:)`), so no network or cache lookup is involved.
  - If a download did not finish (the app was killed, or the article was saved offline), the article stays saved without an image and the image is fetched again on the next launch.
  - Removing an article, eviction, and "clear all" delete the corresponding files.
- **Dedicated Saved Area**: Accessible via the navigation bar bookmark icon on the home screen, presenting saved articles in a dedicated collection.
- **50 MB Storage Budget Decision**:
  - The brief dictates that saved content is limited to **50 MB**.
  - **Eviction Strategy**: Implemented an **oldest-saved-first** eviction policy in `FavoritesManager`.
  - When the cumulative size of saved articles and images would exceed 50 MB (52,428,800 bytes), saving a new article evicts the oldest saved article and deletes its image file until the total is back within budget.
  - **Real sizes**: every image counts with the exact number of bytes its file occupies on disk, read back from the file system. Sizes are re-read on launch so the budget never drifts from reality.
  - **Async Image Re-enforcement**: Because image downloads complete asynchronously after an article is saved, the storage budget is **re-enforced whenever an image lands on disk**. This prevents the total from silently exceeding 50 MB when large images finish downloading.
  - **The user is told**: whenever the limit removes saved articles, `FavoritesManager` posts a `SavedArticlesDidEvictNotification` carrying the removed titles and the reason; the list and detail screens show a toast such as "Storage full: ‘X’ removed to make room." or "‘X’ is too large to save (over the 50 MB limit)."
  - **Usage is visible**: the Saved section shows "12.4 MB of 50 MB used" under the segmented control.
  - **QA aid**: launch the app with `-SavedArticlesStorageLimitMB 1` (Xcode scheme arguments, or `xcrun simctl launch booted com.jayprajapati.Articles -SavedArticlesStorageLimitMB 1`) to exercise eviction without saving 50 MB.
  - **Single Article Exceeding Limit**: If a single article's total size (metadata + image) exceeds the entire 50 MB budget, it is automatically removed from saved storage to prevent permanently consuming the budget.
  - The behavior is covered by automated unit tests (`test50MBStorageLimitEvictsOldestArticleWhenExceeded`, `testAsyncImageSizeUpdateReEnforcesStorageLimit`, `testSingleArticleExceedingBudgetIsEvicted`).

---

### Feature 2: Both Options Implemented

To provide a complete, industry-grade implementation, both optional features were engineered:

#### Option A: Infinite Scroll & Pagination
- The mock API delivers all articles in a single payload, so the pagination is simulated **behind the provider**, as the brief asks: everything above the provider sees a paged API.
- `ArticlesProviderProtocol` exposes `fetchArticles(page:pageSize:)` and answers with an `ArticlesPage` (`articles`, `page`, `hasMore`).
- `ArticlesProvider` plays the server: page 1 downloads the feed and keeps it as the snapshot; later pages are cut from that snapshot (**10 articles per page**) after a simulated latency of 0.6 s. Page 1 is always a fresh download, so pull-to-refresh picks up changes.
- `ArticlesManager` exposes `loadArticles()` (first page) and `loadNextPage()`. The cache holds every page loaded so far; when the network is unavailable the cached list is served in pages of the same size, so scrolling behaves the same offline.
- `ArticleListViewController` only asks the manager for the next page when the last loaded card is about to appear and shows the native activity indicator footer while waiting. It contains no paging logic or artificial delay.
- Search filters the pages loaded so far; scrolling to the end of the results keeps loading pages.
- A failed page load keeps what is on screen, shows a "Couldn't load more articles" toast, and can be retried by scrolling again.

#### Option B: Home Screen Widget with Photos & Deep Linking
- **Target**: `ArticlesWidget` extension built using **WidgetKit**, **SwiftUI**, and **AppIntents**.
- **Supported Families**: `.systemSmall`, `.systemMedium`, and `.systemLarge`.
- **Data comes from the app only**. Both targets share the App Group `group.com.jayprajapati.Articles` (see `Articles.entitlements` and `ArticlesWidget.entitlements`). The widget makes no network requests and ships no article content; when the app has not loaded anything yet it shows an "Open Articles to load the latest news" state.
  - `WidgetSyncManager` (app side) publishes up to 10 articles to `SharedArticleStore`: the article the user **opened last**, then the **saved** articles, then the **latest loaded** ones. It downloads each article's image once, downsampled to 800 px, and reloads the widget once per publish. Updates that arrive together during launch are coalesced into a single publish.
  - `SharedArticleStore` is a file-based store inside the shared container (`articles.json`, one image per article, the browse index). It is compiled into both targets and knows nothing about WidgetKit or networking.
  - The last opened article is remembered across app restarts, so after killing the app the widget still shows what the user read last.
- **Layouts**:
  - **Medium**: Split layout with a 112 pt rounded thumbnail, source, saved indicator, position (e.g. 3/10), headline, date, and a "Read →" pill.
  - **Small**: Full-bleed cover photo with a dark gradient overlay, source tag, headline, and a Next button.
  - **Large**: Hero image, source, date, position, headline, and an "Open Story" button.
- **Interactive Browsing (AppIntents)**:
  - **Next (`>`)** and **Previous (`<`)** buttons cycle through the published list without launching the app, via `NextArticleIntent` and `PreviousArticleIntent`. Opening an article in the app brings the widget back to that article; a plain refresh leaves the browse position alone.
- **Deep Linking**:
  - Tapping the widget sends `articles://open?id=<article identifier>`.
  - `SceneDelegate` looks the identifier up by exact match among the saved articles, the cached feed and the last opened article, falling back to the list's own page-1 request. `AppRouter` then closes Safari if it is open and replaces any open detail screen, so repeated widget taps never stack screens. `articles://open` without an identifier simply opens the app.

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
│   └── Entities/            Article, ArticleSource, ArticlesResponse, ArticlesPage, CachedArticles (Codable), LossyArray
├── Provider/
│   ├── Client/              NetworkClient, NetworkError (+ mapper), NetworkEventLogger, ReachabilityProvider, Endpoint
│   └── Core/                ArticlesProvider
├── Managers/
│   ├── Client/              SharedArticleStore, SavedImageStore (+ protocol), Cache/ (ArticlesCache), Constants/, Utilities/
│   └── Core/                ArticlesManager, ConnectivityManager, FavoritesManager, WidgetSyncManager (+ protocols)
├── ViewControllers/
│   ├── Client/              AppRouter, ViewControllerFactory, BannerPresenter, GlassHelper, ArticleDisplay
│   ├── Core/                ArticleListViewController, ArticleDetailViewController
│   └── Cells/               ArticleCardCell, ArticleGridCell
├── Views/
│   ├── XIBs/                Cells, list header, status banner
│   ├── Storyboards/         ArticleList, ArticleDetail
│   └── SwiftUI/             ContentStateView
├── ArticlesWidget/          ArticlesWidget, ArticlesWidgetBundle, Info.plist, ArticlesWidget.entitlements
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
| Connection restored | Dismisses the offline banner. Reloads only when the list on screen came from the cache, failed or is empty; fresh pages from the network are kept, with their scroll position. |

---

## Part 1 Review: Found and Fixed

A critical pass over the Part 1 code before this submission. Each item names what was wrong and what changed. The behavioural fixes are covered by unit tests that were run against the previous code first and failed there.

| Found | Fixed |
| --- | --- |
| Deep links matched articles by fuzzy title comparison, so two articles with similar titles could open the wrong one. | `SceneDelegate` matches on the exact `Article.identifier` (or exact `url`), looking in the saved articles, the cached feed and the last opened article before falling back to a network load. |
| Every reconnect reloaded page 1, even when the list on screen had just come from the network. The user lost their scroll position and the loaded pages, and the app sent a request it did not need. | `ArticlesLoadResult.needsRefreshWhenOnline`: a reconnect reloads only when the content is cached, failed, empty or still loading. Fresh pages stay as they are. |
| A next page that was in flight when the user pulled to refresh was appended to the *new* list when it arrived, duplicating articles and corrupting the cache. | `ArticlesManager` stamps each list with a generation; a page from an earlier generation is dropped and paging continues from the new list. |
| A cold launch from a widget tap sent two page-1 requests at once (the list screen's and the deep link's); a reconnect during a load sent a third. | `loadArticles()` shares one in-flight page-1 request between all callers. |
| Repeated widget taps pushed a new detail screen on top of the previous one, and a tap while Safari was open did nothing visible. | `AppRouter.showArticleDetail` dismisses Safari, pops to the list and shows the article once; a tap for the article already on screen is a no-op. |
| Pinning the offline banner while a "Back online" toast was still running left a cancelled timer behind, so the next `unpin()` did nothing and the offline banner stayed on screen. | `BannerPresenter.pin` clears the toast timer it cancels. |
| Typing in search faster than the 0.25 s cross-fade could leave the list and the "No results" overlay both hidden or both visible, because the guard read `isHidden` mid-animation. | The list screen tracks the intended state itself and a completion that lost a race no longer applies its stale `isHidden` values. |
| The favourite button bounced twice per tap: once from the tap and once from the change notification that followed. | The detail screen animates only when the shown state actually changed. |
| The README asked for Xcode 16, but the project uses Liquid Glass APIs that need the iOS 26 SDK. | The requirement says Xcode 26, matching the build that was tested. |

---

## Automated Unit Testing

The test suite covers **128 unit tests** with 100% pass rate:

- **`ArticleDecodingTests`** (8 tests): Fault-tolerant decoding of missing, null, empty and mistyped fields and malformed array elements.
- **`ArticlePresentationTests`** (25 tests): Storage size formatting, limit override from launch argument, storage-limit banner wording, Date parsing, link validation, display fallbacks, search filtering, section filter, `SharedArticleStore` (save/load, cycling and wrap-around, index reset when the list shrinks, per-article images and pruning, inert without a container) and deep link construction.
- **`ArticleListViewControllerTests`** (5 tests): The real list screen built by `ViewControllerFactory`: reconnecting keeps fresh pages without a request but reloads cached, failed or empty content, and the "No results" overlay survives typing faster than its cross-fade.
- **`ArticlesManagerTests`** (19 tests): First page caching, cache fallback on failure, next pages appended and cached, failed page retry, reload discarding later pages, offline paging from the cache, lookups ignoring paging, widget publishing, a stale next page dropped after a refresh, overlapping page-1 calls sharing one request, and the reconnect rule.
- **`ArticlesProviderTests`** (11 tests): Page slicing, `hasMore`, snapshot reuse with simulated latency, page 1 refreshing the snapshot, boundary pages, empty feed, invalid page numbers, filtering of empty articles, invalid JSON and network errors, endpoint security.
- **`BannerPresenterTests`** (3 tests): A pinned banner leaves on unpin, also when it was pinned while a toast was running; unpin during a toast lets the toast finish.
- **`ConnectivityManagerTests`** (3 tests): Reachability state changes, observation unregistering, and debounce logic.
- **`FavoritesManagerTests`** (26 tests): Eviction notifications (titles, oldest first, too-large reason, description fallback, none without eviction), Full model persistence, images downloaded into the app's store with their real size, image file deleted on removal and eviction, failed and late downloads, missing images fetched again on launch, sizes re-read from disk, 50 MB budget eviction, async re-enforcement, single-article-over-budget handling, concurrent thread safety, ordering, and widget publishing.
- **`SavedImageStoreTests`** (7 tests): File written under Application Support with its real size, replace, remove, remove all, empty data rejected, unknown article has no image.
- **`WidgetSyncManagerTests`** (21 tests): List composition (last opened, saved, latest; de-duplication; cap of 10; title fallbacks), single publish with one reload, image download de-duplication, failed downloads, coalescing of launch-time updates, no pruning or index reset on relaunch, last opened persistence and lookup for deep links, and JPEG downsampling.

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
