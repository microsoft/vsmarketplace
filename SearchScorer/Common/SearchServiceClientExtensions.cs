using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Azure.Search;
using Microsoft.Azure.Search.Models;
using Index = Microsoft.Azure.Search.Models.Index;

namespace SearchScorer.Common
{
    public static class SearchServiceClientExtensions
    {
        private const string ScoringProfileName = "nuget_scoring_profile";

        private const string PackageIdFieldName = "packageId";
        private const string TokenizedPackageIdFieldName = "tokenizedPackageId";
        private const string TagsFieldName = "tags";

        private const string DownloadScoreBoostName = "downloadScore";

        public static async Task<Index> GetNuGetSearchIndexAsync(this ISearchServiceClient client, SearchScorerSettings settings)
        {
            var index = await client.Indexes.GetAsync(settings.AzureSearchIndexName);
            index.EnsureValidNuGetSearchIndex(settings);

            return index;
        }

        public static async Task UpdateNuGetSearchIndexAsync(
            this ISearchServiceClient client,
            SearchScorerSettings settings,
            Index index,
            double packageIdWeight,
            double tokenizedPackageIdWeight,
            double tagsWeight,
            double downloadScoreBoost)
        {
            Console.WriteLine($"Updating Azure Search service '{settings.AzureSearchServiceName}', index '{settings.AzureSearchIndexName}'");

            Console.WriteLine($"Package ID weight: {packageIdWeight}");
            Console.WriteLine($"Tokenized package ID weight: {tokenizedPackageIdWeight}");
            Console.WriteLine($"Tags weight: {tagsWeight}");
            Console.WriteLine($"Download score boost: {downloadScoreBoost}");

            index.EnsureValidNuGetSearchIndex(settings);

            var indexFieldWeights = index.ScoringProfiles[0].TextWeights.Weights;
            var downloadScoreFunction = index.ScoringProfiles[0].Functions[0];

            indexFieldWeights.Clear();
            indexFieldWeights[PackageIdFieldName] = packageIdWeight;
            indexFieldWeights[TokenizedPackageIdFieldName] = tokenizedPackageIdWeight;
            indexFieldWeights[TagsFieldName] = tagsWeight;

            downloadScoreFunction.Boost = downloadScoreBoost;

            await client.Indexes.CreateOrUpdateAsync(index);

            Console.WriteLine($"Updated Azure Search service '{settings.AzureSearchServiceName}', index '{settings.AzureSearchIndexName}'");
        }

        private static void EnsureValidNuGetSearchIndex(this Index index, SearchScorerSettings settings)
        {
            if (index.ScoringProfiles.Count != 1 || index.ScoringProfiles[0].Name != ScoringProfileName)
            {
                throw new InvalidOperationException(
                    $"Azure Search index '{settings.AzureSearchIndexName}' should have one scoring profile named '{ScoringProfileName}'");
            }

            var scoringProfile = index.ScoringProfiles[0];
            if (scoringProfile.Functions.Count != 1 || scoringProfile.Functions[0].FieldName != DownloadScoreBoostName)
            {
                throw new InvalidOperationException(
                    $"Azure Search index '{settings.AzureSearchIndexName}' should have one scoring function on the '{DownloadScoreBoostName}' field");
            }
        }
    }
}
