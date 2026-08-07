import inspect
import json
import logging
import os
import traceback
from datetime import datetime
from typing import Any

import json_log_formatter

LOG_LEVELS = {
    "CRITICAL": {"level": logging.CRITICAL, "severity": 0},
    "ERROR": {"level": logging.ERROR, "severity": 1},
    "WARNING": {"level": logging.WARNING, "severity": 2},
    "WARN": {"level": logging.WARNING, "severity": 2},
    "INFO": {"level": logging.INFO, "severity": 3},
    "DEBUG": {"level": logging.DEBUG, "severity": 4},
    "NOTSET": {"level": logging.NOTSET, "severity": 5},
}

SEVERITY_MAPPING = {meta["level"]: meta["severity"] for meta in LOG_LEVELS.values()}

_logger = logging.getLogger(__name__)


class JSONFormatter(json_log_formatter.JSONFormatter):
    """A log formatter which outputs JSON and structures log messages as required.

    https://github.com/ONSdigital/dp-standards/blob/main/LOGGING_STANDARDS.md
    """

    def json_record(self, message: str, extra: dict[str, Any], record: logging.LogRecord) -> dict[str, Any]:
        extra = extra.copy()

        record_data = {
            "created_at": datetime.fromtimestamp(record.created).isoformat(),
            "namespace": record.name,
            "severity": SEVERITY_MAPPING.get(record.levelno, 3),  # Default to INFO
            "event": message,
            "data": extra,
        }

        if record.exc_info:
            record_data["errors"] = [
                {
                    "message": traceback.format_exception_only(record.exc_info[1])[0].strip(),
                    "stack_trace": [
                        {"file": summary.filename, "function": summary.name, "line": summary.line}
                        for summary in traceback.extract_tb(record.exc_info[2])
                    ],
                }
            ]

        return record_data

    def to_json(self, record: dict) -> str:
        """Converts the record dict to a JSON string.

        If encoding fails, log a message with context.
        """
        try:
            return json.dumps(record)
        except (TypeError, ValueError):
            # NB: Care must be taken that this message is JSON serializable, to avoid recursion issues.
            _logger.exception(
                "Unable to serialize log message to JSON. Dropping message",
                extra={"original_message": str(record)},
            )
            return ""


def _parse_log_level(level_name: str, fallback: int) -> int:
    level_key = level_name.upper()
    if level_key in LOG_LEVELS:
        return LOG_LEVELS[level_key]["level"]
    return fallback


def configure_logging(level: int | None = None) -> None:
    """Configure root logger to use JSONFormatter for Lambda output.

    Configures the root logger with the ONS JSON format. If APP_LOG_LEVEL is set,
    automatically creates an app-specific logger for the calling package at that
    level, allowing your code to run at DEBUG while third-party libraries stay at INFO.

    Args:
        level: The log level to use. If None, reads from LOG_LEVEL env var (default: INFO).
    """
    if level is None:
        level = _parse_log_level(os.getenv("LOG_LEVEL", "INFO"), logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Reduce botocore log noise
    logging.getLogger("botocore.credentials").setLevel(logging.WARNING)

    formatter = JSONFormatter()

    if root_logger.handlers:
        for handler in root_logger.handlers:
            handler.setFormatter(formatter)
    else:
        handler = logging.StreamHandler()
        handler.setFormatter(formatter)
        root_logger.addHandler(handler)

    app_level_name = os.getenv("APP_LOG_LEVEL")
    if app_level_name:
        # Determine the calling package name automatically
        caller_frame = inspect.stack()[1]
        caller_module = caller_frame.frame.f_globals.get("__name__", "")
        app_logger_name = caller_module.split(".")[0]

        if app_logger_name and app_logger_name != "__main__":
            app_logger = logging.getLogger(app_logger_name)
            app_level = _parse_log_level(app_level_name, level)
            app_logger.setLevel(app_level)
            app_logger.propagate = False

            if app_logger.handlers:
                for handler in app_logger.handlers:
                    handler.setLevel(app_level)
                    handler.setFormatter(formatter)
            else:
                handler = logging.StreamHandler()
                handler.setLevel(app_level)
                handler.setFormatter(formatter)
                app_logger.addHandler(handler)
