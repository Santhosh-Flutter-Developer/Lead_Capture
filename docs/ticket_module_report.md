# Ticket Module Documentation

---

## TABLE OF CONTENTS

1. Project Overview  3
2. Prerequisites  3
3. Project Setup  3
4. Dependencies  4
5. Project Structure  5
6. Source Code  7
7. Enhanced Features  15
8. Platform-Specific Configuration  16
9. Running the Application  17
10. Building for Production  17
11. Troubleshooting  18

---

## 1. Project Overview

The Ticket Module is a comprehensive customer support ticket management system built as part of the LeadCapture Flutter app. It provides a complete solution for managing support tickets, including:

- Ticket creation with rich metadata (client info, priority, status, category)
- Ticket editing with permission checks
- Ticket comments and history tracking
- Notifications and reminders
- Attachments support
- Permission-based access control (canView, canCreate, canEdit, canDelete)
- Record-level ownership checks for edit/delete actions
- Ticket number auto-incrementing
- Restore from trash functionality

The module is robust and well-structured, with proper separation of concerns between models, services, and UI.

### 1.1 Scope
This documentation covers the Ticket Module in the LeadCapture Flutter app, focusing on:
- Who can create tickets
- Who can edit tickets
- How ticket history is maintained
- How comments are managed
- How ticket statuses and priorities work
- How attachments, notifications, and reminders are handled
- Missing or incomplete behaviors

### 1.2 Primary References
- [lib/services/firebase/src/ticket_service.dart](../lib/services/firebase/src/ticket_service.dart)
- [lib/views/screens/tickets/listing/tickets_listing.dart](../lib/views/screens/tickets/listing/tickets_listing.dart)
- [lib/views/screens/tickets/form/ticket_create.dart](../lib/views/screens/tickets/form/ticket_create.dart)
- [lib/views/screens/tickets/form/ticket_view.dart](../lib/views/screens/tickets/form/ticket_view.dart)
- [lib/views/screens/tickets/form/ticket_edit.dart](../lib/views/screens/tickets/form/ticket_edit.dart)
- [lib/models/src/customer_ticket_model.dart](../lib/models/src/customer_ticket_model.dart)
- [lib/constants/src/enum.dart](../lib/constants/src/enum.dart)

---

## 2. Prerequisites

To work with the Ticket Module, ensure you have the following installed:

- Flutter SDK: ^3.9.2
- Dart SDK: Compatible with Flutter 3.9.2
- Firebase CLI (for Firebase services)
- Android Studio / VS Code (for development)
- Git (for version control)

---

## 3. Project Setup

### 3.1 Clone the Repository
```bash
git clone <repository-url>
cd leadcapture_crm
```

### 3.2 Install Dependencies
```bash
flutter pub get
```

### 3.3 Firebase Configuration
1. Ensure Firebase is configured for the project
2. Verify `firebase_options.dart` is present in `lib/`
3. Check `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in their respective directories

### 3.4 Run the App
```bash
flutter run
```

---

## 4. Dependencies

The Ticket Module relies on the following key dependencies from `pubspec.yaml`:

### 4.1 Core Flutter Dependencies
- `flutter`: SDK for Flutter
- `cupertino_icons`: ^1.0.8

### 4.2 Firebase Dependencies
- `firebase_core`: ^4.2.1 - Core Firebase functionality
- `cloud_firestore`: ^6.1.0 - Firestore database
- `firebase_storage`: ^13.0.4 - File storage
- `firebase_messaging`: ^16.0.4 - Push notifications

### 4.3 State Management
- `provider`: ^6.1.5+1 - State management
- `flutter_bloc`: ^9.1.1 - BLoC pattern
- `equatable`: ^2.0.7 - Value equality

### 4.4 UI & Utilities
- `iconsax`: ^0.0.8 - Icon library
- `font_awesome_flutter`: ^10.12.0 - More icons
- `flutter_svg`: ^2.2.2 - SVG support
- `cached_network_image`: ^3.4.1 - Image caching
- `shimmer`: ^3.0.0 - Loading effects
- `another_flushbar`: ^1.12.32 - Snackbars/toast messages
- `file_picker`: ^10.3.3 - File selection
- `path`: ^1.9.1 - Path manipulation
- `mime`: ^2.0.0 - MIME type detection

### 4.5 Other Utilities
- `uuid`: ^4.5.2 - UUID generation
- `intl`: ^0.20.2 - Internationalization
- `shared_preferences`: ^2.5.3 - Local storage
- `hive_flutter`: ^1.1.0 - NoSQL local storage

---

## 5. Project Structure

```
leadcapture_crm/
├── android/                    # Android platform files
├── assets/                     # App assets (images, fonts, etc.)
│   ├── audio/
│   ├── fonts/
│   ├── images/
│   ├── svg/
│   └── templates/
├── docs/                       # Documentation
│   └── ticket_module_report.md  # This file
├── facesdk_plugin/             # Custom face detection plugin
├── functions/                  # Firebase Cloud Functions
├── ios/                        # iOS platform files
└── lib/                        # Main app source code
    ├── app/                    # App initialization
    ├── constants/              # Constants and enums
    │   └── src/
    │       └── enum.dart       # Ticket enums
    ├── models/                 # Data models
    │   └── src/
    │       └── customer_ticket_model.dart
    ├── services/               # Business logic
    │   ├── database/
    │   ├── firebase/
    │   │   └── src/
    │   │       └── ticket_service.dart
    │   └── others/
    ├── theme/                  # App theming
    ├── utils/                  # Utilities
    ├── views/                  # UI screens
    │   └── screens/
    │       └── tickets/
    │           ├── form/
    │           │   ├── ticket_create.dart
    │           │   ├── ticket_view.dart
    │           │   └── ticket_edit.dart
    │           └── listing/
    │               ├── tickets_listing.dart
    │               └── bloc/
    │                   ├── tickets_bloc.dart
    │                   ├── tickets_event.dart
    │                   └── tickets_state.dart
    ├── firebase_options.dart
    └── main.dart
