using System.Collections.Generic;

namespace SearchScorer.Common
{
    public class SearchResponse
    {
        public int TotalHits { get; set; }
        public List<SearchResult> Data { get; set; }
    }
}
