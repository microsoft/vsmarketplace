using System.Collections.Generic;
using System.IO;
using CsvHelper;
using Newtonsoft.Json;

namespace SearchScorer.Common
{
    public static class TopSearchSelectionsCsvReader
    {
        /* This is the query that generates the data:

let minTimestamp = todatetime('2019-07-02T18:57:00Z');
customMetrics
| where timestamp > minTimestamp
| where name == "BrowserSearchSelection"
| extend SearchQuery = trim("\\s", tostring(customDimensions.SearchTerm))
| extend selectedPackageId = tolower(tostring(customDimensions.PackageId))
| project timestamp, SearchQuery, selectedPackageId
| summarize count() by SearchQuery, selectedPackageId
| extend selectedPackageIdAndCount = strcat(selectedPackageId, ":", count_)
| order by count_ desc
| summarize sum(count_), makelist(selectedPackageIdAndCount) by SearchQuery
| order by sum_count_ 
| project SearchQuery, Selections = list_selectedPackageIdAndCount
| take 10000

            */
        public static IReadOnlyList<SearchQueryWithSelections> Read(string path)
        {
            using (var fileStream = File.OpenRead(path))
            using (var streamReader = new StreamReader(fileStream))
            using (var csvReader = new CsvReader(streamReader))
            {
                var output = new List<SearchQueryWithSelections>();
                foreach (var record in csvReader.GetRecords<Record>())
                {
                    var pairs = JsonConvert.DeserializeObject<List<string>>(record.Selections);
                    var selections = new List<SearchSelectionCount>();

                    foreach (var pair in pairs)
                    {
                        var pieces = pair.Split(new[] { ':' }, 2);
                        selections.Add(new SearchSelectionCount(
                            pieces[0].Trim(),
                            int.Parse(pieces[1])));
                    }

                    output.Add(new SearchQueryWithSelections(
                        record.SearchQuery,
                        selections));
                }

                return output;
            }
        }

        private class Record
        {
            public string SearchQuery { get; set; }
            public string Selections { get; set; }
        }
    }
}
