public class Final {
	int MAX_RETRY = 100;
	
	public static void main(String[] args)
	{
		Final f = new Final();
		f.callTwitterApi();
	}

	public void callTwitterApi()
	{
		int retryAttempts = 0;
		boolean retry = true;

		do {
			try {
				// myTwitter.makePostRequest();
				System.out.println("Making post request");
				retry = false;
			} catch (Exception e) {
					// We got an exception. Want to retry.
			}
		} while (retry && (retryAttempts++ < MAX_RETRY));
	}
}
