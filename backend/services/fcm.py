from __future__ import annotations

import os
from datetime import timedelta
from typing import Iterable

import firebase_admin
from firebase_admin import credentials, messaging


def initialize_firebase() -> None:
    if firebase_admin._apps:
        return

    credentials_path = os.environ.get("FIREBASE_CREDENTIALS")
    if not credentials_path:
        raise RuntimeError("FIREBASE_CREDENTIALS is not configured")

    firebase_admin.initialize_app(credentials.Certificate(credentials_path))


def build_data_payload(payload: dict) -> dict[str, str]:
    data = {}
    for key in ("url", "link", "deep_link", "screen", "id", "route"):
        value = payload.get(key)
        if value is not None:
            data[key] = str(value)
    return data


def send_to_token(token: str, payload: dict) -> str:
    initialize_firebase()

    notification = payload.get("notification", {})
    title = notification.get("title") or payload.get("title") or "Damascus Projects"
    body = notification.get("body") or payload.get("body") or ""

    message = messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body or None),
        data=build_data_payload(payload),
        android=messaging.AndroidConfig(
            priority="high",
            ttl=timedelta(
                seconds=int(payload.get("ttl_seconds") or os.environ.get("NOTIFICATION_TTL_SECONDS", "2419200"))
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound="default",
                    badge=1,
                    content_available=True,
                )
            )
        ),
    )
    return messaging.send(message)


def send_to_topic(topic: str, payload: dict) -> str:
    initialize_firebase()

    notification = payload.get("notification", {})
    title = notification.get("title") or payload.get("title") or "Damascus Projects"
    body = notification.get("body") or payload.get("body") or ""

    message = messaging.Message(
        topic=topic,
        notification=messaging.Notification(title=title, body=body or None),
        data=build_data_payload(payload),
    )
    return messaging.send(message)


def send_multicast(tokens: Iterable[str], payload: dict) -> messaging.BatchResponse:
    initialize_firebase()

    notification = payload.get("notification", {})
    title = notification.get("title") or payload.get("title") or "Damascus Projects"
    body = notification.get("body") or payload.get("body") or ""

    messages = [
        messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body or None),
            data=build_data_payload(payload),
        )
        for token in tokens
    ]
    return messaging.send_each(messages)
