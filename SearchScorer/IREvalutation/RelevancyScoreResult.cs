using SearchScorer.Common;

namespace SearchScorer.IREvalutation
{
    public class RelevancyScoreResult
    {
        public RelevancyScoreResult(double resultScore, SearchQueryRelevancyScores input, SearchResponse response)
        {
            ResultScore = resultScore;
            Input = input;
            Response = response;
        }

        public double ResultScore { get; }
        public SearchQueryRelevancyScores Input { get; }
        public SearchResponse Response { get; }
    }

    public class RelevancyScoreResult<TScoreSource> : RelevancyScoreResult
    {
        public RelevancyScoreResult(
            double resultScore,
            SearchQueryRelevancyScores<TScoreSource> input,
            SearchResponse response) : base(resultScore, input, response)
        {
            Input = input;
        }

        public new SearchQueryRelevancyScores<TScoreSource> Input { get; }
    }
}
