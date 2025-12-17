# ShizList

> **"Share the stuff you want"**

A collaborative wish list app built with Flutter and Supabase, enabling multi-user list creation, anonymous claiming, group messaging, and Amazon affiliate integration.

## 🎯 Features

- **Multiple Wish Lists** - Create and manage unlimited lists with categories
- **Item Categories** - Stuff, Events, Trips, Homemade, Meals, Other
- **Anonymous Claiming** - Gifters can claim items without the list owner knowing
- **Claim Expiration** - Optional expiry dates for claims
- **Group Messaging** - Coordinate gift-giving with other gifters
- **Sharing Options** - Public/Private lists with unique URLs and QR codes
- **Amazon Integration** - Search and add products with affiliate links

## 🛠 Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **State Management:** Riverpod
- **Navigation:** GoRouter

## 🎨 Design System

### Colors
- **Primary (ShizList Teal):** `#009688`
- **Background:** `#FAFAFA`
- **Text:** `#212121`
- **Error/Alert:** `#D32F2F`

### Typography
- **Headlines:** Montserrat (Bold 700 / Black 900)
- **Body/UI:** Source Sans Pro (Regular 400 / Semi-Bold 600)

## 📱 Navigation

- **Bottom Tab Bar:** My Lists, Invite, Contacts, Messages, Share
- **Floating Action Button:** Quick add items
- **Side Drawer:** Profile, Settings, Logout

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK
- Supabase account

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/shizlist.git
cd shizlist
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Supabase:
   - Create a new Supabase project
   - Update `lib/core/constants/supabase_config.dart` with your credentials:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

4. Set up the database:
   - Run the SQL migrations in `supabase/migrations/` (to be created)
   - Enable Row Level Security on all tables

5. Run the app:
```bash
flutter run
```

## 📂 Project Structure

```
lib/
├── core/
│   ├── theme/          # Colors, Typography, Theme
│   └── constants/      # App constants, Supabase config
├── features/
│   ├── auth/           # Login, Signup screens
│   ├── lists/          # List management
│   ├── items/          # Item management
│   ├── contacts/       # Contact management
│   ├── messages/       # Group messaging
│   └── share/          # Sharing functionality
├── models/             # Data models
├── services/           # API services
├── routing/            # Navigation
├── widgets/            # Reusable widgets
└── main.dart           # App entry point
```

## 📋 Database Schema

### Core Tables
- `users` - User profiles
- `lists` - Wish lists
- `list_items` - Items in lists
- `claims` - Item claims by gifters
- `list_shares` - List sharing permissions
- `messages` - Group messages
- `conversations` - Message threads
- `contacts` - User contacts

### Key Features
- Dual ID system (internal `id` + public `uid`)
- Row Level Security (RLS) enforced
- Real-time subscriptions for updates

## 🔧 Configuration

### Amazon PA-API (Optional)
To enable Amazon product search and affiliate links:
1. Register for Amazon Associates
2. Apply for Product Advertising API access
3. Configure API credentials in your Supabase Edge Functions

## 📄 License

This project is proprietary. All rights reserved.

## 🤝 Contributing

This is a private project. Contact the repository owner for contribution guidelines.