```

### 5.1 Key Ticket Module Files

| File | Purpose |
|------|---------|
| `lib/models/src/customer_ticket_model.dart` | Ticket data model including comments and history |
| `lib/constants/src/enum.dart` | Ticket enums (status, priority, category, etc.) |
| `lib/services/firebase/src/ticket_service.dart` | Ticket business logic and Firebase operations |
| `lib/views/screens/tickets/listing/tickets_listing.dart` | Ticket listing screen |
| `lib/views/screens/tickets/form/ticket_create.dart` | Ticket creation screen |
| `lib/views/screens/tickets/form/ticket_view.dart` | Ticket detail view screen |
| `lib/views/screens/tickets/form/ticket_edit.dart` | Ticket edit screen |

---

## 6. Source Code

### 6.1 Data Model

#### 6.1.1 CustomerTicketModel
The main ticket model that stores all ticket information.

**Location**: `lib/models/src/customer_ticket_model.dart`

**Fields**:
- `uid`: Unique ticket ID (UUID)
- `ticketNumber`: Auto-incrementing ticket number
- `clientName`: Client name
- `clientCompanyName`: Client company name (optional)
- `modeOfContact`: How the client contacted (enum)
- `ticketTitle`: Ticket title
- `ticketDescription`: Ticket description
- `assignTo`: List of user IDs assigned to the ticket
- `participants`: List of user IDs participating
- `observers`: List of user IDs observing
- `createdBy`: List of user IDs who created the ticket
- `attachments`: List of `FileModel` attachments
- `priorityLevel`: Ticket priority (enum)
- `deadline`: Deadline datetime (optional)
- `reminder`: Reminder datetime (optional)
- `category`: Ticket category (enum)
- `status`: Ticket status (enum)
- `comments`: List of `TicketCommentModel` (stored in subcollection)
- `history`: List of `TicketHistoryModel` (stored in subcollection)
- `ticketCreatedBy`: `UserDataModel` of the creator
- `createdAt`: Creation datetime
- `updatedAt`: Last update datetime
- `project`: Project UID (optional)
- `task`: Task UID (optional)

#### 6.1.2 TicketCommentModel
Model for ticket comments.

**Fields**:
- `userId`: Who commented
- `comment`: The comment text
- `timestamp`: When the comment was posted

#### 6.1.3 TicketHistoryModel
Model for ticket history entries.

**Fields**:
- `timestamp`: When the change happened
- `userId`: Who made the change
- `updateDisposition`: Type of update ("Ticket Created", "Ticket Updated")
- `update`: Optional additional details

### 6.2 Enums

#### 6.2.1 TicketStatus
Available ticket statuses:
- `open`: Open
- `assigned`: Assigned
- `inProgress`: In Progress
- `onHold`: On Hold
- `pendingCustomerResponse`: Pending Customer Response
- `resolved`: Resolved
- `closed`: Closed

**Location**: `lib/constants/src/enum.dart:101`

#### 6.2.2 TicketPriority
Available ticket priorities:
- `low`: Low
- `medium`: Medium (default)
- `high`: High
- `urgent`: Urgent

**Location**: `lib/constants/src/enum.dart:132`

#### 6.2.3 TicketCategory
Available ticket categories:
- `bugReport`: Bug Report
- `technicalSupport`: Technical Support (default)
- `changeRequest`: Change Request
- `enhancementRequest`: Enhancement Request
- `applicationIssue`: Application Issue
- `serverIssue`: Server Issue
- `databaseIssue`: Database Issue
- `networkIssue`: Network Issue

**Location**: `lib/constants/src/enum.dart:67`

#### 6.2.4 TicketModeOfContact
Available modes of contact:
- `whatsApp`: WhatsApp
- `mail`: Mail
- `phone`: Phone (default)
- `visit`: Visit

**Location**: `lib/constants/src/enum.dart:149`

### 6.3 Service Layer

#### 6.3.1 TicketService
Service class that handles all ticket-related operations.

**Location**: `lib/services/firebase/src/ticket_service.dart`

**Methods**:

| Method | Purpose |
|--------|---------|
| `createTicket({required CustomerTicketModel ticket})` | Creates a new ticket with auto-generated ticket number, adds history entry, sends notifications |
| `updateTicket({required String uid, required CustomerTicketModel ticket})` | Updates an existing ticket, adds history entry, sends notifications |
| `deleteTicket({required String uid})` | Moves ticket to trash and deletes it |
| `restoreTicket(CustomerTicketModel ticket)` | Restores a deleted ticket |
| `getTicket({required String uid})` | Retrieves a single ticket |
| `getAllTickets()` | Retrieves all tickets |
| `getTicketHistory({required String ticketId})` | Retrieves ticket history |
| `streamTicketHistory({required String cid, required String ticketId})` | Real-time stream of ticket history |
| `getComments({required String ticketId})` | Retrieves ticket comments |
| `streamComments({required String cid, required String ticketId})` | Real-time stream of comments |
| `addComment({required String ticketId, required String comment})` | Adds a comment to a ticket |

### 6.4 UI Layer

#### 6.4.1 Ticket Listing Screen
**Location**: `lib/views/screens/tickets/listing/tickets_listing.dart`

Features:
- Paginated data table with tickets
- Search functionality
- Sorting by ticket number, title, status
- Bulk delete with undo
- Permission checks for view/create/edit/delete
- Responsive mobile/desktop layout

#### 6.4.2 Ticket Creation Screen
**Location**: `lib/views/screens/tickets/form/ticket_create.dart`

Features:
- Client details (name, company name)
- Mode of contact selection
- Ticket details (title, description)
- Assignment (assign to, participants, observers, created by)
- Project/task association
- Ticket settings (category, status, priority, deadline, reminder)
- File attachments
- Responsive mobile/desktop layout

#### 6.4.3 Ticket View Screen
**Location**: `lib/views/screens/tickets/form/ticket_view.dart`

Features:
- Complete ticket details display
- Comments section with real-time updates
- History section with timeline view
- Attachments download
- Assigned users, participants, observers display
- Responsive mobile/desktop layout

#### 6.4.4 Ticket Edit Screen
**Location**: `lib/views/screens/tickets/form/ticket_edit.dart`

Features:
- Same fields as creation screen
- Pre-populated with existing ticket data
- Supports adding/removing attachments
- Updates ticket history on save

### 6.5 Permission Model

The Ticket Module uses a comprehensive permission system:

- `canView`: View tickets
- `canCreate`: Create new tickets
- `canEdit`: Edit existing tickets (with ownership check)
- `canDelete`: Delete tickets (with ownership check)

**Ownership Check**:
- User is admin, OR
- User is the ticket creator (`ticketCreatedBy.uid`), OR
- User is in `createdBy` list (when `ticketCreatedBy` is empty)

---

## 7. Enhanced Features

### 7.1 Core Features
- ✅ Ticket creation with rich metadata
- ✅ Ticket editing with permission checks
- ✅ Ticket comments (view/add)
- ✅ Ticket history tracking
- ✅ Notifications on ticket creation/update
- ✅ Reminders for tickets
- ✅ File attachments
- ✅ Auto-incrementing ticket numbers
- ✅ Trash/restore functionality
- ✅ Permission-based access control
- ✅ Record-level ownership checks
- ✅ Responsive mobile/desktop UI
- ✅ Real-time updates with streams

### 7.2 Missing or Incomplete Features
- ❌ Comment editing/deletion
- ❌ Richer history tracking (field-level changes, before/after values)
- ❌ Ticket merging/duplicate handling
- ❌ Ticket templates
- ❌ Ticket reporting/analytics
- ❌ SLA tracking
- ❌ Knowledge base integration

---

## 8. Platform-Specific Configuration

### 8.1 Android
**Location**: `android/`

Key files:
- `android/app/build.gradle.kts` - App-level build configuration
- `android/app/src/main/AndroidManifest.xml` - App manifest
- `android/app/google-services.json` - Firebase configuration
- `android/gradle.properties` - Gradle properties

### 8.2 iOS
**Location**: `ios/`

Key files:
- `ios/Runner/Info.plist` - App configuration
- `ios/Runner/GoogleService-Info.plist` - Firebase configuration
- `ios/Podfile` - CocoaPods dependencies

### 8.3 Firebase
Firebase services used:
- **Firestore**: Store tickets, comments, history
- **Storage**: Store ticket attachments
- **Cloud Messaging**: Send notifications

Firestore structure:
```
users/{cid}/
  └── customerTickets/
      └── {ticketId}/
          ├── ticket document
          ├── ticketComments/ (subcollection)
          └── ticketHistory/ (subcollection)
