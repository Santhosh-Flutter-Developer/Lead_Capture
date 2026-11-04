# Permission fixes

1. "Access Denied" flash on page open
   - Sub Department, Designation, Role, Department listings checked `canView` before permissions had loaded -> added `_permissionsLoaded` gate (shows loader first).
   - Contact and Company listings had no view check at all -> added loaded gate + canView check.
   - All permission loaders now guard `setState` with `if (!mounted) return;`.

2. Hide (not disable) buttons without permission
   - Add / Edit / Delete buttons in 13 listings (Role, Designation, Department, Sub Department, Lead Category/Source/Priority/Status, Deal Status, Contact, Company, Projects, Tasks, Tickets) are now removed when the role lacks that permission.
   - Unused `_disabledButton` helpers removed.
   - Menu/sidebar already hide pages without `canView` (unchanged).
