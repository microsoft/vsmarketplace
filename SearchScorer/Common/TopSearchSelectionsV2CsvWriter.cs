using System.Collections.Generic;
using System.IO;
using System.Linq;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class TopSearchSelectionsV2CsvWriter
    {
        public static void Write(string path, IEnumerable<SearchQueryWithSelections> selections)
        {
            using (var fileStream = new FileStream(path, FileMode.Create))
            using (var streamWriter = new StreamWriter(fileStream))
            using (var csvWriter = new CsvWriter(streamWriter))
            {
                csvWriter.WriteField("SearchQuery");
                csvWriter.WriteField("Total");
                csvWriter.WriteField("ID0");
                csvWriter.WriteField("S0");
                csvWriter.WriteField("ID1");
                csvWriter.WriteField("S1");
                csvWriter.WriteField("ID2");
                csvWriter.WriteField("S2");
                csvWriter.WriteField("ID3");
                csvWriter.WriteField("S3");
                csvWriter.WriteField("ID4");
                csvWriter.WriteField("S4");
                csvWriter.NextRecord();

                foreach (var ts in selections)
                {
                    csvWriter.WriteField(ts.SearchQuery);
                    csvWriter.WriteField(ts.Selections.Sum(x => x.Count));
                    foreach (var s in ts.Selections.OrderByDescending(x => x.Count).Take(5))
                    {
                        csvWriter.WriteField(s.PackageId);
                        csvWriter.WriteField(s.Count);
                    }

                    csvWriter.NextRecord();
                }
            }
        }
    }
}
