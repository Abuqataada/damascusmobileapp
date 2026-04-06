"""
Minimal Flask example for sending Firebase Cloud Messaging push notifications.

This example keeps the payload compatible with the Flutter app in this repo:
- `data.url`
- `data.link`
- `data.deep_link`

Install:
    pip install firebase-admin flask

Firebase setup:
1. Download your Firebase service account key JSON.
2. Point GOOGLE_APPLICATION_CREDENTIALS at that file.

Example:
    set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccountKey.json
"""

from __future__ import annotations

import os
from typing import Any, Dict

from flask import Flask, jsonify, request
import firebase_admin
from firebase_admin import credentials, messaging

app = Flask(__name__)


def initialize_firebase() -> None:
    if firebase_admin._apps:
        return

    credentials_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not credentials_path:
        raise RuntimeError(
            "Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON"
        )

    cred = credentials.Certificate(credentials_path)
    firebase_admin.initialize_app(cred)


def build_message(token: str, payload: Dict[str, Any]) -> messaging.Message:
    data = {
        key: str(value)
        for key, value in payload.items()
        if key in {"url", "link", "deep_link", "screen", "id"}
        and value is not None
    }

    notification = payload.get("notification", {})
    title = notification.get("title") or payload.get("title") or "Damascus Projects"
    body = notification.get("body") or payload.get("body") or ""

    return messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body or None),
        data=data,
    )


@app.post("/api/push/send")
def send_push() -> Any:
    initialize_firebase()

    body = request.get_json(force=True, silent=False) or {}
    token = body.get("token")
    if not token:
        return jsonify({"error": "Missing device token"}), 400

    message = build_message(token, body)
    message_id = messaging.send(message)
    return jsonify({"ok": True, "message_id": message_id})


@app.post("/api/push/topic")
def send_topic_push() -> Any:
    initialize_firebase()

    body = request.get_json(force=True, silent=False) or {}
    topic = body.get("topic")
    if not topic:
        return jsonify({"error": "Missing topic"}), 400

    notification = body.get("notification", {})
    title = notification.get("title") or body.get("title") or "Damascus Projects"
    body_text = notification.get("body") or body.get("body") or ""

    data = {
        key: str(value)
        for key, value in body.items()
        if key in {"url", "link", "deep_link", "screen", "id"}
        and value is not None
    }

    message = messaging.Message(
        topic=topic,
        notification=messaging.Notification(title=title, body=body_text or None),
        data=data,
    )
    message_id = messaging.send(message)
    return jsonify({"ok": True, "message_id": message_id})


if __name__ == "__main__":
    app.run(debug=True)
