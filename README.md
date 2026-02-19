# Commvault Cloud SaaS Dashboard - iOS App

An iOS application for monitoring and managing Commvault Cloud (SaaS/Metallic) backup environments with local RAG-powered Q&A, competitive intelligence tracking, and proactive notifications.

## Features

### Dashboard
- Real-time health overview (Good/Info/Warning/Critical status)
- Job summary for last 24 hours with success/failure/running counts
- SLA compliance percentage
- Storage utilization with visual gauge
- Alert summary with critical alert count
- Anomalous entity detection (ransomware/insider threat indicators)
- Morning digest card with overnight summary

### Job Management
- Full job listing with status filters (All, Failed, Running, Completed, Pending, Killed)
- Job detail view with client info, timing, progress, and failure reasons
- Job actions: Resubmit failed jobs directly from the app
- Real-time progress tracking for running jobs

### Ask Commvault (Local RAG)
- On-device question answering about Commvault APIs and features
- TF-IDF scoring with NLP tokenization and lemmatization via Apple NaturalLanguage framework
- Embedded knowledge base covering: Authentication, Dashboard, Jobs, Alerts, SaaS/Metallic, Storage, Security, Workflows
- Relevant API endpoint suggestions with each answer
- Confidence scoring and source attribution

### Notifications
- **Job Failure Alerts** (opt-in): Immediate notification when backup jobs fail, with configurable polling interval
- **Morning Digest** (opt-in): Scheduled overnight summary delivered at your chosen time - includes job counts, failures, critical alerts, and SLA compliance
- **Cohesity Tracking** (opt-in): Nightly scan at 10 PM for new Cohesity features with notification of changes
- iOS Background Task support for all notification types

### Competitive Intelligence
- Monitors Cohesity Data Protect "What's New" page for feature updates
- Categorizes features: Microsoft 365, AWS, Azure, Infrastructure, Security, Databases, Reporting
- Highlights new features detected since last scan
- Tracks feature availability status (GA, Private Preview, Controlled Availability, Early Access)
- Persistent storage of feature history for comparison

### Security
- API keys stored exclusively in iOS Keychain with hardware encryption
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection level
- Keys never leave the device - all API calls direct to your ring
- Support for both API token and username/password authentication

## Architecture

```
CommvaultSaaS/
├── App/
│   ├── CommvaultSaaSApp.swift          # App entry point, appearance config
│   ├── RootView.swift                  # Auth-gated root navigation
│   └── MainTabView.swift               # Tab bar (Dashboard, Jobs, Ask CV, Intel, Settings)
├── Models/
│   └── CommvaultModels.swift            # All Codable API models
├── Services/
│   ├── CommvaultAPIService.swift        # Full REST API client (actor-based)
│   ├── AuthenticationManager.swift      # Auth state, Keychain integration
│   ├── RAGEngine.swift                  # Local RAG with NLP
│   ├── NotificationManager.swift        # Push notification management
│   ├── CohesityMonitorService.swift     # Competitive intelligence scraper
│   ├── BackgroundJobMonitor.swift       # iOS BGTaskScheduler handlers
│   └── SettingsManager.swift            # UserDefaults preferences
├── Views/
│   ├── Authentication/LoginView.swift   # Login with ring + API key/credentials
│   ├── Dashboard/DashboardView.swift    # Health dashboard with cards
│   ├── Jobs/JobsView.swift              # Job list, filters, detail sheet
│   ├── RAG/RAGChatView.swift            # Chat interface for API Q&A
│   ├── Competitive/CompetitiveView.swift # Cohesity feature tracker
│   └── Settings/SettingsView.swift      # Notification prefs, connection info
├── Utilities/
│   ├── CommvaultColors.swift            # Brand color palette & gradients
│   └── KeychainManager.swift            # Secure Keychain CRUD
├── RAGData/
│   └── CommvaultAPIKnowledgeBase.json   # Embedded API documentation
└── Resources/
    └── Assets.xcassets/                 # App icon, accent color
```

## Commvault API Endpoints Used

| Category | Endpoint | Method |
|----------|----------|--------|
| Auth | `/Login` | POST |
| Auth | `/ApiToken` | GET/POST/DELETE |
| Dashboard | `/CommServ/CommCellInfo` | GET |
| Dashboard | `/DashboardTile/HealthOverview` | GET |
| Dashboard | `/DashboardTile/SLA` | GET |
| Dashboard | `/DashboardTile/StorageSpace` | GET |
| Dashboard | `/DashboardTile/AnomalousEntities` | GET |
| Dashboard | `/DashboardTile/JobsInLast24Hours` | GET |
| Jobs | `/Job` | GET |
| Jobs | `/Job/{id}` | GET |
| Jobs | `/Job/{id}/FailedItems` | GET |
| Jobs | `/Job/{id}/Action/Resubmit` | POST |
| Jobs | `/Job/{id}/Action/Kill` | POST |
| Jobs | `/Job/{id}/Action/Suspend` | POST |
| Jobs | `/Job/{id}/Action/Resume` | POST |
| Alerts | `/AlertRule/Triggered` | GET |
| Alerts | `/AlertRule` | GET |
| Usage | `/Metallic/Usage/Summary` | GET |
| Usage | `/Metallic/Usage/Details` | GET |

## Ring Configuration

Commvault SaaS customers are assigned to rings with the format:
- `M` followed by 2-3 digits (e.g., `M88`, `M123`)
- Full endpoint: `https://M88.metallic.io/commandcenter/api/`

The app validates ring format on the login screen and constructs all API URLs accordingly.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Active Commvault Cloud (Metallic) subscription with API access

## Color Scheme

Based on Commvault's brand guidelines:
- **Deep Purple**: `#1A054F` (primary backgrounds)
- **Medium Purple**: `#783D7A` (accents, buttons)
- **Rose Pink**: `#CB9298` (tab highlights)
- **Hot Pink**: `#F495B1` (accent gradient)
- **Peach**: `#F0C4A3` (gradient elements)
- **Navy Blue**: `#2A3176` (card gradients)

## Data Sources

- **Commvault REST API**: https://api.commvault.com (SP42 latest)
- **Commvault Docs**: https://documentation.commvault.com (SaaS view)
- **Cohesity What's New**: https://docs.cohesity.com/baas/data-protect/whatsnew.htm
