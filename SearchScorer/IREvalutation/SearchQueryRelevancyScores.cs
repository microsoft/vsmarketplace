using System.Collections.Generic;

namespace SearchScorer.IREvalutation
{
    public class SearchQueryRelevancyScores
    {
        public SearchQueryRelevancyScores(string searchQuery, IReadOnlyDictionary<string, int> packageIdToScore)
        {
            SearchQuery = searchQuery;
            PackageIdToScore = packageIdToScore;
        }

        public string SearchQuery { get; }
        public IReadOnlyDictionary<string, int> PackageIdToScore { get; }
    }

    public class SearchQueryRelevancyScores<TSource> : SearchQueryRelevancyScores
    {
        public SearchQueryRelevancyScores(
            string searchQuery,
            IReadOnlyDictionary<string, int> packageIdToScore,
            TSource source) : base(searchQuery, packageIdToScore)
        {
            Source = source;
        }

        public TSource Source { get; }
    }
}
