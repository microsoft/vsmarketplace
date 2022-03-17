using System.Collections.Generic;
using System.Linq;

namespace SearchScorer.IREvalutation
{
    public class SearchQueriesReport<T>
    {
        public SearchQueriesReport(IReadOnlyList<WeightedRelevancyScoreResult<T>> queries)
        {
            Queries = queries;
        }

        public double Score => Queries.Sum(x => x.Score);
        public IReadOnlyList<WeightedRelevancyScoreResult<T>> Queries { get; }
    }
}
