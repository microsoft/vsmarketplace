namespace SearchScorer.Common
{
    public class SearchSelectionCount
    {
        public SearchSelectionCount(string packageId, int count)
        {
            PackageId = packageId;
            Count = count;
        }

        public string PackageId { get; }
        public int Count { get; }
    }
}
