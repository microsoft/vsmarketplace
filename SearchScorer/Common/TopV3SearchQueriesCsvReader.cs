using System.Collections.Generic;
using System.IO;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class TopV3SearchQueriesCsvReader
    {
        /* This is the query that generates the data:

        requests
        | where timestamp > ago(90d)
        | where name == "GET Search/V3SearchAsync"
        | where operation_SyntheticSource != "Application Insights Availability Monitoring"
        | extend parsedUrl = parse_url(url)
        | extend q = tostring(parsedUrl["Query Parameters"]["q"])
        | where (tolower(q) matches regex "^packageid(:|%3a)[\\w\\._-]+$") == false
        | summarize sum(itemCount) by q
        | order by sum_itemCount desc
        // | where sum_itemCount < 296 // Use this filter to get the next "page" of 10,000
        | take 10000

        */

        public static Dictionary<string, int> Read(string pathPattern)
        {
            var output = new Dictionary<string, int>();

            foreach (var path in Directory.EnumerateFiles(
                Path.GetDirectoryName(pathPattern),
                Path.GetFileName(pathPattern)))
            {
                using (var fileStream = File.OpenRead(path))
                using (var streamReader = new StreamReader(fileStream))
                using (var csvReader = new CsvReader(streamReader))
                {
                    foreach (var record in csvReader.GetRecords<Record>())
                    {
                        output[record.q] = record.sum_itemCount;
                    }
                }
            }

            return output;
        }

        private class Record
        {
            public string q { get; set; }
            public int sum_itemCount { get; set; }
        }
    }
}
