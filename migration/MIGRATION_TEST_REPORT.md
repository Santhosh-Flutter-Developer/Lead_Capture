# Migration test report — READ THIS FIRST

**Nothing has been compiled or run.** The sandbox could not download the Dart/Flutter SDK, so `flutter pub get`, `flutter analyze`, unit tests and calls against your live API were **not executed**. The work is verified only by reading the PHP source and the Flutter code and by text searches. Expect some compile errors to fix on first build (likely spots: model constructor arguments in mappers, nullable/`??` warnings, part-file imports in blocs, `EventModel.copyWith`, `UserDataModel` args).

## What to run
```
flutter pub get
flutter analyze        # send me the errors, I will fix them
flutter run
```
## Manual test checklist (against your server)
Login admin & employee · forgot password OTP · employees/roles/designations CRUD · each master · leads (create, status → deal conversion, comment, attachment) · deals · tasks · tickets · projects/updations · payments · clients · calendar · notifications (30 s poll) · dashboard · activity/login logs · settings · trash restore · backup · chat (create direct/group, send, attachment, react, pin, forward) · feed (post, like, poll, comment) · holidays.

## Known behaviour differences
Polling instead of live streams (≤30 s; chat 5 s); unsupported actions listed in `MISSING_API_REQUIREMENTS.md`.
