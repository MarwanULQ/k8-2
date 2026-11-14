from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return "Kubernetes Flask webapp is running.\n"


@app.get("/health")
def health():
    return jsonify(status="ok")
