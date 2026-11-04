# Work Report — April 16, 2026

## Objective
Implement post creation & edit history timing with audit trails in the feed module.

## Changes

### Feed Model (`lib/models/src/feed_model.dart`)
- Fixed `createdAt` timestamp serialization (was degrading to "now" on reload)
- Added `updatedAt` field for last edit time
- Added timestamp normalization helpers for Timestamp/String/int formats
- Added `copyWith()` method for immutable updates
- Created `FeedHistoryModel` class for audit trail records (timestamp, userId, action, content)

### Feed Service (`lib/services/firebase/src/feed_service.dart`)
- Added `_addFeedHistory()` to write history subcollection on create/edit
- `createFeed()` now writes history with action="Created"
- `editFeed()` now writes history with action="Edited" and persists `updatedAt`
- History stored in `feeds/{feedId}/history/` subcollection

### Feed UI (`lib/views/screens/feed/src/listing/feed_listing.dart`)
- New `_buildTimeLabel()` shows "Posted Xm/h/d ago" or "Posted Xm/h/d ago · Edited Xm/h/d ago"
- Displays edit status at a glance

## Verification
✓ All 3 files pass analyzer checks  
✓ Code formatted with `dart format`  
✓ Windows app builds & launches successfully  
✓ Timestamps persist across reloads

## Files Modified
- `lib/models/src/feed_model.dart`
- `lib/services/firebase/src/feed_service.dart`
- `lib/views/screens/feed/src/listing/feed_listing.dart`

## Status
✓ Complete and deployed  
✓ Ready for testing
