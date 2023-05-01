public class StringUtilities
{
    /**
     * Trims each line separated by \n in a string.
     **/
    public static String trimEachLine(String stringArr)
    {
        String[] lines = stringArr.split("\n");
        String result = "";
        for (String line : lines)
        {
            result += line.trim() + "\n";
        }
        return result;
    }
}