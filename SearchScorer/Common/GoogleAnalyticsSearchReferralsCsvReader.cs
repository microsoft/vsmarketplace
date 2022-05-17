using System;
using System.Collections.Generic;
using System.IO;
using System.Web;
using CsvHelper;

namespace SearchScorer.Common
{
    public class GoogleAnalyticsSearchReferralsCsvReader
    {
        public static IReadOnlyDictionary<string, int> Read(string path)
        {
            using (var fileStream = File.OpenRead(path))
            using (var streamReader = new StreamReader(fileStream))
            using (var csvReader = new CsvReader(streamReader))
            {
                csvReader.Configuration.HasHeaderRecord = true;
                csvReader.Configuration.IgnoreBlankLines = true;

                var output = new Dictionary<string, int>();

                csvReader.Read(); // comment
                csvReader.Read(); // comment 
                csvReader.Read(); // comment
                csvReader.Read(); // comment
                csvReader.Read(); // comment
                csvReader.Read(); // empty line
                csvReader.ReadHeader();

                while (csvReader.Read())
                {
                    var landingPage = csvReader.GetField<string>("Landing Page");
                    var landingUri = new Uri("http://example" + landingPage);
                    var queryString = HttpUtility.ParseQueryString(landingUri.Query);

                    // Skip queries where we are not hitting the first page.
                    if (int.TryParse(queryString["page"], out var page) && page != 1)
                    {
                        continue;
                    }

                    var searchTerm = csvReader.GetField<string>("Search Term");
                    var sessions = int.Parse(csvReader.GetField<string>("Sessions").Replace(",", string.Empty));

                    if (output.TryGetValue(searchTerm, out var existingSessions))
                    {
                        output[searchTerm] += sessions;
                    }
                    else
                    {
                        output.Add(searchTerm, sessions);
                    }
                }

                return output;
            }
        }

        private class Record
        {
            public string LandingPage { get; set; }
            public string SearcTerm { get; set; }
            public int Sessions { get; set; }
        }
    }
}
