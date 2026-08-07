# dis-infra-python-logging

ONS Dissemination JSON log formatter for Python Lambda functions.

Implements the [ONS logging standards](https://github.com/ONSdigital/dp-standards/blob/main/LOGGING_STANDARDS.md)
as a reusable package.

## Installation

Add as a git dependency in your `pyproject.toml`:

```toml
[tool.poetry.dependencies]
dis-logging = {git = "git@github.com:ONSdigital/dis-infra-python-logging.git", tag = "v1.0.0"}
```

Then run:

```bash
poetry lock && poetry install
```

## Usage

Call `configure_logging()` once in your handler file:

```python
from dis_logging import configure_logging

configure_logging()
```

That's it. All loggers in your code will output structured JSON. No arguments
required — it reads configuration from environment variables.

### How it works

- Configures the **root logger** with the ONS JSON format
- Every `logging.getLogger(__name__)` in your code inherits the formatter
- Third-party libraries (boto3, urllib3) are automatically covered
- If `APP_LOG_LEVEL` is set, your app code gets a separate log level while
  third-party libraries stay at the root level — so you can `DEBUG` your code
  without drowning in boto noise

### Example

```python
# my_module/handler.py
import logging
from dis_logging import configure_logging

configure_logging()
logger = logging.getLogger(__name__)

def lambda_handler(event, context):
    logger.info("Processing event", extra={"event_id": event.get("id")})
    return {"statusCode": 200}
```

Output:

```json
{"created_at": "2024-01-15T10:30:00", "namespace": "my_module.handler", "severity": 3, "event": "Processing event", "data": {"event_id": "abc123"}}
```

### Configuration

| Environment variable | Description | Default |
|---------------------|-------------|---------|
| `LOG_LEVEL` | Root logger level (all loggers) | `INFO` |
| `APP_LOG_LEVEL` | Your app code's log level (auto-detected from caller package) | — |

### Severity levels

| Level | Severity |
|-------|----------|
| CRITICAL | 0 |
| ERROR | 1 |
| WARNING | 2 |
| INFO | 3 |
| DEBUG | 4 |

## Development

```bash
make install  # Install dependencies
make test     # Run tests
make lint     # Run linting
make format   # Auto-format
make all      # Run everything
```

## Contributing

Full contributing [guidelines are covered here](CONTRIBUTING.md).
