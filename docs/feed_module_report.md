# Feed Module Analysis Report

## 1) Scope

This report analyzes the Feed module in the LeadCapture Flutter app, focusing on:
- Who can create posts
- Who can edit posts
- How edit history is maintained
- How the comment section is maintained
- How polls are managed
- How save and delete actions work for posts and comments
- Missing or incomplete behaviors

Primary references:
- [lib/services/firebase/src/feed_service.dart](lib/services/firebase/src/feed_service.dart)
- [lib/views/screens/feed/feed.dart](lib/views/screens/feed/feed.dart)
- [lib/views/screens/feed/src/listing/feed_listing.dart](lib/views/screens/feed/src/listing/feed_listing.dart)
- [lib/views/screens/feed/src/listing/comment_sheet.dart](lib/views/screens/feed/src/listing/comment_sheet.dart)
- [lib/views/screens/feed/src/form/feed_create.dart](lib/views/screens/feed/src/form/feed_create.dart)
- [lib/views/screens/feed/src/form/feed_edit.dart](lib/views/screens/feed/src/form/feed_edit.dart)
- [lib/models/src/feed_model.dart](lib/models/src/feed_model.dart)
- [lib/views/components/src/desktop_sidebar.dart](lib/views/components/src/desktop_sidebar.dart)

---

## 2) Executive Summary

The Feed module is implemented as a community-style post stream with:
- Post creation
- Post editing
- Media/file attachments
- Likes/reactions
- Commenting and replies
- Polls
- Comment reactions
- Refreshable grid listing

However, the module is lightweight from a governance perspective:
- There is no feed-specific permission layer in the feed code itself
- The module does not show record-level ownership checks for edit/delete actions
- Edit history is not maintained as a dedicated audit trail for feed post changes
- Comment deletion and comment editing are not implemented in the reviewed code
- The save/bookmark action appears only as an icon and is not wired to behavior
- Poll voting updates the vote totals, but the code does not clearly track a per-user vote history in a way that prevents repeat voting

---

## 3) Who Can Create Posts

### 3.1 Practical access

The Feed screen is exposed as a regular menu item in the desktop sidebar and is not wrapped in a feed-specific permission check in the reviewed code.

