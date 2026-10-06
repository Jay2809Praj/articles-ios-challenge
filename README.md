# Articles

An iOS / iPadOS app that lists articles from a mock API and shows a detail screen for each one. Built for the Magycal iOS challenge.

- **UIKit + Storyboards + XIBs**, MVC, with one self-contained **SwiftUI** component embedded through `UIHostingController`
- **iPhone and iPad** (`UISplitViewController` on iPad), deployment target **iOS 18.0**
- Works **offline**, survives **broken data**, supports **Dynamic Type**, and adopts **Liquid Glass** on iOS 26 with a fallback for iOS 18–25

## Requirements

| Tool | Version |
| --- | --- |
| Xcode | 26 (built and tested with 26.6) |
| iOS deployment target | 18.0 |
| CocoaPods | 1.16 or newer |

## Setup and run

```bash
git clone https://github.com/Jay2809Praj/articles-ios-challenge.git
cd articles-ios-challenge
pod install
open Articles.xcworkspace
```

Select the **Articles** scheme, choose an iPhone or iPad simulator (or a device), and run. Always open the **workspace**, not the project.

To run the unit tests press `⌘U`, or:

```bash
xcodebuild test -workspace Articles.xcworkspace -scheme Articles \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## What is implemented

| Area | Implementation |
| --- | --- |
| Article list | Storyboard scene, `UICollectionView` with XIB-based cells, list and grid layouts from the design, inline search |
| Article detail | Storyboard scene following the Figma frame, favourite toggle, opens the full article in `SFSafariViewController` |
| SwiftUI | `ContentStateView` (loading skeleton, offline, error, empty, no results, iPad placeholder) hosted by `ContentStateViewController` |
| iPad | `UISplitViewController`, list and detail side by side; collapses to a navigation stack in compact widths |
| Dynamic Type | Every font goes through `UIFontMetrics`; cells self-size; the card footer stacks vertically at accessibility sizes |
| Liquid Glass | Detail back button, floating "Read Full Article" button and status banner use glass on iOS 26 behind `#available`, with blur / solid fallbacks |
| Interactivity | Pull-to-refresh, zoom transition from the card image into the detail image, press states, animated state changes |
| Networking | Alamofire, one `NetworkError` type for every failure |
| Logging | XCGLogger: requests at `debug`, responses at `info`, headers at `verbose`, cache fallbacks at `warning`, failures at `error` |
| Dependency injection | Swinject container set up in `AppDelegate`; view controllers receive managers through their initialisers |
| Cache | The last loaded list is persisted with Cache and shown when the device is offline or the request fails |
| Connectivity | ReachabilitySwift; an offline banner or full-screen state is shown, and the list refreshes automatically when the connection returns |
| Images | Kingfisher with downsampling, the design's placeholder while loading and as fallback for missing, invalid or failing URLs |
| Data robustness | Lenient decoding of every field, lossy array decoding, link validation, invalid JSON reported as an error state |

## Architecture

The project follows the structure requested in the challenge. Each layer only knows the one below it, and only through protocols.

```
ViewControllers  →  Managers  →  ProviderProtocols  ←  Providers  →  Alamofire / Reachability
                        ↓
                      Cache
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
│   ├── Client/              Cache/ (ArticlesCache), Constants/ (colours, fonts, icons, metrics), Utilities/
│   └── Core/                ArticlesManager, ConnectivityManager, FavoritesManager (+ their protocols)
├── ViewControllers/
│   ├── Client/              AppRouter, ViewControllerFactory, banner, glass helper, reusable view classes
│   ├── Core/                ArticleListViewController, ArticleDetailViewController
│   └── Cells/               ArticleCardCell, ArticleGridCell
├── Views/
│   ├── XIBs/                Cells, list header, Read More button, status banner
│   ├── Storyboards/         ArticleList, ArticleDetail
│   └── SwiftUI/             ContentStateView
├── Assets.xcassets          Colours, icons and images exported from Figma
├── Assets/Fonts/            Roboto, Roboto Condensed, Montserrat
├── AppDelegate.swift        App start-up and Swinject container
├── SceneDelegate.swift      Window set-up
└── LaunchScreen.storyboard
```

**How the rules of the brief are met**

- *View controllers talk only to Managers.* `ArticleListViewController` depends on `ArticlesManagerProtocol` and `ConnectivityManagerProtocol`; `ArticleDetailViewController` on `FavoritesManagerProtocol`. Neither imports Alamofire, Cache, Reachability or Swinject.
- *Managers talk to Providers through protocols.* `ArticlesManager` only sees `ArticlesProviderProtocol` and `ArticlesCacheProtocol`, which is what lets `ArticlesTests` replace both with mocks.
- *View controllers do not create their dependencies.* `ViewControllerFactory` instantiates each storyboard scene with `instantiateViewController(identifier:creator:)` and passes managers resolved from the container into a custom `init?(coder:…)`. A view controller cannot exist without them.
- *Single responsibility.* The list screen is split into the view controller (state and coordination), `ArticleListDataSource`, `ArticleListLayoutFactory`, `ArticleListHeaderView`, `BannerPresenter` and `ArticleDisplay` (formatting and fallbacks).

