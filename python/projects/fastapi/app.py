from fastapi import FastAPI

server = FastAPI()

@server.get("/")
def index():
    return "hello world"

@server.get("/foo")
def foo():
    return "foo"

@server.get("/sum/{x}/{y}")
def sum(x: int, y: int):
    """
    this endpoint adds two numbers
    """
    return x + y

def sum(x: int, y: int):
    return x + y
    
sum("one", "two")

