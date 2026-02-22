# Commvault Cloud SaaS Dashboard - iOS App

An iOS application for monitoring Commvault Cloud (Metallic) infrastructure health and user activity. Connects directly to your Metallic ring via the Commvault REST API to surface server status, update readiness, and user login metrics at a glance.

## Current Features

### Home Screen
- Central navigation hub with cards for each monitoring area
- Displays connected ring host and status
- Quick access to Settings via toolbar

### Infrastructure Health
- Fetches all servers from `/V4/Servers` with full property detail
- **Infrastructure / Non-Infrastructure toggle** — segmented picker to split servers by role
- Filters out servers where `updateStatus` or `networkReadiness` is `NOT_APPLICABLE`
- Groups servers into three health statuses:
  - **Offline** (red) — `networkReadiness == "OFFLINE"`
  - **Needs Update** (amber) — online but `updateStatus == "NEEDS_UPDATE"`
  - **Online** (green) — online and up to date
- Tap any status card to drill into the server list
- Server details: display name, version, install date, client roles, OS info
- Offline servers show last online time and when they went offline

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

### Dynamic Ring Selection
- On first boot, enter your ring number (e.g., 036, 088) — always prefixed with M
- All API URLs dynamically use your selected ring (`m{NNN}.metallic.io`)
- Ring stored in Keychain and restored on relaunch
- Reset from Settings to switch rings

### Token-Based Authentication
- Authenticate with Commvault API access token + refresh token (no username/password)
- Token validation on setup by calling `/v4/user`
- Automatic token renewal on app launch and when idle > 2 hours
- Renewed tokens (both access and refresh) replace originals in Keychain
- Automatic retry on 401 — renews token and retries the failed request once
- Tokens encrypted and stored in iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)

### Settings
- View connected ring and API endpoint
- Token status indicator (Valid, Renewed, Expired, Failed) with color coding
- Last renewal timestamp
- Manual "Renew Token Now" button
- Update tokens without resetting ring
- Reset Connection (clears all data, returns to setup)
- Log Out (clears tokens, keeps ring)
- Security info display (Keychain storage, TLS details)

### Pull-to-Refresh
- Pull down on any data view to reload
- Toolbar refresh button with token renewal

## Architecture

```
CommvaultSaaS/
├── App/
│   ├── CommvaultSaaSApp.swift          # @main entry point, nav bar appearance
│   └── RootView.swift                  # Auth gate: LoginView or HomeView
├── Models/
│   └── CommvaultModels.swift           # Codable models (CommvaultUser, CommvaultServer, etc.)
├── Services/
│   ├── AuthenticationManager.swift     # Token lifecycle, ring config, Keychain integration
│   └── CommvaultAPIService.swift       # Actor-based REST client with dynamic ring URL
├── Views/
│   ├── Authentication/
│   │   └── LoginView.swift             # Ring number + token input with validation
│   ├── Home/
│   │   └── HomeView.swift              # Main navigation hub with feature cards
│   ├── Dashboard/
│   │   └── DashboardView.swift         # User dashboard, StatCard, UserListView, ViewModel
│   ├── Infrastructure/
│   │   ├── InfrastructureHealthView.swift  # Server health overview with infra/non-infra tabs
│   │   └── ServerListView.swift            # Server list detail with status grouping
│   └── Settings/
│       └── SettingsView.swift          # Settings, token management, UpdateTokensSheet
├── Utilities/
│   ├── CommvaultColors.swift           # Brand color palette & gradients
│   └── KeychainManager.swift           # iOS Keychain CRUD wrapper
└── Resources/
    ├── Assets.xcassets/                # App icon, accent color
    └── Info.plist                      # ATS config, background task IDs
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `actor CommvaultAPIService` | Thread-safe concurrent API access without manual locking |
| `@MainActor` ViewModels | All UI state updates guaranteed on main thread |
| `TimeInterval?` for timestamps | Custom decoder handles Int, Double, or String from API |
| No `?limit=` on `/v4/user` | The Commvault API omits `lastLoggedIn` from responses when limit is specified |
| Token-only auth (no password) | Aligns with Commvault API token model; more secure for mobile |
| Keychain with `WhenUnlockedThisDeviceOnly` | Strongest iOS protection — hardware-encrypted, device-tied, no iCloud sync |
| Dynamic ring in `baseURL` | Computed property rebuilds URL from stored ring number on every request |
| 401 auto-retry | ViewModels catch `.unauthorized`, call `handleUnauthorized()`, retry once with fresh token |

## Data Flow

```
App Launch
  │
  ├─ Keychain has tokens? ──yes──▶ Configure API ──▶ Renew Token ──▶ HomeView
  │                                                                     │
  └─ No tokens ──▶ LoginView                               ┌───────────┼───────────┐
                      │                                     ▼           ▼           ▼
                      ▼                              Infrastructure   User       Settings
                 setupTokens()                          Health     Dashboard
                      │                                     │           │
                      ▼                                     ▼           ▼
              Validate via GET /v4/user             GET /V4/Servers  GET /v4/user
                      │                                     │           │
                      ▼                                     ▼           ▼
              Save ring + tokens to Keychain        Group by status  Compute stats
                      │                             Offline/Update   Inactive/Never
                      ▼                             /Online
              isAuthenticated = true
                      │
                      └────────▶ HomeView
