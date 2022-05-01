using SearchScorer.Common;

namespace SearchScorer.IREvalutation
{
    public class RelevancyScoreResult
    {
        public RelevancyScoreResult(double resultScore, SearchQueryRelevancyScores input, ExtensionQueryResult response)
        {
            ResultScore = resultScore;
            Input = input;
            Response = response;
        }

        public double ResultScore { get; }
        public SearchQueryRelevancyScores Input { get; }
        public ExtensionQueryResult Response { get; }
    }

    public class RelevancyScoreResult<TScoreSource> : RelevancyScoreResult
    {
        public RelevancyScoreResult(
            double resultScore,
            SearchQueryRelevancyScores<TScoreSource> input,
            ExtensionQueryResult response) : base(resultScore, input, response)
        {
            Input = input;
        }

        public new SearchQueryRelevancyScores<TScoreSource> Input { get; }
    }
}
