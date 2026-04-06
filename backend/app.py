from __future__ import annotations

import os

from flask import Flask, jsonify

from config import DevelopmentConfig, ProductionConfig
from extensions import db
from routes.events import events_bp
from routes.push import push_bp


def create_app() -> Flask:
    app = Flask(__name__)
    env = os.environ.get("FLASK_ENV", os.environ.get("APP_ENV", "production")).lower()
    app.config.from_object(DevelopmentConfig if env == "development" else ProductionConfig)

    db.init_app(app)
    app.register_blueprint(push_bp)
    app.register_blueprint(events_bp)

    @app.get("/health")
    def health():
        return jsonify({"ok": True})

    with app.app_context():
        from models import DeviceToken  # noqa: F401

        db.create_all()

    return app


app = create_app()
