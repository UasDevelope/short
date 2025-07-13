# Firebase Setup Guide

## 1. Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing project
3. Enable Firestore Database
4. Enable Storage (for video uploads)

## 2. Firestore Security Rules

Copy the contents of `firestore.rules` to your Firebase Console:

1. Go to Firestore Database → Rules
2. Replace the rules with the content from `firestore.rules`
3. Publish the rules

## 3. Firebase Storage Rules

Copy the contents of `storage.rules` to your Firebase Console:

1. Go to Storage → Rules
2. Replace the rules with the content from `storage.rules`
3. Publish the rules

## 4. iOS Configuration

1. Download `GoogleService-Info.plist` from Firebase Console
2. Add it to `ios/Runner/` directory
3. Add to Xcode project if not automatically added

## 5. Android Configuration

1. Download `google-services.json` from Firebase Console
2. Add it to `android/app/` directory

## 6. Test the App

The app will now:
- ✅ Work with sample videos if Firestore is not configured
- ✅ Create sample data automatically
- ✅ Handle permission errors gracefully
- ✅ Show videos from Firestore when properly configured

## Troubleshooting

If you still see permission errors:
1. Check that Firestore rules are published
2. Verify `GoogleService-Info.plist` is in the iOS project
3. Make sure the Firebase project is properly configured 