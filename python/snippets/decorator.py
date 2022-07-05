#!/usr/bin/env python3

from enum import Enum

class Player:
    def __init__(self, admin=False):
        self.admin = bool(admin)

    def __repr__(self):
        return "Admin" if self.admin else "User"

class Game:
    def __init__(self, player=None):
        self.player = player or Player()
        self.state = Game.State.IN_GAME

    class State(Enum):
        START_MENU = 1
        GAME_OVER = 2
        IN_GAME = 3
        PUZZLE = 4
        FIGHT = 5
    
    def run_command(self, command, *args, **kwargs):
        command_name = "do_" + command
        if hasattr(self, command_name):
            func = getattr(self, command_name)
            return func(*args, **kwargs)

    def admin(func):
        def wrapper(self, *args, **kwargs):
            print("4", self.player)
            if self.player.admin:
                print("5", "running admin command")
                return func(self, *args, **kwargs)
        return wrapper

    def state(state=State.IN_GAME):
        def state_decorator(func):
            def func_wrapper(self, *args, **kwargs):
                if self.state == state:
                    return func(self, *args, **kwargs)
            return func_wrapper
        return state_decorator

    @admin
    def do_admin(self, *args, **kwargs):
        return "Admin command"

    def do_user(self, *args, **kwargs):
        return "User command"

    @state(State.PUZZLE)
    def do_puzzle(self, *args, **kwargs):
        return "Puzzle command"

jack = Player()
admin = Player(True)
game = Game(jack)
print("1", game.player)
print("2", game.run_command("admin"))
print("3", game.run_command("user"))
print("6", game.run_command("puzzle"))
game.state = Game.State.PUZZLE
print("7", game.run_command("puzzle"))
