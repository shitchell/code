from pydantic import BaseModel, BaseSettings, Field, conint, constr, validator, root_validator, ValidationError
from typing import List, Optional
from datetime import datetime
import re

# Define the Friend model
class Friend(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)  # Name with constraints on length
    age: conint(ge=0, le=120)  # Constrained integer between 0 and 120
    years_known: conint(ge=0)  # Constrained integer greater than or equal to 0

    # Custom validator to ensure the name contains only alphabetic characters
    @validator('name')
    def name_must_be_alpha(cls, v):
        if not re.match(r'^[a-zA-Z]+$', v):
            raise ValueError('name must only contain letters')
        return v

# Define the Person model
class Person(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)  # Name with constraints on length
    age: conint(ge=0, le=120)  # Constrained integer between 0 and 120
    email: Optional[str] = Field(None, regex=r'^\S+@\S+\.\S+$')  # Optional email field with regex validation
    friends: List[Friend] = []  # List of Friend models, defaulting to an empty list

    # Config class to set additional model options
    class Config:
        min_anystr_length = 1  # Minimum length for any string field
        max_anystr_length = 50  # Maximum length for any string field
        anystr_strip_whitespace = True  # Strip leading/trailing whitespace from string fields
        validate_assignment = True  # Enable validation on assignment

    # Custom validator to ensure the name contains only alphabetic characters
    @validator('name')
    def name_must_be_alpha(cls, v):
        if not re.match(r'^[a-zA-Z]+$', v):
            raise ValueError('name must only contain letters')
        return v

    # Root validator to check all fields after individual field validation
    @root_validator
    def check_age(cls, values):
        age = values.get('age')
        if age and age < 0:
            raise ValueError('age must be a non-negative integer')
        return values

# Define the Settings model for application configuration
class Settings(BaseSettings):
    app_name: str  # Application name
    admin_email: Optional[str] = Field(None, regex=r'^\S+@\S+\.\S+$')  # Optional admin email with regex validation
    items_per_user: int = 50  # Default number of items per user
    debug_mode: bool = False  # Debug mode flag

    # Config class to set additional settings options
    class Config:
        env_prefix = 'MYAPP_'  # Prefix for environment variables
        env_file = '.env'  # Path to .env file
        env_file_encoding = 'utf-8'  # Encoding for .env file

# Example usage
def main():
    # Load settings from environment variables and .env file
    settings = Settings()
    print(f"App Name: {settings.app_name}")
    print(f"Admin Email: {settings.admin_email}")
    print(f"Items Per User: {settings.items_per_user}")
    print(f"Debug Mode: {settings.debug_mode}")

    # Create a person and their friends
    try:
        friend1 = Friend(name="Alice", age=30, years_known=5)  # Creating a Friend instance
        friend2 = Friend(name="Bob", age=25, years_known=3)  # Creating another Friend instance
        person = Person(
            name="JohnDoe",
            age=28,
            email="john.doe@example.com",
            friends=[friend1, friend2]  # Creating a Person instance with friends
        )
        print(person.json(indent=2))  # Print the JSON representation of the person
    except ValidationError as e:
        print("Validation error:", e.json(indent=2))  # Print validation errors, if any

if __name__ == "__main__":
    main()