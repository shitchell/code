def do_test(req, *args, **kwargs):
	def do_more():
		print("wat")
	if req:
		req.wfile.write(bytes(" ".join(args), "UTF-8"))
do_test.hidden = True

def do_foo(req, *args, **kwargs):
	req.wfile.write(bytes("bar", "UTF-*"))
