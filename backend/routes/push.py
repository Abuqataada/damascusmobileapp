from __future__ import annotations

from functools import wraps

from flask import Blueprint, current_app, jsonify, request

from extensions import db
from models import DeviceToken
from services.fcm import send_multicast, send_to_token, send_to_topic


push_bp = Blueprint("push", __name__, url_prefix="/api/push")


def require_api_key(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        expected = current_app.config.get("PUSH_API_KEY")
        provided = request.headers.get("X-API-Key", "")
        if not expected or provided != expected:
            return jsonify({"error": "Unauthorized"}), 401
        return view(*args, **kwargs)

    return wrapped


@push_bp.post("/tokens")
def register_token():
    body = request.get_json(force=True, silent=False) or {}
    token = body.get("token")
    if not token:
        return jsonify({"error": "Missing token"}), 400

    user_id = body.get("user_id")
    platform = body.get("platform") or "android"
    app_version = body.get("app_version")
    device_name = body.get("device_name")

    device = DeviceToken.query.filter_by(token=token).one_or_none()
    if device is None:
        device = DeviceToken(
            token=token,
            user_id=user_id,
            platform=platform,
            app_version=app_version,
            device_name=device_name,
            enabled=True,
        )
        db.session.add(device)
    else:
        device.user_id = user_id or device.user_id
        device.platform = platform or device.platform
        device.app_version = app_version or device.app_version
        device.device_name = device_name or device.device_name
        device.enabled = True

    device.touch()
    db.session.commit()
    return jsonify({"ok": True, "device": device.to_dict()})


@push_bp.post("/tokens/unregister")
def unregister_token():
    body = request.get_json(force=True, silent=False) or {}
    token = body.get("token")
    if not token:
        return jsonify({"error": "Missing token"}), 400

    device = DeviceToken.query.filter_by(token=token).one_or_none()
    if device is None:
        return jsonify({"ok": True})

    device.enabled = False
    device.touch()
    db.session.commit()
    return jsonify({"ok": True})


@push_bp.post("/send")
@require_api_key
def send_push():
    body = request.get_json(force=True, silent=False) or {}
    token = body.get("token")
    topic = body.get("topic")

    if token:
        message_id = send_to_token(token, body)
        return jsonify({"ok": True, "message_id": message_id})

    if topic:
        message_id = send_to_topic(topic, body)
        return jsonify({"ok": True, "message_id": message_id})

    return jsonify({"error": "Provide either token or topic"}), 400


@push_bp.post("/broadcast")
@require_api_key
def broadcast_push():
    body = request.get_json(force=True, silent=False) or {}
    user_id = body.get("user_id")

    query = DeviceToken.query.filter_by(enabled=True)
    if user_id:
        query = query.filter_by(user_id=user_id)

    tokens = [device.token for device in query.all()]
    if not tokens:
        return jsonify({"ok": True, "sent": 0})

    response = send_multicast(tokens, body)
    return jsonify(
        {
            "ok": True,
            "sent": response.success_count,
            "failed": response.failure_count,
        }
    )
