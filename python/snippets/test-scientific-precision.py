#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Given a set of numbers, run some tests to determine the validity of the idea in science
that the final precision is determined by the least precise number in the set *and*
that it is therefore acceptable to reduce the precision of all numbers to that of the
least precise number.

My hypothesis is that this is not true, and that the precision of the final result is
reduced in a compound fashion by the precision of each number in the set. i.e.: if only
one number in the set is reduced to a precision of 1, the final result will be reduced
to a precision of 1, but if all numbers are reduced to a precision of 1, the final
result will be reduced to some other precision less than 1.
"""

import math
import numpy as np
import random
import sys


def main():
    # If available, get a list of numbers from the arguments
    numbers: list[float]
    if len(sys.argv) > 1:
        numbers = [float(x) for x in sys.argv[1:]]
    else:
        numbers = [random.random() * 100 for _ in range(10)]
    print(f"Numbers: {numbers}")
