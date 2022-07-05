import java.util.Arrays;
import java.util.stream.Collectors;

public class CommandController
{
	private Game game;
	
	public String doEcho(String[] args)
	{
		return Arrays.stream(args).collect(Collectors.joining(" "));
	}
}