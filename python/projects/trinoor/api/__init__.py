"""
This is a modular, RESTful FastAPI server. Out of the box, it supports only
enabling, disabling, and loading plugins. Every other functionality is added
via plugins.

Responses follow the model:
```
{
    "response_code": 200,
    "success": true,
    "message": "the thing you did did the thing it was supposed to do",
    "payload": {
        "users": ["john", "jacob", ...]
    }
}
```
"""
