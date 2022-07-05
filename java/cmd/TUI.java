import java.util.InputMismatchException;
import java.util.Scanner;

public class TUI implements View
{
	private Scanner stdin;

	public TUI()
	{
		this.stdin = new Scanner(System.in);
	}

	@Override
	public void output(Object obj)
	{
		System.out.println(obj.toString());
	}

	@Override
	public void getInput()
	{
		
	}

	public int getInt()
	{
		return 0;
	}

	private int guaranteeInt(String prompt)
	{
		boolean isInt = false;
		int returnInt = 0;

		do
		{
			this.output(prompt);

			try
			{
				returnInt = stdin.nextInt();
				isInt = true;
			}
			catch (InputMismatchException ex)
			{
				this.output("Please enter a valid integer!");
			}

			// Remove trailing newline after nextInt()
			stdin.nextLine();
		} while (!isInt);

		return returnInt;
	}
}