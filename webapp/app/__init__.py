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

    @app.cli.command("seed-books")
    def seed_books():
        from .models import Book

        books = [
            ("The Great Gatsby", "F. Scott Fitzgerald", "Classic", "great-gatsby.jpg", "12.99", 4),
            ("Pride and Prejudice", "Jane Austen", "Romance", "pride-prejudice.jpg", "10.50", 3),
            ("Frankenstein", "Mary Shelley", "Gothic", "frankenstein.jpg", "11.25", 5),
            ("1984", "George Orwell", "Dystopian", "1984.jpg", "13.75", 2),
            ("The Hobbit", "J.R.R. Tolkien", "Fantasy", "the-hobbit.jpg", "15.00", 4),
            ("The Little Prince", "Antoine de Saint-Exupéry", "Fiction", "little-prince.jpg", "9.99", 3),
        ]
        for title, author, category, cover, price, quantity in books:
            book = Book.query.filter_by(title=title).first()
            if book is None:
                book = Book(title=title, total_quantity=quantity, available_quantity=quantity)
                db.session.add(book)
            book.author = author
            book.category = category
            book.cover_image = cover
            book.price = price
            if book.total_quantity is None:
                book.total_quantity = quantity
            if book.available_quantity is None:
                book.available_quantity = quantity
        db.session.commit()
        print(f"Seeded or updated {len(books)} books.")
    return app


@login_manager.user_loader
def load_user(user_id):
    from .models import User

    return db.session.get(User, int(user_id))
