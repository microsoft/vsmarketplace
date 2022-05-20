using System.Collections.Generic;
using System.IO;
using System.Linq;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class GitHubUsageCsvWriter
    {
        public static void Write(string path, IReadOnlyList<GitHubRepository> repositories)
        {
            using (var fileStream = new FileStream(path, FileMode.Create))
            using (var streamWriter = new StreamWriter(fileStream))
            using (var csvWriter = new CsvWriter(streamWriter))
            {
                var records = repositories
                    .SelectMany(x => x
                        .Dependencies
                        .Select(d => new Record { RepositoryId = x.Id, Stars = x.Stars, Dependency = d }));

                csvWriter.WriteHeader<Record>();
                csvWriter.NextRecord();
                csvWriter.WriteRecords(records);
            }
        }

        private class Record
        {
            public string RepositoryId { get; set; }
            public int Stars { get; set; }
            public string Dependency { get; set; }
        }
    }
}
