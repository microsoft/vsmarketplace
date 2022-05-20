using SearchScorer.Common;
using SearchScorer.IREvalutation;

ServicePointManager.DefaultConnectionLimit = 64;

var assemblyDir = Path.GetDirectoryName(Environment.CurrentDirectory);
assemblyDir = Path.Combine(assemblyDir, "files");

var settings = new SearchScorerSettings
{
    ControlBaseUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery", //TODO: Add marketplace url
    TreatmentBaseUrl = "https://marketplace.vsallin.net/_apis/public/gallery/extensionquery",
    //ControlBaseUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=6.0-preview.1", //TODO: Add marketplace url
    //TreatmentBaseUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=6.0-preview.1",

    CuratedSearchQueriesCsvPath = @"curatedsearchqueries.csv",
    TopSearchQueriesCsvPath = @"topsearchqueries.csv",
    TopSearchSelectionsCsvPath = @"topsearchselections.csv",

    TopClientSearchQueriesCsvPath = @"topclientsearchqueries.csv",
    GoogleAnalyticsSearchReferralsCsvPath = @"GoogleAnalyticsSearchReferrals.csv",

    ClientCuratedSearchQueriesCsvPath = @"curatedsearchqueries.csv",
    FeedbackSearchQueriesCsvPath = @"feedbacksearchqueries.csv",

    PackageIdWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    TokenizedPackageIdWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    TagsWeights = CreateRange(lower: 1, upper: 10, increments: 3),
    DownloadWeights = CreateRange(lower: 1, upper: 10, increments: 3)
};

using (var httpClientHandler = new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip })
using (var httpClient = new HttpClient())
{
    //if (args.Length == 0 || args[0] == "score")
    {
        httpClient.DefaultRequestHeaders.TryAddWithoutValidation("Content-Type", "application/json; charset=utf-8");
        await RunScoreCommandAsync(settings, httpClient);
    }
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