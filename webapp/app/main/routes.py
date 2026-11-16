from flask import jsonify, render_template

from . import bp


@bp.get("/")
def index():
    return render_template("index.html")


@bp.get("/healthz")
def healthz():
    return jsonify(status="ok")


@bp.get("/health")
def health():
    return healthz()
