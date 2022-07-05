import java.util.Scanner;

public class StringReverse
{
	public static void main(String[] args)
	{
		System.out.println("Type some shit:");
		Scanner stdin = new Scanner(System.in);
		String revStr = StringReverse.reverseStr(stdin.nextLine());
		System.out.println(revStr);
	}

	public static String reverseStr(String str)
	{
		System.out.println("Calling reverseStr on: " + str);

		if (str.length() <= 1)
		{
			return str;
		}

		char last = str.charAt(0);
		String rev = str.substring(1);
		return reverseStr(rev) + last;
	}
}