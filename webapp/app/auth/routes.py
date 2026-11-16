from urllib.parse import urlsplit

from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_user, logout_user
from flask_wtf import FlaskForm
from wtforms import PasswordField, StringField, SubmitField
from wtforms.validators import DataRequired, Email, EqualTo, Length

from .. import db
from ..models import User
from . import bp


class RegistrationForm(FlaskForm):
    name = StringField("Name", validators=[DataRequired(), Length(min=2, max=100)])
    email = StringField("Email", validators=[DataRequired(), Email(), Length(max=255)])
    password = PasswordField("Password", validators=[DataRequired(), Length(min=8, max=128)])
    password_confirmation = PasswordField(
        "Confirm password", validators=[DataRequired(), EqualTo("password", message="Passwords must match.")]
    )
    submit = SubmitField("Register")


class LoginForm(FlaskForm):
    email = StringField("Email", validators=[DataRequired(), Email(), Length(max=255)])
    password = PasswordField("Password", validators=[DataRequired()])
    submit = SubmitField("Log in")


def safe_next_url(target):
    if not target:
        return None
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not parsed.path.startswith("/"):
        return None
    return target


@bp.route("/register", methods=["GET", "POST"])
def register():
    if current_user.is_authenticated:
        return redirect(url_for("main.index"))
    form = RegistrationForm()
    if form.validate_on_submit():
        email = form.email.data.strip().lower()
        if User.query.filter_by(email=email).first():
            form.email.errors.append("An account with this email already exists.")
        else:
            user = User(name=form.name.data.strip(), email=email)
            user.set_password(form.password.data)
            db.session.add(user)
            db.session.commit()
            login_user(user)
            flash("Registration successful.", "success")
            return redirect(url_for("main.index"))
    return render_template("auth/register.html", form=form)


@bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("main.index"))
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data.strip().lower()).first()
        if user is None or not user.check_password(form.password.data):
            flash("Invalid email or password", "error")
        else:
            login_user(user)
            flash("Logged in successfully.", "success")
            return redirect(safe_next_url(request.args.get("next")) or url_for("main.index"))
    return render_template("auth/login.html", form=form)


@bp.post("/logout")
def logout():
    logout_user()
    flash("You have been logged out.", "success")
    return redirect(url_for("main.index"))
