class EmailAddress:
    def __init__(self, address: str | None = None):
        self._address = address

    @property
    def address(self) -> str | None:
        return self._address

    @address.setter
    def address(self, value: str) -> None:
        if not isinstance(value, str):
            raise TypeError("Email Address must be a string")
        self._address = value

    @property
    def local(self) -> str:
        if self.address:
            index: int = 0
            try:
                index: int = self.address.index("@")
            except ValueError:
                ...
            return self.address[:index]

    def __str__(self):
        return self.address

    def __repr__(self):
        if self.address:
            return f"<{self.address}>"
        else:
            return ""


class GitUser:
    def __init__(self, name: str | None = None, email: str | None = None):
        self.name: str = name
        self.email = email

    @property
    def email(self) -> EmailAddress:
        return self._email

    @email.setter
    def email(self, value: str | None):
        if isinstance(value, str):
            self._email = EmailAddress(value)
        elif value is None:
            self._email = None
        else:
            raise TypeError("email must be a string")

    def __str__(self):
        _str: str = ""
        if self.name:
            _str += self.name
        if self.name and self.email:
            _str += " "
        if self.email:
            _str += f"<{self.email.address}>"
        return _str

    def __repr__(self):
        return f"<GitUser {self!s}>"
