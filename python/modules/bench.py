import time
import random

function = type(lambda x: None)

def clock(func, *args, reps=5, **kwargs):
	start = time.time()
	for x in range(0, reps):
		func(*args, **kwargs)
	total = time.time() - start
	print("Function '%s' with %i repetitions: %f" % (func.__code__.co_name, reps, total))
	return total

def compare(*args, reps=5):
	'''Compare functions. The format for functions is:
	
	compare((function1, args, kwargs), (function2, args, kwargs), ...)'''
	times = []
	funcs = []
	for arg in args:
		if isinstance(arg, function):
			func = arg
			args = []
			kwargs = {}
		elif len(arg) > 2:
			func, args, kwargs = arg[:3]
		elif len(arg) == 2:
			func, args = arg
			kwargs = {}
		t = clock(func, *args, reps=reps, **kwargs)
		times.append(t)
		funcs.append(func)
	f = 0
	f2 = 0
	for x in range(0, len(times)):
		if f2 == f and x != f:
			f2 = x
		if times[x] < times[f]:
			f2 = f
			f = x
	func = funcs[f]
	print("Function %i ('%s') is fastest by %f seconds" % (f + 1, func.__code__.co_name, times[f2] - times[f]))

def randdata(length=100):
	data = ""
	while len(data) < length:
		data += str(random.randrange(1000000000, 10000000000))
	data = data[:length]
	return data