```

Storage structure:
```
ticketAttachments/
  └── {fileId}/file
```

---

## 9. Running the Application

### 9.1 Development
```bash
# Run on Android
flutter run

# Run on iOS
flutter run -d ios

# Run on Windows
flutter run -d windows
```

### 9.2 Debugging
```bash
# Run with debug logging
flutter run --verbose

# Attach to running app
flutter attach
```

### 9.3 Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/ticket_test.dart
```

---

## 10. Building for Production

### 10.1 Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### 10.2 iOS
```bash
# Build for iOS
flutter build ios --release

# Archive for App Store
# Use Xcode to archive and upload
```

### 10.3 Windows
```bash
# Build Windows app
flutter build windows --release
```

---

## 11. Troubleshooting

### 11.1 Common Issues

**Issue**: Ticket not saving
- Check Firebase connectivity
- Verify Firestore permissions
- Check logs for errors

**Issue**: Attachments not uploading
- Verify Firebase Storage permissions
- Check file size limits
- Verify internet connection

**Issue**: Notifications not received
- Check Firebase Messaging setup
- Verify device token registration
- Check notification permissions

**Issue**: Permission denied
- Verify user has correct permissions
- Check ownership of the ticket
- Verify admin status if applicable

### 11.2 Logs
View logs for debugging:
```bash
flutter logs
```

