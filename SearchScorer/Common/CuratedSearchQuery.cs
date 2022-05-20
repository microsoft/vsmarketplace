using System.Collections.Generic;

namespace SearchScorer.Common
{
    public class CuratedSearchQuery
    {
        public CuratedSearchQuery(string searchQuery, IReadOnlyDictionary<string, int> packageIdToScore)
        {
            SearchQuery = searchQuery;
            PackageIdToScore = packageIdToScore;
        }

        public string SearchQuery { get; }
        public IReadOnlyDictionary<string, int> PackageIdToScore { get; }
    }
}
