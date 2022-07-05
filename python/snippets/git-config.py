def get_config(key: str, default: str = None, repo: Repository = None) -> str:
    values: list[str] = []
    # try to find the configuration using the repo if provided
    if repo:
            values = list(repo.config.get_multivar(key))
    else:
        values = list(pygit2.Config.get_global_config().get_multivar(key))
    if len(values) > 0:
        return values[0]
    return default

class User:
    _name: str = None
    _email: str = None
    _username: str = None
    _password: str = None
    @property
    def name(self) -> str:
        if self._name:
            return self._name
        # return the environment git user.name
        value: str = get_config("user.name")
        if not value:
            raise NoIdentityException("No user.name found. Please either set `git config --global user.name <name>` or set `git.user.name = '<name>'`")
        return value
    @name.setter
    def name(self, value: str):
        self._name = value
    @property
    def email(self) -> str:
        if self._email:
            return self._email
        value: str = get_config("user.email")
        if not value:
            raise NoIdentityException("No user.email found. Please either set `git config --global user.email <email>` or set `git.user.email = '<email>'`")
        return value
    @email.setter
    def email(self, value: str):
        self._email = value
    @property
    def username(self) -> str:
        if self._username:
            return self._username
        # return the environment git user.name
        value: str = get_config("credential.username")
        if not value:
            raise NoIdentityException("No credential.username found. Please either set `git config credential.username <username>` or set `git.user.username = '<username>'`")
        return value
    @username.setter
    def username(self, value: str):
        self._username = value
    @property
    def password(self) -> str:
        if self._password:
            return self._password
        raise NoIdentityException("No credential.helper found. Please set `git.user.password = '<password>'`")
    @password.setter
    def password(self, value: str):
        self._password = value
user = User()
