import json
import logging
import sys
from unittest.mock import patch

from dis_logging import JSONFormatter, configure_logging


class TestJSONFormatter:
    def setup_method(self):
        self.formatter = JSONFormatter()

    def test_basic_log_record(self):
        record = logging.makeLogRecord(
            {"msg": "Hello world", "levelno": logging.INFO, "name": "test", "created": 1700000000.0}
        )
        formatted = self.formatter.format(record)
        data = json.loads(formatted)

        assert data["event"] == "Hello world"
        assert data["namespace"] == "test"
        assert data["severity"] == 3  # INFO
        assert "created_at" in data

    def test_severity_levels(self):
        levels = [
            (logging.CRITICAL, 0),
            (logging.ERROR, 1),
            (logging.WARNING, 2),
            (logging.INFO, 3),
            (logging.DEBUG, 4),
        ]
        for level, expected_severity in levels:
            record = logging.makeLogRecord({"msg": "test", "levelno": level, "name": "test", "created": 1700000000.0})
            formatted = self.formatter.format(record)
            data = json.loads(formatted)
            assert data["severity"] == expected_severity, f"Failed for level {level}"

    def test_extra_data_included(self):
        record = logging.makeLogRecord(
            {"msg": "test", "levelno": logging.INFO, "name": "test", "created": 1700000000.0}
        )
        formatted = self.formatter.format(record)
        data = json.loads(formatted)
        assert "data" in data

    def test_exception_info_included(self):
        try:
            raise ValueError("something went wrong")
        except ValueError:
            exc_info = sys.exc_info()

        record = logging.makeLogRecord(
            {
                "msg": "error occurred",
                "levelno": logging.ERROR,
                "name": "test",
                "created": 1700000000.0,
                "exc_info": exc_info,
            }
        )

        formatted = self.formatter.format(record)
        data = json.loads(formatted)

        assert "errors" in data
        assert len(data["errors"]) == 1
        assert "something went wrong" in data["errors"][0]["message"]
        assert "stack_trace" in data["errors"][0]

    def test_to_json_handles_unserializable(self):
        record = {"key": object()}
        result = self.formatter.to_json(record)
        assert result == ""


class TestConfigureLogging:
    def setup_method(self):
        # Reset root logger before each test
        root = logging.getLogger()
        root.handlers.clear()
        root.setLevel(logging.WARNING)
        # Reset any app loggers
        for name in ["my_module", "botocore.credentials"]:
            logger = logging.getLogger(name)
            logger.handlers.clear()
            logger.setLevel(logging.NOTSET)
            logger.propagate = True

    def teardown_method(self):
        # Clean up root logger
        root = logging.getLogger()
        root.handlers.clear()
        root.setLevel(logging.WARNING)

    def test_configures_root_logger_with_json_formatter(self):
        configure_logging()
        root = logging.getLogger()

        assert root.level == logging.INFO
        assert len(root.handlers) >= 1
        assert isinstance(root.handlers[0].formatter, JSONFormatter)

    def test_respects_level_argument(self):
        configure_logging(level=logging.DEBUG)
        root = logging.getLogger()
        assert root.level == logging.DEBUG

    def test_reads_log_level_from_env(self, monkeypatch):
        monkeypatch.setenv("LOG_LEVEL", "ERROR")
        configure_logging()
        root = logging.getLogger()
        assert root.level == logging.ERROR

    def test_configures_app_logger_automatically(self, monkeypatch):
        monkeypatch.setenv("APP_LOG_LEVEL", "DEBUG")

        # Simulate being called from a module named "my_module.handler"
        fake_frame = type("Frame", (), {"f_globals": {"__name__": "my_module.handler"}})()
        fake_info = type("FrameInfo", (), {"frame": fake_frame})()

        with patch("dis_logging.formatter.inspect.stack", return_value=[None, fake_info]):
            configure_logging()

        app_logger = logging.getLogger("my_module")
        assert app_logger.level == logging.DEBUG
        assert app_logger.propagate is False
        assert len(app_logger.handlers) >= 1
        assert isinstance(app_logger.handlers[0].formatter, JSONFormatter)

    def test_no_app_logger_without_env_var(self):
        # APP_LOG_LEVEL not set
        configure_logging()

        app_logger = logging.getLogger("my_module")
        assert app_logger.level == logging.NOTSET
        assert len(app_logger.handlers) == 0

    def test_no_app_logger_when_called_from_main(self, monkeypatch):
        monkeypatch.setenv("APP_LOG_LEVEL", "DEBUG")

        # Simulate being called from __main__
        fake_frame = type("Frame", (), {"f_globals": {"__name__": "__main__"}})()
        fake_info = type("FrameInfo", (), {"frame": fake_frame})()

        with patch("dis_logging.formatter.inspect.stack", return_value=[None, fake_info]):
            configure_logging()

        # Should not create an app logger for __main__
        main_logger = logging.getLogger("__main__")
        assert len(main_logger.handlers) == 0

    def test_reduces_botocore_noise(self):
        configure_logging()
        botocore_logger = logging.getLogger("botocore.credentials")
        assert botocore_logger.level == logging.WARNING

    def test_reuses_existing_handlers(self):
        root = logging.getLogger()
        existing_handler = logging.StreamHandler()
        root.addHandler(existing_handler)

        configure_logging()

        assert existing_handler in root.handlers
        assert isinstance(existing_handler.formatter, JSONFormatter)
