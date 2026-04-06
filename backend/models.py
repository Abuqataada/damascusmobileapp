from __future__ import annotations

from datetime import datetime, timezone

from extensions import db


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DeviceToken(db.Model):
    __tablename__ = "device_tokens"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(128), nullable=True, index=True)
    token = db.Column(db.String(512), nullable=False, unique=True, index=True)
    platform = db.Column(db.String(32), nullable=False, default="android")
    enabled = db.Column(db.Boolean, nullable=False, default=True)
    app_version = db.Column(db.String(32), nullable=True)
    device_name = db.Column(db.String(128), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=utcnow,
        onupdate=utcnow,
    )
    last_seen_at = db.Column(db.DateTime(timezone=True), nullable=True)

    def touch(self) -> None:
        self.last_seen_at = utcnow()

    def to_dict(self) -> dict[str, object | None]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "token": self.token,
            "platform": self.platform,
            "enabled": self.enabled,
            "app_version": self.app_version,
            "device_name": self.device_name,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "last_seen_at": self.last_seen_at.isoformat() if self.last_seen_at else None,
        }
