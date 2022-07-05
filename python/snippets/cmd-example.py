import cmd

class Game(cmd.Cmd):
    intro = "The Game\nType help or ? to list commands.\n"
    prompt = "> "
    file = ".game-input-history.txt"
    
    def do_left(self, arg):
        """move left"""
        print("you went left!")
    def do_right(self, arg):
        """move right"""
        print("you went right!")

Game().cmdloop()
