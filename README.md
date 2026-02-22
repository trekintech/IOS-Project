# Commvault Cloud SaaS Dashboard - iOS App

An iOS application for monitoring Commvault Cloud (Metallic) user activity. Connects directly to your Metallic ring via the Commvault REST API to surface user login metrics — identifying inactive and never-logged-in accounts at a glance.

## Current Features

### User Dashboard
- Total user count from your Commvault environment
- **Inactive 6+ Months** — users whose last login exceeds 6 months
- **Inactive 1+ Year** — users whose last login exceeds 12 months
- **Never Logged In** — accounts with no recorded login activity (`lastLoggedIn: 0` or absent)
- Tap any stat card to drill into the filtered user list

### User List
- Searchable by name or email
- Displays full name, email, last login date, and enabled/disabled status
- Avatar initials derived from display name
- Last login shown as formatted date, or "Never logged in" in red

### Token-Based Authentication
- Authenticate with Commvault API access token + refresh token (no username/password)
- Token validation on setup by calling `/v4/user`
- Automatic token renewal when idle > 2 hours
- Tokens encrypted and stored in iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- Tokens never leave the device — all API calls go direct to your ring

### Pull-to-Refresh & Manual Refresh
- Pull down on the dashboard to reload data
- Toolbar refresh button with token renewal

## Architecture

```
CommvaultSaaS/
├── App/
│   ├── CommvaultSaaSApp.swift          # @main entry point, nav bar appearance
│   └── RootView.swift                  # Auth gate: LoginView or DashboardView
├── Models/
│   └── CommvaultModels.swift           # Codable models (CommvaultUser, UsersResponse, etc.)
├── Services/
│   ├── AuthenticationManager.swift     # Token lifecycle, Keychain integration
│   └── CommvaultAPIService.swift       # Actor-based REST client
├── Views/
│   ├── Authentication/
│   │   └── LoginView.swift             # Token input with validation
│   └── Dashboard/
│       └── DashboardView.swift         # Dashboard, StatCard, UserListView, ViewModel
├── Utilities/
│   ├── CommvaultColors.swift           # Brand color palette & gradients
│   └── KeychainManager.swift           # iOS Keychain CRUD wrapper
├── RAGData/
│   └── CommvaultAPIKnowledgeBase.json  # Embedded API docs (for future RAG feature)
└── Resources/
    ├── Assets.xcassets/                # App icon, accent color
    └── Info.plist                      # ATS config, background task IDs
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `actor CommvaultAPIService` | Thread-safe concurrent API access without manual locking |
| `@MainActor` ViewModels | All UI state updates guaranteed on main thread |
| `TimeInterval?` for `lastLoggedIn` | Custom decoder handles Int, Double, or String from API |
| No `?limit=` on `/v4/user` | The Commvault API omits `lastLoggedIn` from responses when limit is specified |
| Token-only auth (no password) | Aligns with Commvault API token model; more secure for mobile |
| Keychain with `WhenUnlockedThisDeviceOnly` | Strongest iOS protection — hardware-encrypted, device-tied, no iCloud sync |

## Data Flow

```
App Launch
  │
  ├─ Keychain has tokens? ──yes──▶ Configure API ──▶ DashboardView
  │                                                     │
  └─ No tokens ──▶ LoginView                            ▼
                      │                          loadUsers()
                      ▼                       GET /v4/user
                 setupTokens()                     │
                      │                            ▼
                      ▼                    Decode [CommvaultUser]
              Validate via GET /v4/user         │
                      │                         ▼
                      ▼                  Compute stats:
              Save to Keychain           - totalUsers
                      │                  - inactiveSixMonths
                      ▼                  - inactiveOneYear
              isAuthenticated = true      - neverLoggedIn
                      │                         │
                      └────────▶ DashboardView ◀┘
