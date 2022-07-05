public class Main
{
	public static void main(String[] argv)
	{
		CommandController cc = new CommandController();
		String[] args = {"hello", "world"};
		
		System.out.println(cc.doEcho(args));
	}
}