## Handling bad data and bad networks

The mock API contains 79 articles with these problems, all of which are handled:

| Problem in the feed | Behaviour |
| --- | --- |
| `title` missing | The description is used as the title; "Untitled article" if both are missing |
| `description` missing or empty | The body falls back to the content, or to "No preview is available for this article." |
| `author` is `null` | The publisher name is shown instead; the byline is omitted if neither exists |
| `urlToImage` is `null`, empty or missing | The design's placeholder image is shown |
| Image fails to load | One retry, then the same placeholder |
| Invalid or non-http(s) link | The "Read Full Article" button is disabled and labelled "Full article unavailable" |
| A field has the wrong type | That field becomes `nil`; the article is kept |
| An array element is not an object | That element is skipped; the rest are kept |
| The whole payload is invalid JSON | Cached articles are shown with a notice, or an error state with Retry if nothing is cached |

| Network situation | Behaviour |
| --- | --- |
| Offline with cached articles | The cached list is shown with a pinned "You're offline · Saved …" banner |
| Offline with nothing cached | The "You're offline" screen from the design, with Retry |
| Request fails while online | Cached list plus a "Couldn't refresh" toast, or an error state with Retry |
| Connection returns | "Back online" toast and an automatic refresh |

To see these states, run on a device and use Airplane Mode, or use the Network Link Conditioner.

## Third-party libraries

Required by the brief and all in use: **Alamofire**, **XCGLogger**, **Swinject**, **ReachabilitySwift**, **Kingfisher**, **Cache**.

The optional pods are not used, deliberately:

| Pod | Why it is not included |
| --- | --- |
| Loaf | Unmaintained since 2020. The app needs a banner that can stay pinned while offline and render as Liquid Glass, so a small `StatusBannerView` (XIB) with `BannerPresenter` does the job. |
| KMNavigationBarTransition | Smooths transitions between differently styled navigation bars by swizzling UIKit. Both screens draw their own headers as in the design, so there is no bar transition to fix. |
| FTLinearActivityIndicator | Recreates the status bar activity indicator on notched iPhones. The design calls for none; loading is shown with skeleton cards and pull-to-refresh. |
| AlamofireNetworkActivityIndicator | Drives `isNetworkActivityIndicatorVisible`, which has had no effect since iOS 13. |

No other pods were added.

## Assumptions and decisions

- **Figma frame size.** The design is 393 pt wide. Margins, paddings and sizes are taken from it as-is; cards stretch with the screen and images keep the design's aspect ratio.
- **Android status bar.** The frames include an Android status bar. Vertical offsets are measured from its bottom edge and applied below the iOS safe area.
- **Title box.** The design gives the two-line card title a 45 pt box with 24 pt line height (48 pt of text). The label is 48 pt and the gap below is reduced by 3 pt, so every other measurement matches.
- **Light appearance only.** The design defines no dark variant, so the app is fixed to the light appearance instead of shipping an unreviewed dark theme.
- **Opening the full article.** The design has no control for this, but the brief requires it. A floating button reusing the design's "Read More" style was added to the detail screen.
- **Byline.** The design shows only the article's age on the detail screen. The author or publisher is appended to that line so the `null` author case is visibly handled.
- **Search and layout toggle.** The header icons are functional: the grid icon switches to the two-column layout from the design, and search filters the loaded list by title, description, author and source. The search field itself is not in the design.
- **Favourites.** The heart on the detail screen toggles between the two icons in the design and is stored locally. There is no favourites list because the design has none.
- **Body text.** The feed's `content` ends in a "[+3029 …" truncation marker followed by filler text. The marker is removed; the rest is shown unchanged.
- **Split view assembly.** Each screen is laid out in its own storyboard. `AppRouter` assembles the split view in code so the same scenes can be injected and reused in both columns.
- **Custom transition.** The iOS 18 zoom transition is used for the push on iPhone, aligned to the detail image. It is interruptible and provides the interactive dismissal for free.
- **Cache pod version.** `Cache` 6.0.0 is the latest version published to CocoaPods trunk.
- **Fonts.** Roboto, Roboto Condensed and Montserrat are bundled (Latin subset) under the Apache 2.0 and SIL Open Font licences.

## With more time

- UI tests and snapshot tests for both screens at several Dynamic Type sizes and on iPad
- A favourites list, and a shared element transition for the iPad column
- Pagination and background refresh, if the API supported them
- Localisation (all copy is currently English and inline)
- A dark appearance agreed with design
- Full VoiceOver audit, including custom rotor actions on cards
- CI running the build and tests on every push
