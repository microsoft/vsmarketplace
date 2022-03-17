using System.Collections.Generic;
using System.IO;
using System.Linq;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class HashedSearchQueryCsvWriter
    {
        public static void Write(string key, string path, IReadOnlyDictionary<string, int> searchQueries)
        {
            using (var fileStream = new FileStream(path, FileMode.Create))
            using (var streamWriter = new StreamWriter(fileStream))
            using (var csvWriter = new CsvWriter(streamWriter))
            {
                csvWriter.WriteField("Query");
                csvWriter.WriteField("HashedQuery");
                csvWriter.WriteField("Count");
                csvWriter.NextRecord();

                var additional = new[] { string.Empty, " ", "  ", "   " };
                var localSearchQueries = new Dictionary<string, int>();
                foreach (var pair in searchQueries)
                {
                    localSearchQueries[pair.Key] = pair.Value;
                }

                foreach (var a in additional)
                {
                    if (!localSearchQueries.ContainsKey(a))
                    {
                        localSearchQueries[a] = 0;
                    }
                }

                var hasher = new Hasher(key);
                foreach (var pair in localSearchQueries.OrderByDescending(x => x.Value))
                {
                    csvWriter.WriteField(pair.Key);
                    csvWriter.WriteField(hasher.Hash(pair.Key));
                    csvWriter.WriteField(pair.Value);
                    csvWriter.NextRecord();
                }
            }
        }
    }
}
