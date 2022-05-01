using System.Collections.Generic;

namespace SearchScorer.Common
{
    public class Search1Response
    {
        public int TotalHits { get; set; }
        public List<SearchResult> Data { get; set; }
    }
}