```

## API Integration

### Ring Configuration

Commvault SaaS customers are assigned to rings:
- Format: `m` + 2-3 digits (e.g., `m036`, `m088`)
- Base URL: `https://m036.metallic.io/commandcenter/api`

Currently hardcoded to `m036.metallic.io`. The ring endpoint is stored as a Keychain key for future configurability.

### Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v4/user` | GET | Fetch all users with login timestamps |
| `/V4/AccessToken/Renew` | POST | Refresh expired access tokens |

### Authentication Headers

```
Authtoken: <access-token>
Accept: application/json
```

### User Response Format

```json
{
  "numberOfUsers": 6,
  "users": [
    {
      "id": 10274,
      "name": "mtlc-man\\mandrews",
      "fullName": "Mike Andrews",
      "email": "mandrews@cvlt.mail.onmicrosoft.com",
      "lastLoggedIn": 1771694749,
      "enabled": true,
      "lockInfo": { "isLocked": false },
      "numberOfLaptops": 0,
      "company": { "id": 3525, "name": "mtlc-man" }
    }
  ]
}
```

`lastLoggedIn` is a Unix timestamp (seconds since epoch). A value of `0` means the user has never logged in.

## Color Scheme

Based on Commvault brand guidelines:

| Color | Hex | Usage |
|-------|-----|-------|
| Deep Purple | `#1A054F` | Navigation bar, primary backgrounds |
| Medium Purple | `#783D7A` | Accent, user avatars |
| Navy Blue | `#2A3176` | Card gradients |
| Hot Pink | `#F495B1` | Accent gradient |
| Peach | `#F0C4A3` | Login background gradient |
| Green | `#34C759` | Success / enabled status |
| Orange | `#FF9500` | Warning / inactive 1yr cards |
| Red | `#FF3B30` | Critical / never logged in cards |

### Dashboard Card Gradients

- **Total Users**: Deep Purple → Navy Blue
- **Inactive 6+ Months**: Dark Gold → Gold (`#5C4B1E` → `#B8860B`)
- **Inactive 1+ Year**: Brown → Orange (`#7B4B1E` → `#C97A1E`)
- **Never Logged In**: Dark Red → Red (`#7B1E1E` → `#C93030`)

## Security

- **No arbitrary network access** — `NSAllowsArbitraryLoads` is `false`
- **Allowed domains**: `*.metallic.io`, `*.cohesity.com` (TLS 1.2+, forward secrecy required)
- **Keychain storage**: `kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **No credentials in code** — all secrets stored in Keychain at runtime
- **Token auto-renewal** — refresh token used to renew access token after 2 hours of inactivity

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+
- Active Commvault Cloud (Metallic) subscription with API token access

## Getting Started

1. Open `CommvaultSaaS.xcodeproj` in Xcode
2. Build and run on a simulator or device (iOS 17+)
3. On the login screen, enter your Commvault **Access Token** and **Refresh Token**
4. Tap **Connect** — the app validates by fetching users from your ring
5. Once authenticated, the dashboard loads with user activity metrics

### Obtaining Tokens

1. Log in to your Commvault Command Center (e.g., `https://m036.metallic.io/commandcenter`)
2. Navigate to **Manage > Security > API Tokens**
3. Create a new API token with appropriate permissions
4. Copy the access token and refresh token into the app

## Planned Features

The following are scaffolded but not yet implemented:

- **Job Management** — Job listing, filtering, detail view, resubmit/kill actions
- **Ask Commvault (RAG)** — On-device Q&A using embedded API knowledge base with TF-IDF + NLP
- **Competitive Intelligence** — Monitor Cohesity feature releases
- **Push Notifications** — Job failure alerts, morning digest, Cohesity tracking
- **Settings** — Notification preferences, ring configuration, connection management
- **Background Tasks** — iOS BGTaskScheduler for periodic job/alert checking

## Data Sources

- **Commvault REST API**: https://api.commvault.com
- **Commvault Docs**: https://documentation.commvault.com
