import os

from flask import Flask
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from flask_wtf import CSRFProtect

db = SQLAlchemy()
migrate = Migrate()
csrf = CSRFProtect()
login_manager = LoginManager()
login_manager.login_view = "auth.login"
login_manager.login_message = "Please log in to continue."


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.from_mapping(
        SECRET_KEY=os.getenv("SECRET_KEY", "dev-only-change-me"),
        SQLALCHEMY_DATABASE_URI=os.getenv("DATABASE_URL", "sqlite:///library.db"),
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "false").lower() == "true",
    )
    if test_config:
        app.config.update(test_config)

    db.init_app(app)
    migrate.init_app(app, db)
    csrf.init_app(app)
    login_manager.init_app(app)

    from .auth import bp as auth_bp
    from .main import bp as main_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    return app


@login_manager.user_loader
def load_user(user_id):
    from .models import User

    return db.session.get(User, int(user_id))
