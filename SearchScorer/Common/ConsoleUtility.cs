using System;

namespace SearchScorer.Common
{
    public static class ConsoleUtility
    {
        public static void WriteHeading(string heading, char fence)
        {
            Console.WriteLine();
            Console.WriteLine(heading);
            Console.WriteLine(new string(fence, heading.Length));
        }
    }
}
