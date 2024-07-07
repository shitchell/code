## 1. Set up the models using pydantic
from pydantic import BaseModel

class Friend(BaseModel):
    name: str
    age: int
    years_known: int

class Person(BaseModel):
    name: str
    age: int
    friends: list[Friend] = []

    @classmethod
    def from_json(cls, data: dict):
        return cls(**data)

## 2. Create a person from JSON data
import json

json_str = """{
    "name": "Alice",
    "age": 30,
    "friends": [
        {
            "name": "Bob",
            "age": 31,
            "years_known": 10
        },
        {
            "name": "Charlie",
            "age": 29,
            "years_known": 5
        }
    ]
}"""
json_data = json.loads(json_str)

# person = Person(**json_data)
person = Person.from_json(json_data)

print(person)
