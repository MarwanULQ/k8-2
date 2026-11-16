from flask import jsonify, render_template
from ..models import Book

from . import bp


@bp.get("/")
def index():
    return render_template("index.html", books=Book.query.order_by(Book.title).all())


@bp.get("/healthz")
def healthz():
    return jsonify(status="ok")


@bp.get("/health")
def health():
    return healthz()