```

## API Integration

### Ring Configuration

Commvault SaaS customers are assigned to rings:
- Format: `m` + 2-3 digits (e.g., `m036`, `m088`)
- Base URL pattern: `https://m{NNN}.metallic.io/commandcenter/api`

The ring is selected on first boot via the login screen and stored in Keychain. It can be changed by resetting the connection from Settings.

### Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v4/user` | GET | Fetch all users with login timestamps |
| `/V4/Servers` | GET | Fetch all servers with health, update status, and connectivity |
| `/V4/AccessToken/Renew` | POST | Refresh expired access tokens |

### Authentication Headers

```
Authtoken: <access-token>
Accept: application/json
```

### Example Response Formats

**Users** (`/v4/user`):
```json
{
  "numberOfUsers": 6,
  "users": [
    {
      "id": 12345,
      "name": "domain\\jsmith",
      "fullName": "John Smith",
      "email": "jsmith@example.com",
      "lastLoggedIn": 1740000000,
      "enabled": true,
      "lockInfo": { "isLocked": false },
      "numberOfLaptops": 0,
      "company": { "id": 1000, "name": "example-co" }
    }
  ]
}
```

`lastLoggedIn` is a Unix timestamp (seconds since epoch). A value of `0` means the user has never logged in.

**Servers** (`/V4/Servers`):
```json
{
  "totalServers": 37,
  "servers": [
    {
      "id": 5678,
      "name": "backup-server-01",
      "displayName": "Backup Server 01",
      "hostName": "backup-server-01.example.com",
      "installTime": 1690000000,
      "version": "11.38.18",
      "updateStatus": "UP_TO_DATE",
      "networkReadiness": "ONLINE",
      "isInfrastructure": true,
      "clientRoles": ["MediaAgent", "Virtual Server Agent"],
      "additionalProperties": {
        "clientStatus": "READY",
        "lastOnlineTime": 1740000000,
        "osInfo": "Microsoft Windows Server 2022"
      }
    }
  ]
}
```

## Color Scheme

Based on Commvault brand guidelines:

| Color | Hex | Usage |
|-------|-----|-------|
| Deep Purple | `#1A054F` | Navigation bar, primary backgrounds |
| Medium Purple | `#783D7A` | Accent, user avatars |
| Navy Blue | `#2A3176` | Card gradients |
| Hot Pink | `#F495B1` | Accent gradient |
| Peach | `#F0C4A3` | Login background gradient |
| Green | `#34C759` | Success / online / enabled |
| Orange | `#FF9500` | Warning / needs update / inactive |
| Red | `#FF3B30` | Critical / offline / never logged in |

### Infrastructure Health Card Gradients

- **Offline**: Dark Red → Red (`#7B1E1E` → `#C93030`)
- **Needs Update**: Dark Gold → Gold (`#5C4B1E` → `#B8860B`)
- **Online**: Dark Green → Green (`#1E5C2E` → `#2D8B4E`)

### User Dashboard Card Gradients

- **Total Users**: Deep Purple → Navy Blue
- **Inactive 6+ Months**: Dark Gold → Gold (`#5C4B1E` → `#B8860B`)
- **Inactive 1+ Year**: Brown → Orange (`#7B4B1E` → `#C97A1E`)
- **Never Logged In**: Dark Red → Red (`#7B1E1E` → `#C93030`)

## Security

- **No arbitrary network access** — `NSAllowsArbitraryLoads` is `false`
- **Allowed domains**: `*.metallic.io`, `*.cohesity.com` (TLS 1.2+, forward secrecy required)
- **Keychain storage**: `kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **No credentials in code** — all secrets stored in Keychain at runtime
- **Token auto-renewal** — refresh token used to renew access token on launch and after 2 hours of inactivity

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+
- Active Commvault Cloud (Metallic) subscription with API token access

## Getting Started

1. Open `CommvaultSaaS.xcodeproj` in Xcode
2. Build and run on a simulator or device (iOS 17+)
3. On the login screen, enter your **Ring Number** (e.g., 036)
4. Paste your **Access Token** and **Refresh Token**
5. Tap **Connect** — the app validates by fetching users from your ring
6. Once authenticated, the home screen loads with navigation to Infrastructure Health and User Dashboard

### Obtaining Tokens

1. Find your ring number from your Commvault Cloud URL (e.g., M036 from `m036.metallic.io`)
2. Log in to your Commvault Command Center
3. Navigate to **Manage > Security > API Tokens**
4. Create a new API token with appropriate permissions
5. Copy the access token and refresh token into the app

## Data Sources

- **Commvault REST API**: https://api.commvault.com
- **Commvault Docs**: https://documentation.commvault.com
