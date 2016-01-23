# Method for generating a score by comparing 2 lists
def score_set(guess, solution):
	t = list(solution)
	c = 0
	a = 0
	for i in range(len(guess)):
		if guess[i] == t[i]:
			c += 1
			t[i] = "S"
			guess[i] = "G"
	for num in guess:
		try:
			i = t.index(num)
		except:
			continue
		a += 1
		t[i] = "X"
	return c, a
	return len(c), len(a.difference(c))

# Method for generating a score by comparing 2 lists
def score(guess, solution):
	tmp = list(solution)
	correct, almost = 0, 0
	for i in range(len(guess)):
		if guess[i] == tmp[i]:
			correct += 1
			tmp[i] = None
		else:
			try:
				s_i = tmp.index(guess[i])
			except:
				continue
			else:
				almost += 1
				tmp[s_i] = None
	return correct, almost
