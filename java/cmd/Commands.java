public class Commands
{
	
}

interface Command
{
	public abstract void run(String[] args);
	public abstract String getHelp();
}