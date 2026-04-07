# Firebase Push Setup For This App

This app already includes the Flutter-side Firebase hooks for push notifications.
Follow the steps below to finish setup without changing the existing WebView logic.

## 1. Create Firebase Projects

Create a Firebase project in the Firebase console and register:

- An Android app with package name `io.kodular.abuqataada21.Damascus_Projects`
- An iOS app with the same bundle identifier used by your Flutter iOS project

## 2. Add Firebase Config Files

Place these files in the project:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

If you changed the Android package name after creating Firebase, re-download `google-services.json` from the Firebase console for the new package name so FCM keeps working.

## 3. Android Notification Permission

The Android manifest already includes the notification permission needed for Android 13+.
Users will still be prompted at runtime by the app.

## 4. iOS Notification Permission

The app requests notification permission on startup through Firebase Messaging.
Make sure push notification capability is enabled in Xcode and the APNs key is linked in Firebase.

## 5. Push Payload Format

To open a page inside the WebView, send data payloads with one of these keys:

- `url`
- `link`
- `deep_link`

Example payload:

```json
{
  "to": "FCM_DEVICE_TOKEN",
  "notification": {
    "title": "New update",
    "body": "Tap to open the dashboard"
  },
  "data": {
    "url": "https://app.damascusprojects.com/dashboard"
  }
}
```

If the URL is external, the app opens it in the device browser.
If the URL belongs to `damascusprojects.com`, the app keeps it inside the WebView.

## 6. Recommended Server Flow

From your Flask backend, store each device token after login and send notifications through Firebase Cloud Messaging when an event occurs.

Keep the payload small and only send the destination URL or route plus a short title/body.

For a minimal working Flask example, see [docs/flask_fcm_example.py](docs/flask_fcm_example.py).

For a production-ready backend scaffold, see the `backend/` folder in this repo.

## Production Backend Flow

Use these routes from your Flask app:

- `POST /api/push/tokens`
- `POST /api/push/tokens/unregister`
- `POST /api/push/send`
- `POST /api/push/broadcast`
- `POST /api/events/order-completed`

### Token registration payload

```json
{
  "token": "FCM_DEVICE_TOKEN",
  "user_id": "12345",
  "platform": "android",
  "app_version": "1.0.0",
  "device_name": "Pixel 7"
}
```

### Send push payload

All send routes accept a body like this:

```json
{
  "token": "FCM_DEVICE_TOKEN",
  "notification": {
    "title": "New message",
    "body": "You have a new update"
  },
  "url": "https://app.damascusprojects.com/messages/42"
}
```

Add the header:

```http
X-API-Key: your-server-api-key
```

### Sample authenticated app event

The `POST /api/events/order-completed` route shows how to trigger a push from a real app event.

Example request:

```json
{
  "user_id": "12345",
  "order_id": "ORD-9876"
}
```

With the same header:

```http
X-API-Key: your-server-api-key
```

The route looks up all active device tokens for that user and sends a push with:

- title: `Order completed`
- body: `Your order ORD-9876 is ready`
- url: `https://app.damascusprojects.com/orders/ORD-9876`

### Deployment notes

- Use PostgreSQL or another production database instead of SQLite.
- Keep the Firebase service account JSON out of source control.
- Rotate the push API key regularly.
- Store tokens per user and deactivate them on logout, uninstall events, or login from a new device if that matches your business rules.
- Protect token registration and token removal with your existing authentication layer, or only expose them after a verified session is established.

## 7. What This App Already Does

- Shows foreground notifications using `flutter_local_notifications`
- Handles taps from background and terminated states
- Opens internal pages in the WebView
- Sends external links to the browser
- Leaves normal browsing and upload behavior unchanged
