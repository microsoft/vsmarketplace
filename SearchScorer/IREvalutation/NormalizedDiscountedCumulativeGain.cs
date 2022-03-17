using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using SearchScorer.Common;

namespace SearchScorer.IREvalutation
{
    public class NormalizedDiscountedCumulativeGain
    {
        private readonly SearchClient _searchClient;

        public NormalizedDiscountedCumulativeGain(SearchClient searchClient)
        {
            _searchClient = searchClient;
        }

        public async Task<RelevancyScoreResult<T>> ScoreAsync<T>(
            SearchQueryRelevancyScores<T> query,
            string baseUrl,
            int resultsToEvaluate)
        {
            var response = await _searchClient.SearchAsync(
                baseUrl,
                query.SearchQuery,
                resultsToEvaluate);

            if (!query.PackageIdToScore.Any() || query.PackageIdToScore.Max(x => x.Value) == 0)
            {
                return new RelevancyScoreResult<T>(
                    0,
                    query,
                    response);
            }

            var patternToScorePairs = new List<KeyValuePair<Regex, int>>();
            foreach (var pair in query.PackageIdToScore.Where(x => x.Value > 0))
            {
                if (WildcardUtility.IsWildcard(pair.Key))
                {
                    patternToScorePairs.Add(new KeyValuePair<Regex, int>(
                        WildcardUtility.GetPackageIdWildcareRegex(pair.Key),
                        pair.Value));
                }
            }

            // Determine the score for each of the returns package IDs.
            var scores = new List<int>();
            for (var i = 0; i < response.Data.Count; i++)
            {
                var packageId = response.Data[i].Id;
                if (query.PackageIdToScore.TryGetValue(packageId, out var score))
                {
                    scores.Add(score);
                }
                else
                {
                    // It might be that the score map contains wildcards. Let's try those. Execute them from longest to
                    // shortest. This is a hueristic to perform the most specific ones first.
                    var match = false;
                    foreach (var pair in patternToScorePairs.OrderByDescending(x => x.Key.ToString().Length))
                    {
                        if (pair.Key.IsMatch(packageId))
                        {
                            scores.Add(pair.Value);
                            patternToScorePairs.Remove(pair);
                            match = true;
                            break;
                        }
                    }

                    if (match)
                    {
                        continue;
                    }

                    scores.Add(0);
                }
            }

            // Determine the ideal scores by taking the top N scores.
            var idealScores = query
                .PackageIdToScore
                .Select(x => x.Value)
                .OrderByDescending(x => x)
                .Take(resultsToEvaluate);

            // Calculate the NDCG.
            var resultScore = NDCG(scores, idealScores);

            if (resultScore > 1.0)
            {
                throw new InvalidOperationException("An NDCG score cannot be greater than 1.0. There's a bug!");
            }

            return new RelevancyScoreResult<T>(
                resultScore,
                query,
                response);
        }

        private static double NDCG(IEnumerable<int> scores, IEnumerable<int> idealScores)
        {
            return DCG(scores) / DCG(idealScores);
        }

        private static double DCG(IEnumerable<int> scores)
        {
            var sum = 0.0;
            var i = 1;

            foreach (var score in scores)
            {
                sum += score / Math.Log(i + 1, 2);
                i++;
            }

            return sum;
        }
    }
}
