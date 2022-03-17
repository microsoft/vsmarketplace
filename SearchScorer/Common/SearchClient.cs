using System;
using System.Collections.Concurrent;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web;
using Newtonsoft.Json;

namespace SearchScorer.Common
{
    public class SearchClient
    {
        private readonly HttpClient _httpClient;
        private readonly ConcurrentDictionary<Uri, Lazy<Task<SearchResponse>>> _cache = new ConcurrentDictionary<Uri, Lazy<Task<SearchResponse>>>();

        public SearchClient(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<SearchResponse> SearchAsync(string baseUrl, string query, int take)
        {
            var queryString = HttpUtility.ParseQueryString(string.Empty);
            queryString["q"] = query;
            queryString["prerelease"] = "true";
            queryString["semVerLevel"] = "2.0.0";
            queryString["debug"] = "true";
            queryString["take"] = take.ToString();

            var uriBuilder = new UriBuilder(baseUrl)
            {
                Path = "/query",
                Query = queryString.ToString(),
            };

            var requestUri = uriBuilder.Uri;

            var lazyTask = _cache.GetOrAdd(requestUri, _ => new Lazy<Task<SearchResponse>>(
                async () =>
                {
                    var attempt = 0;
                    while (true)
                    {
                        attempt++;
                        try
                        {
                            using (var request = new HttpRequestMessage(HttpMethod.Get, requestUri))
                            using (var response = await _httpClient.SendAsync(request))
                            {
                                response.EnsureSuccessStatusCode();
                                var json = await response.Content.ReadAsStringAsync();
                                return JsonConvert.DeserializeObject<SearchResponse>(json);
                            }
                        }
                        catch (Exception ex) when (attempt < 3)
                        {
                            Console.WriteLine($"[ WARN ] Search query '{query}' failed: " + ex.Message);
                            await Task.Delay(TimeSpan.FromSeconds(1));
                        }
                    }
                }));

            return await lazyTask.Value;
        }
    }
}
