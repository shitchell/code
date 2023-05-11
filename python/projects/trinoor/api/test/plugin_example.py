from ..api import APIPlugin, Request, handles, fire_event, does, context


class TestPlugin(APIPlugin):
    @self.post("/test")
    async def test(self, request: Request) -> tuple[str, int]:
        """
        Test the API.
        """
        return "Test successful", 200

    @handles("test_action")
    @context(lambda data: data["this"] == "that", foo="bar")
    async def test_action(self, request: Request) -> tuple[str, int]:
        """
        Test the API.
        """
        return "Test successful", 200