Reference:
- [desktop_sidebar.dart](lib/views/components/src/desktop_sidebar.dart#L214)

### 3.2 Post creation flow

The floating action button in the feed listing opens the create screen for anyone who can access the Feed page.

Reference:
- [feed_listing.dart](lib/views/screens/feed/src/listing/feed_listing.dart#L51)

### 3.3 Actual create behavior

Feed creation loads the current signed-in user and builds the post author metadata from either:
- Admin profile, or
- Employee profile

Then it writes a post to:
- users/{cid}/feed

It supports:
- Text content
- Media images
- Document attachments
- Tagged users
- Reactions list initialized empty
- Optional poll payload

Reference:
- [feed_create.dart](lib/views/screens/feed/src/form/feed_create.dart#L1)
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L1)

### 3.4 Conclusion

Any logged-in user who can reach the Feed screen can create a post. The module itself does not enforce a separate post-creation permission gate.

---

## 4) Who Can Edit Posts

### 4.1 UI exposure

Each post card shows a more/options icon that opens the edit form directly.

Reference:
- [feed_listing.dart](lib/views/screens/feed/src/listing/feed_listing.dart#L180)

### 4.2 Permission model

No feed-specific permission check was found in the feed listing or feed edit flow.
There is also no record-level ownership check in the reviewed UI path that restricts editing to post authors only.

### 4.3 Practical result

In the current implementation, post editing appears to be available to users who can open the feed card and access the edit sheet.

### 4.4 Conclusion

The module does not currently enforce a clear author-only edit rule in the reviewed code.

---

## 5) How Edit History Is Maintained

### 5.1 Post-level edit history

The feed service updates the post document through CommonService.update, which records a generic activity log entry such as:
- "<content> has been updated"

Reference:
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L163)

This means the app records an activity log for the update action, but it is not a dedicated post-edit history model inside the feed document.

### 5.2 What is not present

The reviewed code does not show:
- A dedicated feed edit-history subcollection
- A before/after field diff
- A versioned post revision timeline
- A visible edit-history tab in the feed UI

### 5.3 Conclusion

Edit history is maintained only in the sense of general activity logging through the shared service layer. It is not a rich post revision history system.

---

## 6) How the Comment Section Is Maintained

### 6.1 Comment data model

Comments are embedded in the feed model as a list of CommentModel objects.
Each comment stores:
- commentId
- authorId
- authorName
- authorAvatar
- content
- replyToCommentId
- reactions map
- createdAt

Reference:
- [feed_model.dart](lib/models/src/feed_model.dart#L154)

### 6.2 Comment UI behavior

The comment drawer supports:
- Viewing comments
- Adding a comment
- Replying to a comment
- Reacting to a comment
- Viewing nested reply preview

Reference:
- [comment_sheet.dart](lib/views/screens/feed/src/listing/comment_sheet.dart#L1)

### 6.3 How comments are saved

Comment addition updates the feed document directly:
- comments array receives the new CommentModel via arrayUnion
- commentsCount is incremented by 1

Reference:
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L149)

### 6.4 Comment reply support

Replying is represented by replyToCommentId in the comment model.
The UI shows the replied comment preview if replyToCommentId is present.

Reference:
- [comment_sheet.dart](lib/views/screens/feed/src/listing/comment_sheet.dart#L88)

### 6.5 Comment reactions

Comment reactions are stored as a map of emoji to user lists.
The UI supports:
- double tap to react
- long press actions for reply or reaction
- toggling a reaction on or off for the current user

Reference:
- [comment_sheet.dart](lib/views/screens/feed/src/listing/comment_sheet.dart#L104)
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L104)

### 6.6 What is missing

The reviewed code does not show:
- Comment delete
- Comment edit
- Comment moderation controls
- Comment audit trail
- Comment threading beyond one-level replies

### 6.7 Conclusion

The comment system is functional and supports replies and reactions, but it is append/update oriented rather than lifecycle complete.

---

## 7) How Polls Are Managed

### 7.1 Poll creation

The create screen allows users to enable a poll and enter:
- Poll question
- At least 2 options
- Up to 5 options

Reference:
- [feed_create.dart](lib/views/screens/feed/src/form/feed_create.dart#L1)

### 7.2 Poll editing

The edit screen preserves poll data when present and allows the user to revise it.
If a feed already contains a poll, the edit form preloads:
- question
- options

Reference:
- [feed_edit.dart](lib/views/screens/feed/src/form/feed_edit.dart#L1)

### 7.3 Poll data structure

PollModel stores:
- pollId
- question
- options

Each PollOption stores:
- optionId
- title
- votes

Reference:
- [feed_model.dart](lib/models/src/feed_model.dart#L146)

### 7.4 Voting behavior

The vote action increments the selected option’s vote count and writes the poll back to the feed document.
The Bloc then refreshes the feed list after voting.

Reference:
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L193)
- [feed_bloc.dart](lib/views/screens/feed/src/listing/bloc/feed_bloc.dart#L1)

### 7.5 Important limitation

The code reviewed does not show a per-user vote ledger, and the vote path only increments the counter.
That means the code does not clearly prevent repeated voting by the same user through a recorded vote history.

### 7.6 Conclusion

Polls are supported, but voting logic is basic and lacks strong anti-duplication or voter-tracking behavior in the reviewed implementation.

---

## 8) How Save, Delete, and Reactions Work

## 8.1 Save / bookmark post

The feed card shows a save/archive-style icon in the action bar.

Reference:
- [feed_listing.dart](lib/views/screens/feed/src/listing/feed_listing.dart#L244)

However, there is no onTap handler attached to that icon in the reviewed code.
That means save/bookmark is currently only visual and not functional in the inspected implementation.

### 8.2 Delete post

No post delete action was found in the feed card or feed detail UI.
The post edit screen is available, but the reviewed UI does not expose a delete post control.

### 8.3 Delete comments

No comment delete action was found in the comment sheet.
Comments can be posted and reacted to, but they are not removable from the reviewed UI flow.

### 8.4 Like / reaction behavior

Post-level likes are stored in feed.reactions.
The UI toggles a like state per current user.
The service updates the reactions array by adding or removing the current user entry.

Reference:
- [feed_service.dart](lib/services/firebase/src/feed_service.dart#L80)
- [feed_bloc.dart](lib/views/screens/feed/src/listing/bloc/feed_bloc.dart#L1)

### 8.5 Comment reactions

Comment reactions are stored separately in the comment.reactions map and can be toggled for each emoji.

Reference:
- [comment_sheet.dart](lib/views/screens/feed/src/listing/comment_sheet.dart#L104)

---

## 9) Feed Data Model Summary

FeedModel includes:
- author identity and avatar
- content text
- mediaImages
- attachments
- taggedUsers
- poll
- reactions
- commentsCount
- embedded comments list
- createdAt timestamp

Reference:
- [feed_model.dart](lib/models/src/feed_model.dart#L1)

This means the feed document is carrying both summary data and embedded social data in the same record.

---

## 10) Missing or Incomplete Features

### 10.1 Missing permission model

No feed-specific permission layer was found for:
- create post
- edit post
- delete post
- comment actions
- poll actions

### 10.2 Missing post ownership enforcement

The reviewed code does not enforce author-only editing or deletion.

### 10.3 Missing post delete workflow

There is no visible delete post action in the reviewed feed UI.

### 10.4 Missing comment lifecycle controls

There is no visible support for:
- edit comment
- delete comment
- soft delete comment
- comment audit trail

### 10.5 Missing save/bookmark wiring

The save/archive icon is present, but the action is not wired in the inspected code.

### 10.6 Missing robust poll voting controls

There is no clearly implemented per-user vote history or vote-locking mechanism.

### 10.7 Missing feed history/versioning

Post updates are logged generically, but there is no revision history or field-level diff view.

---

## 11) Overall Assessment

The Feed module is feature-rich from a social collaboration perspective, but it is still light on governance.

Strengths:
- Easy post creation and editing
- Media support
- Comments, replies, and reactions
- Poll creation and voting
- Simple, visually polished feed layout

Weaknesses:
- No clear author-only control for editing or deletion
- No feed-specific permissions in the reviewed code
- No comment delete/edit lifecycle
- Save/bookmark is not functional in the reviewed UI
- Poll voting is basic and not strongly identity-guarded
- Edit history is only recorded as general activity logging

---

## 12) Suggested Next Improvements

1. Add explicit feed permissions
- Separate create, edit, delete, comment, and vote permissions.

2. Enforce record ownership
- Restrict edit/delete to the author or authorized moderators.

3. Add comment lifecycle features
- Support edit, delete, soft delete, and audit history for comments.

4. Implement save/bookmark storage
- Persist saved posts per user and expose a saved-posts list.

5. Strengthen poll voting
- Store voter identity per option and prevent duplicate voting.

6. Add feed revision history
- Store field-level versions or history entries for each edit.

7. Add moderation tools
- Add delete/report/hide actions for posts and comments.

---

## Appendix: Related Files

- [docs/screen_inventory.txt](docs/screen_inventory.txt)
- [docs/firebase_service_inventory.txt](docs/firebase_service_inventory.txt)
- [docs/model_inventory.txt](docs/model_inventory.txt)

Report generated: April 14, 2026
