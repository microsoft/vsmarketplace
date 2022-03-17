using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using NuGet.Packaging;

namespace SearchScorer.Common
{
    public class PackageIdPatternValidator
    {
        private static readonly char[] Separators = new[] { '.', '-', '_' };

        private readonly SearchClient _searchClient;

        public PackageIdPatternValidator(SearchClient searchClient)
        {
            _searchClient = searchClient;
        }

        public async Task<List<string>> GetNonExistentPackageIdsAsync(IEnumerable<string> packageIds, SearchScorerSettings settings)
        {
            var distinct = packageIds.Distinct(StringComparer.OrdinalIgnoreCase);
            var work = new ConcurrentBag<string>(distinct);
            var output = new ConcurrentBag<string>();

            var workers = Enumerable
                .Range(0, 16)
                .Select(async workerId =>
                {
                    while (work.TryTake(out var packageIdPattern))
                    {
                        var exists = await DoesPackageIdExistAsync(packageIdPattern, settings);
                        Console.Write(".");
                        if (!exists)
                        {
                            output.Add(packageIdPattern);
                        }
                    }
                })
                .ToList();

            await Task.WhenAll(workers);

            return output
                .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        public async Task<bool> DoesPackageIdExistAsync(
            string packageIdPattern,
            SearchScorerSettings settings)
        {
            Task<bool> controlExistsTask;
            Task<bool> treatmentExistsTask;

            if (PackageIdValidator.IsValidPackageId(packageIdPattern))
            {
                var query = $"packageid:{packageIdPattern}";
                controlExistsTask = DoesPackageIdExistInQueryAsync(packageIdPattern, settings.ControlBaseUrl, query, take: 1);
                treatmentExistsTask = DoesPackageIdExistInQueryAsync(packageIdPattern, settings.TreatmentBaseUrl, query, take: 1);

            }
            else if (packageIdPattern.EndsWith("*"))
            {
                var prefix = packageIdPattern.Substring(0, packageIdPattern.Length - 1).TrimEnd(Separators);
                if (!PackageIdValidator.IsValidPackageId(prefix))
                {
                    throw new ArgumentException($"The package ID '{packageIdPattern}' looks like a pattern but the part before the wildcard is not a valid package ID.");
                }

                var pieces = prefix
                    .Split(Separators)
                    .Where(x => !string.IsNullOrWhiteSpace(x));
                var query = string.Join(" ", pieces);
                controlExistsTask = DoesPackageIdExistInQueryAsync(packageIdPattern, settings.ControlBaseUrl, query, take: 1000);
                treatmentExistsTask = DoesPackageIdExistInQueryAsync(packageIdPattern, settings.TreatmentBaseUrl, query, take: 1000);
            }
            else
            {
                throw new NotSupportedException();
            }

            await Task.WhenAll(controlExistsTask, treatmentExistsTask);

            if (controlExistsTask.Result != treatmentExistsTask.Result)
            {
                throw new ArgumentNullException(
                    $"The package ID '{packageIdPattern}' has inconsistent availability. " +
                    $"Exists in control: {controlExistsTask.Result}. " +
                    $"Exists in treatment: {treatmentExistsTask.Result}.");
            }

            return controlExistsTask.Result;
        }

        private async Task<bool> DoesPackageIdExistInQueryAsync(
            string packageId,
            string baseUrl,
            string query,
            int take)
        {
            var response = await _searchClient.SearchAsync(baseUrl, query, take);
            return response.Data.Any(x => WildcardUtility.Matches(x.Id, packageId));
        }
    }
}
