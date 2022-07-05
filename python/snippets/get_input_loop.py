from typing import Callable, Type, TypeVar, Union

T = TypeVar("T")

class InvalidTypeException(Exception): pass

def input_loop(
        prompt: str = "> ",
        description: str = "",
        dtype: Type[T] = str,
        validate: Union[list[Callable[[T], bool]], Callable[[T], bool]] = [],
        attempts: int = -1,
        error_str: str = "Not a valid input!",
        show_errors: bool = False,
        ) -> T:
    """
    Prompt the user for input and loop until a valid value is entered.    

    :param prompt: text to display to the user when entering input
    :param description: text to display *once* when the function starts
    :param error_str: text to display when an invalid value is entered
    :param show_errors: show raw Python exception messages
    :param validate: a function 
    """
    # verify that the dtype is a class
    if not isinstance(dtype, Type):
        raise InvalidTypeException(f"`dtype` must be a class or type, not {type(dtype)}")

    def _validate(value):
        """validate the user's input"""
        nonlocal validate

        # check the value type
        validated = isinstance(value, dtype)
        if not validated: return False

        # convert the `validate` parameter to a list if not already one
        if not isinstance(validate, (list, tuple, set)):
            validate = [validate]
        
        # loop over all validation functions and check the given value
        for validator in validate:
            validated &= validator(value)

        return validated

    if description:
        print(description)

    user_input = None
    while attempts != 0 and not _validate(user_input):
        # get user input
        try:
            user_input = input(prompt)
        except Exception as e:
            if show_errors:
                print(e)
        
        # try to convert it to the given type
        try:
            user_input = dtype(user_input)
        except Exception as e:
            if show_errors:
                print(e)
            if error_str:
                print(error_str)

        attempts -= 1

    if _validate(user_input):
        return user_input
    return None
