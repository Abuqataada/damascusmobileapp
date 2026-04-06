from __future__ import annotations

from flask import Blueprint, jsonify, request

from models import DeviceToken
from routes.push import require_api_key
from services.fcm import send_multicast


events_bp = Blueprint("events", __name__, url_prefix="/api/events")


@events_bp.post("/order-completed")
@require_api_key
def order_completed():
    """
    Sample authenticated app event.

    Send a push to every active device registered for a user when an order completes.
    """

    body = request.get_json(force=True, silent=False) or {}
    user_id = body.get("user_id")
    order_id = body.get("order_id")

    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400

    query = DeviceToken.query.filter_by(enabled=True, user_id=str(user_id))
    tokens = [device.token for device in query.all()]
    if not tokens:
        return jsonify({"ok": True, "sent": 0, "message": "No active devices for user"}), 200

    payload = {
        "notification": {
            "title": "Order completed",
            "body": f"Your order {order_id or ''} is ready".strip(),
        },
        "url": f"https://app.damascusprojects.com/orders/{order_id}" if order_id else "https://app.damascusprojects.com/orders",
        "route": "/orders",
        "id": order_id,
    }

    response = send_multicast(tokens, payload)
    return jsonify(
        {
            "ok": True,
            "sent": response.success_count,
            "failed": response.failure_count,
            "user_id": user_id,
            "order_id": order_id,
        }
    )
