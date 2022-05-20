using System;
using System.Collections.Generic;
using System.Linq;
using SearchScorer.Common;

namespace SearchScorer.IREvalutation
{
    public static class RelevancyScoreBuilder
    {
        /// <summary>
        /// The number possible relevancy scores minus one. There are a lot of options, the simplest being a binary
        /// option set:
        /// 
        ///    { relevant, not relevant }
        ///   
        /// We'll take a slightly more complex range:
        /// 
        ///    { perfect, excellent, good, fair, bad }
        ///    
        /// This is mentioned by Oliver Chapell's "Expected Reciprocal Rank for Graded Relevance" paper. He worked for
        /// Yahoo Labs so it's good enough for me.
        /// </summary>
        public const int MaximumRelevancyScore = 4;

        public static IReadOnlyList<SearchQueryRelevancyScores<CuratedSearchQuery>> FromCuratedSearchQueriesCsv(SearchScorerSettings settings)
        {
            var queries = CuratedSearchQueriesCsvReader.Read(settings.CuratedSearchQueriesCsvPath);
            return FromCuratedSearchQueries(queries);
        }

        public static IReadOnlyList<SearchQueryRelevancyScores<CuratedSearchQuery>> FromClientCuratedSearchQueriesCsv(SearchScorerSettings settings)
        {
            var queries = CuratedSearchQueriesCsvReader.Read(
                settings.ClientCuratedSearchQueriesCsvPath,
                settings.CuratedSearchQueriesCsvPath);
            return FromCuratedSearchQueries(queries);
        }

        private static IReadOnlyList<SearchQueryRelevancyScores<CuratedSearchQuery>> FromCuratedSearchQueries(IReadOnlyList<CuratedSearchQuery> queries)
        {
            var output = new List<SearchQueryRelevancyScores<CuratedSearchQuery>>();
            foreach (var query in queries)
            {
                output.Add(new SearchQueryRelevancyScores<CuratedSearchQuery>(
                    query.SearchQuery,
                    query.PackageIdToScore,
                    query));
            }

            return output;
        }

        public static IReadOnlyList<SearchQueryRelevancyScores<FeedbackSearchQuery>> FromFeedbackSearchQueriesCsv(SearchScorerSettings settings)
        {
            var output = new List<SearchQueryRelevancyScores<FeedbackSearchQuery>>();
            var feedbackSearchQueries = FeedbackSearchQueriesCsvReader.Read(settings.FeedbackSearchQueriesCsvPath);
            foreach (var feedback in feedbackSearchQueries)
            {
                // Give expected package IDs the maximum relevancy score.
                var scores = feedback
                    .MostRelevantPackageIds
                    .ToDictionary(x => x, x => MaximumRelevancyScore, StringComparer.OrdinalIgnoreCase);;

                output.Add(new SearchQueryRelevancyScores<FeedbackSearchQuery>(
                    feedback.SearchQuery,
                    scores,
                    feedback));
            }

            return output;
        }

        public static IReadOnlyList<SearchQueryRelevancyScores<SearchQueryWithSelections>> FromTopSearchSelectionsCsv(string path)
        {
            // The goal here is to take the frequency that a package ID was clicked for each search query and somehow
            // use this frequency compared to other clicked package IDs to assign a relevancy score. This is of course
            // only an educated guess since people may be clicking results because today's relevancy algorithm puts
            // them at the not because they are actually good results.
            //
            // This mapping must take a package ID frequency and map it to an integer in the range:
            //
            //   [0, MaximumRelevancyScore]
            //
            // We do this by taking a ratio of clickCount / maxClickCount where clickCount is the number of times a 
            // package ID was clicked for a given search query and maxClickCount is the click count of the package ID
            // that was clicked the most. We then bucket that ratio into into "MaximumRelevancyScore" + 1 evenly-sized
            // buckets covering the range [0.00, 1.00].
            // 
            // For example, suppose MaximumRelevancyScore is 4, the search query is "nuget", NuGet.Versioning has 601
            // clicks, NuGet.Frameworks has 501 clicks, and NuGet.Core has 79 clicks. The mapping of ratio buckets
            // to resulting score are:
            //
            //   [0.00, 0.20) => 0
            //   [0.20, 0.40) => 1
            //   [0.40, 0.60) => 2
            //   [0.60, 0.80) => 3
            //   [0.80, 1.00] => 4
            //
            // The highest click count is 601.
            //
            // NuGet.Versioning's score will be: 601 / 601 = 1.00 => 4.
            // NuGet.Framework's score will be: 501 / 601 = 0.83 => 4.
            // NuGet.Core's score will be: 79 / 601 = 0.13 => 0.

            var firstBucketUpperBound = 1.0 / (MaximumRelevancyScore + 1);

            var output = new List<SearchQueryRelevancyScores<SearchQueryWithSelections>>();
            var topSearchSelections = TopSearchSelectionsCsvReader.Read(path);
            foreach (var searchQueryWithSelections in topSearchSelections)
            {
                var maxClickCount = searchQueryWithSelections.Selections.Max(x => x.Count);
                var packageIdToScore = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
                foreach (var selection in searchQueryWithSelections.Selections)
                {
                    var clickCount = selection.Count;
                    var ratio = (double)clickCount / maxClickCount;
                    var score = (int)Math.Ceiling(ratio / firstBucketUpperBound) - 1;
                    packageIdToScore.Add(selection.PackageId, score);
                }

                output.Add(new SearchQueryRelevancyScores<SearchQueryWithSelections>(
                    searchQueryWithSelections.SearchQuery,
                    packageIdToScore,
                    searchQueryWithSelections));
            }

            return output;
        }
    }
}
