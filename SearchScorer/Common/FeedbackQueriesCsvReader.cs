using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using CsvHelper.TypeConversion;

namespace SearchScorer.Common
{
    public static class FeedbackSearchQueriesCsvReader
    {
        public static IReadOnlyList<FeedbackSearchQuery> Read(string path)
        {
            using (var fileStream = File.OpenRead(path))
            using (var streamReader = new StreamReader(fileStream))
            using (var csvReader = new CsvReader(streamReader))
            {
                csvReader.Configuration.RegisterClassMap<RecordMap>();

                return csvReader
                    .GetRecords<Record>()
                    .Select(x => new FeedbackSearchQuery(
                        x.Source,
                        x.FeedbackDisposition,
                        x.SearchQuery,
                        x.Buckets,
                        x.MostRelevantPackageIds))
                    .ToList();
            }
        }

        private class Record
        {
            public SearchQuerySource Source { get; set; }
            public FeedbackDisposition FeedbackDisposition { get; set; }
            public string SearchQuery { get; set; }
            public List<Bucket> Buckets { get; set; }
            public List<string> MostRelevantPackageIds { get; set; }
        }

        private class RecordMap : ClassMap<Record>
        {
            public RecordMap()
            {
                Map(x => x.Source);
                Map(x => x.FeedbackDisposition);
                Map(x => x.SearchQuery);
                Map(x => x.Buckets).TypeConverter<PipeDelimitedListConverter<Bucket>>();
                Map(x => x.MostRelevantPackageIds).TypeConverter<PipeDelimitedListConverter<string>>();
            }
        }

        private class PipeDelimitedListConverter<T> : ITypeConverter
        {
            private static readonly Func<string, object> _converter;

            static PipeDelimitedListConverter()
            {
                if (typeof(T).IsEnum)
                {
                    _converter = x => Enum.Parse(typeof(T), x);
                }
                else if (typeof(T) == typeof(string))
                {
                    _converter = x => x;
                }
            }

            public object ConvertFromString(string text, IReaderRow row, MemberMapData memberMapData)
            {
                if (string.IsNullOrEmpty(text))
                {
                    return new List<T>();
                }

                var output = text
                    .Split('|')
                    .Select(x => x.Trim())
                    .Where(x => !string.IsNullOrEmpty(x))
                    .Select(x => (T)_converter(x))
                    .ToList();

                return output;
            }

            public string ConvertToString(object value, IWriterRow row, MemberMapData memberMapData)
            {
                if (value == null)
                {
                    return string.Empty;
                }

                var sb = new StringBuilder();
                var sequence = (IEnumerable<T>)value;
                foreach (var item in sequence)
                {
                    if (sb.Length > 0)
                    {
                        sb.Append(" | ");
                    }

                    sb.Append(item?.ToString());
                }

                return sb.ToString();
            }
        }
    }
}
