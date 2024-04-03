"""
This module provides a wrapper around the OpenAI API
"""
from __future__ import annotations

import openai as _openai
from enum import Enum as _Enum


class APIConnection:
    class RequestMode(_Enum):
        """
        An enumeration of the different modes that OpenAI's API supports.
        """

        EDIT = "edits"
        COMPLETION = "completions"

        # TODO: the below was auto-generated. I'm leaving it in for now because it
        # TODO: looks like an awesome idea and I want to implement it later.
        # # Generate code that runs a single script and returns the result
        # SINGLE = "single"
        # # Generate code that runs multiple scripts and returns the result of the last
        # # script
        # MULTIPLE = "multiple"
        # Edit the code to fix any errors

    def __init__(self, api_key: str):
        # Set up an OpenAI client and test the API key
        self.openai_client = _openai.api_requestor.APIRequestor(api_key)
        self._test_auth()
        self._cache: dict[str, str] = {}

    def _test_auth(self):
        """
        Test the OpenAI API key by sending a request to the OpenAI API. If the request
        fails, an exception is raised.
        """
        # Test the OpenAI API key by sending a request to the OpenAI API
        # We want to send a request that uses the API key, but doesn't require any
        # special permissions and requires the least amount of data/tokens. The
        # "Search" endpoint is a good candidate for this, so we'll use that.
        try:
            self.openai_client.request(url="/completions", method="GET")
        except _openai.error.AuthenticationError:
            raise ValueError("Invalid OpenAI API key")
        except _openai.error.InvalidRequestError:
            pass

    def list_engines(self) -> list[str]:
        """
        Lists the currently available (non-finetuned) models, and provides basic
        information about each one such as the owner and availability.

        Returns:
            list[str]: A list of the available engines.
        """
        # Get a list of the available engines
        response = self.openai_client.request("get", "/engines")
        return response[0].data["data"]

    def send_request(
        self,
        prompt: str = None,
        engine: str = "davinci",
        mode: APIConnection.RequestMode | str = "completion",
        temperature: float = 0,
        **kwargs,
    ) -> str:
        """
        Send a request to the OpenAI API and return the response.

        Args:
            prompt (str): The prompt to send to the OpenAI API.
            engine (str, optional): The engine to use. Defaults to "davinci".
            mode (CodeGenerator.RequestMode | str): The mode to use. This should be a
                valid value from the RequestModes enumeration or a string containing the
                name of a valid mode. Defaults to "completions".
            temperature (float, optional): A value between 0-1 which determines how
                random the generated code is. Higher values result in more random code;
                lower values result in more predictable code. Defaults to 0.5.
            **kwargs: Additional keyword arguments to pass to the OpenAI API.

        Returns:
            str: The generated code.
        """
        # Get / verify the mode
        if isinstance(mode, APIConnection.RequestMode):
            mode = mode.value
        elif isinstance(mode, str):
            try:
                mode = APIConnection.RequestMode[mode.upper()].value
            except KeyError:
                raise ValueError(f"Invalid request mode: {mode}")

        # Fill in the default values for the keyword arguments
        params: dict[str, str | int | float] = {
            "model": engine,
            "prompt": prompt,
            "max_tokens": 500,
            "temperature": temperature,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0,
            "logprobs": 0,
            "best_of": 1,
        }
        params.update(kwargs)
        # Remove any keys with a value of None
        params = {k: v for k, v in params.items() if v is not None}

        # Send a request to the OpenAI API and return the generated code
        response = self.openai_client.request("post", f"/{mode}", params)
        # print("RAW RESPONSE:", response[0].data)
        return response[0].data["choices"][0]["text"]
