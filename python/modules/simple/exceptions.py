import sys
from typing import Optional
from types import TracebackType

class SimpleException(Exception):
    exception: Exception
    traceback: TracebackType
    reason: str
    filename: str
    line: int
    name: str
    type: type

    def __init__(self, e: Exception = None):
        self.exception = Exception()
        if isinstance(self._get_exception(e), Exception):
            self._init()

    def _get_exception(self, e: Exception = None) -> Optional[Exception]:
        if isinstance(e, Exception):
            self.exception = e
        else:
            # Try to get the most recent traceback
            info = sys.exc_info()
            if isinstance(info[1], Exception):
                self.exception = info[1]
        return self.exception

    def _init(self) -> None:
        if isinstance(self.exception, Exception):
            self.name = self.exception.__class__.__name__
            if isinstance(self.exception.__traceback__, TracebackType):
                self.traceback = self.exception.__traceback__
                self.line = self.traceback.tb_lineno
                self.filename = self.traceback.tb_frame.f_code.co_filename
                self.reason = str(self.exception)

    def __bool__(self) -> bool:
        return hasattr(self, "exception") and isinstance(self.exception, Exception)
