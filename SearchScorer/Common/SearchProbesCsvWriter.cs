using System.Collections.Generic;
using System.IO;
using CsvHelper;

namespace SearchScorer.Common
{
    public static class SearchProbesCsvWriter
    {
        public static void Append(string path, SearchProbesRecord score)
        {
            var exists = File.Exists(path);

            using (var streamWriter = new StreamWriter(path, append: true))
            using (var csvWriter = new CsvWriter(streamWriter))
            {
                if (!exists)
                {
                    csvWriter.WriteHeader<SearchProbesRecord>();
                    csvWriter.NextRecord();
                }

                csvWriter.WriteRecord(score);
                streamWriter.WriteLine();
            }
        }
    }

    public class SearchProbeTest
    {
        public double PackageIdWeight { get; set; }
        public double TokenizedPackageIdWeight { get; set; }
        public double TagsWeight { get; set; }
        public double DownloadScoreBoost { get; set; }
    }

    public class SearchProbesRecord : SearchProbeTest
    {
        public double CuratedSearchScore { get; set; }
        public double ClientCuratedSearchScore { get; set; }
        public double FeedbackScore { get; set; }
    }
}
