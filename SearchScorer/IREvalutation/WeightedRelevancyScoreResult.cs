namespace SearchScorer.IREvalutation
{
    public class WeightedRelevancyScoreResult<T>
    {
        public WeightedRelevancyScoreResult(RelevancyScoreResult<T> result, double weight)
        {
            Result = result;
            Weight = weight;
        }

        public double Score => Weight * Result.ResultScore;
        public RelevancyScoreResult<T> Result { get; }
        public double Weight { get; }
    }
}
