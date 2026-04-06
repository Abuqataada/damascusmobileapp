from __future__ import annotations

import os


class BaseConfig:
    SECRET_KEY = os.environ.get("SECRET_KEY", "change-me")
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///damascus_push.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    FIREBASE_CREDENTIALS = os.environ.get("FIREBASE_CREDENTIALS")
    PUSH_API_KEY = os.environ.get("PUSH_API_KEY", "")
    NOTIFICATION_TTL_SECONDS = int(os.environ.get("NOTIFICATION_TTL_SECONDS", "2419200"))


class DevelopmentConfig(BaseConfig):
    DEBUG = True


class ProductionConfig(BaseConfig):
    DEBUG = False
