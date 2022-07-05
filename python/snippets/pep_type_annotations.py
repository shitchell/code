import sys

def print_int(num: int):
	print("Number: %i" % num)

def print_float(num: float):
	print("Rounded Float: %.2f" % num)

print_float("hello")

for x in [10, "10", 69.96284, "9000.1"]:
	print("print_int", x, type(x))
	try:
		print_int(x)
	except Exception as e:
		print(e)
	print("print_float", x, type(x))
	try:
		print_float(x)
	except Exception as e:
		print(e)
