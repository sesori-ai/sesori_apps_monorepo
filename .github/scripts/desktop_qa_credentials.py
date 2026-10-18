"""Dedicated CI account input. Never pass these values through argv or child environments."""

from dataclasses import dataclass
import os


AUTH_EMAIL_ENVIRONMENT_KEY = "SESORI_DESKTOP_QA_EMAIL"
AUTH_PASSWORD_ENVIRONMENT_KEY = "SESORI_DESKTOP_QA_PASSWORD"


@dataclass(frozen=True, repr=False)
class QaCredentials:
    email: str
    password: str


def load_qa_credentials() -> QaCredentials:
    # Consume before starting any child, including dbus-run-session and its daemon.
    email = os.environ.pop(AUTH_EMAIL_ENVIRONMENT_KEY, None)
    password = os.environ.pop(AUTH_PASSWORD_ENVIRONMENT_KEY, None)
    if email is None or not email.strip():
        raise ValueError(f"{AUTH_EMAIL_ENVIRONMENT_KEY} is required")
    if password is None or not password:
        raise ValueError(f"{AUTH_PASSWORD_ENVIRONMENT_KEY} is required")
    if any(delimiter in value for value in (email, password) for delimiter in ("\n", "\r")):
        raise ValueError("QA credentials must be single-line values")
    return QaCredentials(email=email, password=password)
