using SearchScorer.Common;
using SearchScorer.IREvalutation;

ServicePointManager.DefaultConnectionLimit = 64;

var assemblyDir = Path.GetDirectoryName(Environment.CurrentDirectory);
assemblyDir = Path.Combine(assemblyDir, "files");

var settings = new SearchScorerSettings
{
    ControlBaseUrl = "", //TODO: Add marketplace url
    TreatmentBaseUrl = "",

    PackageIdWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    TokenizedPackageIdWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    TagsWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    DownloadWeights = CreateRange(lower: 1, upper: 10, increments: 3)
};

using (var httpClientHandler = new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip })
using (var httpClient = new HttpClient())
{
    if (args.Length == 0 || args[0] == "score")
        await RunScoreCommandAsync(settings, httpClient);
}

static async Task RunScoreCommandAsync(SearchScorerSettings settings, HttpClient httpClient)
{
    var searchClient = new SearchClient(httpClient);
    var scoreEvaluator = new RelevancyScoreEvaluator(searchClient);
    await scoreEvaluator.RunAsync(settings);
}

static IReadOnlyList<double> CreateRange(int lower, int upper, double increments)
{
    var count = (upper - lower) / increments + 1;
    return Enumerable
        .Range(0, (int)count)
        .Select(i => (i * increments + lower))
        .ToList();
}