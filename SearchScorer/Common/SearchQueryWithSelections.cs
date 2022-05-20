using System.Collections.Generic;

namespace SearchScorer.Common
{
    public class SearchQueryWithSelections
    {
        public SearchQueryWithSelections(string searchQuery, IReadOnlyList<SearchSelectionCount> selections)
        {
            SearchQuery = searchQuery;
            Selections = selections;
        }

        public string SearchQuery { get; }
        public IReadOnlyList<SearchSelectionCount> Selections { get; }
    }
}
