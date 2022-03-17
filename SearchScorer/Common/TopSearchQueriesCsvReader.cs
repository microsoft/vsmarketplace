using System.Collections.Generic;
using System.IO;
using System.Linq;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class TopSearchQueriesCsvReader
    {
        /* This is the query that generates the data:

let minTimestamp = todatetime('2019-07-02T18:57:00Z');
customMetrics
| where timestamp > minTimestamp
| where name == "BrowserSearchPage"
| where customDimensions.PageIndex == 0
| extend Query = trim("\\s", tostring(customDimensions.SearchTerm))
| distinct Query, session_Id
| summarize QueryCount = count() by Query
| order by QueryCount desc
| take 10000

            This query is an attempt to remove search queries where the first page in the session is the search query
            indicating that it was a non-organic search.

let minTimestamp = todatetime('2019-07-02T18:57:00Z');
pageViews
| where timestamp > minTimestamp
| where session_Id != ""
| summarize min(timestamp), min(url) by session_Id
| project session_Id, firstPageViewTimestamp = min_timestamp, firstPageViewUrl = min_url 
| join kind=inner (
    pageViews
    | where timestamp > minTimestamp
    | where session_Id != ""
    | extend parsedUrl = parse_url(url)
    | where parsedUrl.Path == "/packages"
    | extend searchQuery = url_decode(trim("\\s", tostring(parsedUrl["Query Parameters"]["q"])))
    | extend page = tostring(parsedUrl["Query Parameters"]["page"])
    | extend prerel = tolower(tostring(parsedUrl["Query Parameters"]["prerel"])) != "false"
    | extend page = iff(page == "", 1, toint(page))
    | where page > 0
    | project session_Id, timestamp, searchQuery, page, prerel, url
) on session_Id
| project timestamp, session_Id, firstPageViewTimestamp, firstPageViewUrl, searchQuery, page, prerel, url
| join kind=innerunique (
    customMetrics
    | where timestamp > minTimestamp
    | where name == "BrowserSearchPage"
    | project session_Id
) on session_Id
| project timestamp, session_Id, firstPageViewTimestamp, firstPageViewUrl, searchQuery, page, prerel, url
| where page == 1
| where searchQuery != ""
| summarize searchCount = count(), nonLandingSearchCount = countif(timestamp != firstPageViewTimestamp) by searchQuery
| order by nonLandingSearchCount desc
| project Query = searchQuery, QueryCount = nonLandingSearchCount
| take 10000

            */

        public static IReadOnlyDictionary<string, int> Read(string path)
        {
            using (var fileStream = File.OpenRead(path))
            using (var streamReader = new StreamReader(fileStream))
            using (var csvReader = new CsvReader(streamReader))
            {
                return csvReader
                    .GetRecords<Record>()
                    .Where(x => !string.IsNullOrEmpty(x.Query))
                    .ToDictionary(x => x.Query, x => x.QueryCount);
            }
        }

        private class Record
        {
            public string Query { get; set; }
            public int QueryCount { get; set; }
        }
    }
}
