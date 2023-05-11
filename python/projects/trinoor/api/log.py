import logging as _logging
from lib_programname import get_path_executed_script as _get_program_path
from traceback import format_exception as _format_exception
from enum import Enum as _Enum
from pathlib import Path as _Path


class LogLevel(_Enum):
    """Enum for log levels"""

    # Detailed information, typically of interest only when diagnosing problems.
    DEBUG = _logging.DEBUG

    # Confirmation that things are working as expected.
    INFO = _logging.INFO

    # An indication that something unexpected happened, or indicative of some problem in
    # the near future (e.g. ‘disk space low’). The software is still working as
    # expected.
    WARNING = _logging.WARNING

    # Due to a more serious problem, the software has not been able to perform some
    # function.
    ERROR = _logging.ERROR

    # A serious error, indicating that the program itself may be unable to continue
    # running.
    CRITICAL = _logging.CRITICAL


# TODO: allow setting {"filepath": _Path, "stdout": bool, "stderr": bool, "format": str}
#       for each log level using a Logger.config dict or similar
class Logger:
    """
    A logger that handles writing to different `getLogger()` names for different log
    levels.

    Example:
        >>> logger = Logger("my_logger", error="my_logger.error", info="my_logger.info")
        >>> logger.info("This is an info message") # writes to my_logger.info
        >>> logger.error("This is an error message") # writes to my_logger.error
        >>> logger.warning("This is a warning message") # writes to my_logger
    """

    def __init__(
        self,
        default: str = None,
        debug: str = None,
        info: str = None,
        warning: str = None,
        error: str = None,
        critical: str = None,
    ) -> None:
        """
        A logger that handles writing to different `getLogger()` names for different log
        levels.

        Args:
            default (str): The name of the default logger to use. Defaults to the
                running program name.
            debug (str, optional): The name of the logger to write debug messages to.
                Defaults to the default logger.
            info (str, optional): The name of the logger to write info messages to.
                Defaults to the default logger.
            warning (str, optional): The name of the logger to write warning messages
                to. Defaults to the error logger.
            error (str, optional): The name of the logger to write error messages to.
                Defaults to the default logger.
            critical (str, optional): The name of the logger to write critical messages
                to. Defaults to the error logger.
        """
        self._default = default
        self._debug = debug
        self._info = info
        self._warning = warning
        self._error = error
        self._critical = critical

    @property
    def default_name(self) -> str:
        """
        The name of the default logger to use. Defaults to the running program name.
        """
        # If the default name is not set, set it to the name of the running program
        if not hasattr(self, "_default") or not self._default:
            self._default = _get_program_path().stem
        return self._default

    @default_name.setter
    def default_name(self, name: str) -> None:
        """
        Sets the default logger name.

        Args:
            name (str): The name of the default logger to use.
        """
        self._default = name

    @property
    def debug_name(self) -> str:
        """
        The name of the logger to write debug messages to. Defaults to the default
        logger.
        """
        return self._debug or self.default_name

    @debug_name.setter
    def debug_name(self, name: str) -> None:
        """
        Sets the debug logger name.

        Args:
            name (str): The name of the logger to write debug messages to.
        """
        self._debug = name

    @property
    def info_name(self) -> str:
        """
        The name of the logger to write info messages to. Defaults to the default
        logger.
        """
        return self._info or self.default_name

    @info_name.setter
    def info_name(self, name: str) -> None:
        """
        Sets the info logger name.

        Args:
            name (str): The name of the logger to write info messages to.
        """
        self._info = name

    @property
    def warning_name(self) -> str:
        """
        The name of the logger to write warning messages to. Defaults to the error
        logger.
        """
        return self._warning or self.error_name

    @warning_name.setter
    def warning_name(self, name: str) -> None:
        """
        Sets the warning logger name.

        Args:
            name (str): The name of the logger to write warning messages to.
        """
        self._warning = name

    @property
    def error_name(self) -> str:
        """
        The name of the logger to write error messages to.
        """
        if not hasattr(self, "_error") or not self._error:
            self._error = self.default_name
        return self._error

    @error_name.setter
    def error_name(self, name: str) -> None:
        """
        Sets the error logger name.

        Args:
            name (str): The name of the logger to write error messages to.
        """
        self._error = name

    @property
    def critical_name(self) -> str:
        """
        The name of the logger to write critical messages to. Defaults to the error
        logger.
        """
        return self._critical or self.error_name

    @critical_name.setter
    def critical_name(self, name: str) -> None:
        """
        Sets the critical logger name.

        Args:
            name (str): The name of the logger to write critical messages to.
        """
        self._critical = name

    def _get_logger(self, level: LogLevel) -> _logging.Logger:
        """
        Gets the logger for the given log level.

        Args:
            level (LogLevel): The log level to get the logger for.

        Returns:
            _logging.Logger: The logger for the given log level.
        """
        # Get the logger name for the given log level
        logger_name = self.default_name
        if level == LogLevel.DEBUG:
            logger_name = self.debug_name
        elif level == LogLevel.INFO:
            logger_name = self.info_name
        elif level == LogLevel.WARNING:
            logger_name = self.warning_name
        elif level == LogLevel.ERROR:
            logger_name = self.error_name
        elif level == LogLevel.CRITICAL:
            logger_name = self.critical_name

        # Return the logger
        return _logging.getLogger(logger_name)

    def set_level(self, level: LogLevel) -> None:
        """
        Sets the level for messages to display. Any logging calls below this threshhold
        will not do anything.

        Args:
            level (LogLevel): The log level to set.
        """
        _logging.basicConfig(level=level.value)

    def log(self, level: LogLevel, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the specified level.

        Args:
            level (LogLevel): The level to log at.
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        # Determine the logging function to use
        log_function: callable
        if level == LogLevel.DEBUG:
            log_function = _logging.getLogger(self.debug_name).debug
        elif level == LogLevel.INFO:
            log_function = _logging.getLogger(self.info_name).info
        elif level == LogLevel.WARNING:
            log_function = _logging.getLogger(self.warning_name).warning
        elif level == LogLevel.ERROR:
            log_function = _logging.getLogger(self.error_name).error
        elif level == LogLevel.CRITICAL:
            log_function = _logging.getLogger(self.critical_name).critical
        else:
            raise ValueError(f"Invalid log level: {level}")

        # Get the exception if one is passed
        exc: Exception = None
        if isinstance(msg, Exception):
            exc = msg
            msg = ""
        else:
            _args: list[str] = []
            for arg in args:
                if isinstance(arg, Exception):
                    exc = arg
                    # logging tries to insert the args into the message via % formatting
                    # so if there isn't a %s in the message, we will not include the
                    # exception in the args
                    if "%s" in msg:
                        _args.append(str(arg))
                else:
                    _args.append(str(arg))
            args = _args

        # Log the message
        if msg:
            log_function(msg, *args, **kwargs)

        # Log the exception if one was passed
        if exc:
            for line in _format_exception(exc):
                log_function(line.rstrip())

    def debug(self, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the debug level.

        Args:
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        self.log(LogLevel.DEBUG, msg, *args, **kwargs)

    def info(self, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the info level.

        Args:
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        self.log(LogLevel.INFO, msg, *args, **kwargs)

    def warning(self, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the warning level.

        Args:
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        self.log(LogLevel.WARNING, msg, *args, **kwargs)

    def error(self, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the error level.

        Args:
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        self.log(LogLevel.ERROR, msg, *args, **kwargs)

    def critical(self, msg: str | Exception, *args, **kwargs) -> None:
        """
        Logs a message at the critical level.

        Args:
            msg (str): The message or Exception to log. If an Exception is passed,
                the full traceback is logged.
            *args: Additional arguments to pass to the logger. If an exception is
                included in the args, the full traceback is logged.
            **kwargs: Additional keyword arguments to pass to the logger.
        """
        self.log(LogLevel.CRITICAL, msg, *args, **kwargs)