---

## 12. Overall Assessment

The Ticket Module is well-implemented and feature-rich for basic ticket management.

### 12.1 Strengths
- Robust permission system with role-based access control
- Record-level ownership checks
- Comprehensive ticket metadata (status, priority, category, assignments)
- Notifications and reminders
- Attachment support
- Trash/restore functionality
- Clean separation of concerns between models, services, and UI
- Good use of subcollections for comments and history
- Responsive UI with both mobile and desktop layouts

### 12.2 Weaknesses
- Basic comment functionality (no edit/delete)
- Limited history tracking (only creation/update events, no field-level details)
- Missing advanced features (templates, merging, analytics)

---

## 13. Suggested Next Improvements

1. **Enhance Comment Functionality**
   - Add comment editing and deletion
   - Add comment reactions (like/heart/etc.)

2. **Enhance History Tracking**
   - Track field-level changes (before/after values)
   - Add specific history events for status changes, priority changes, assignment changes, etc.

3. **Add Ticket Templates**
   - Allow users to create and use ticket templates for common issues

4. **Add Ticket Merging**
   - Allow merging duplicate tickets

5. **Add Reporting/Analytics**
   - Create dashboards for ticket metrics

6. **Add SLA Tracking**
   - Track and enforce Service Level Agreements based on priority

7. **Add Knowledge Base Integration**
   - Link tickets to knowledge base articles for common solutions

---

## Appendix: Related Files

- [docs/screen_inventory.txt](./screen_inventory.txt)
- [docs/firebase_service_inventory.txt](./firebase_service_inventory.txt)
- [docs/model_inventory.txt](./model_inventory.txt)

---

**Report generated**: June 26, 2026
