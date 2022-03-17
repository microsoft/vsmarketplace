namespace SearchScorer.Common
{
    public enum Bucket
    {
        Acronym,
        Author,
        CommonName,
        ExactMatch,
        Freshness,
        MultiTerm,
        PartialId,
        Prefix,
        Tags,
        TopDownloads,
    }
}
