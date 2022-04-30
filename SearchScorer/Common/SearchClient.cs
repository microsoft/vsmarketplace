using System;
using System.Collections.Concurrent;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
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
            //var queryString = HttpUtility.ParseQueryString(string.Empty);
            query = "python";

            var uriBuilder = new UriBuilder(baseUrl)
            {
                //Path = "/query",

                //Query = "{\"assetTypes\":null,\"filters\":[{\"criteria\":[{\"filterType\":10,\"value\":\"python\"}]," +
                //"\"direction\":2,\"pageSize\":100,\"pageNumber\":1,\"sortBy\":0,\"sortOrder\":0,\"pagingToken\":null}],\"flags\":103}"

            };

            var queryStr = "{\"filters\":[{\"criteria\":[{\"filterType\":10,\"value\":\"" + query + "\"}, {\"filterType\":8,\"value\":\"Microsoft.VisualStudio.Code\"}]," +
                "\"direction\":0,\"pageSize\":50,\"pageNumber\":1,\"sortBy\":6,\"sortOrder\":0,\"pagingToken\":null}],\"flags\":947, \"assetTypes\":[]}";

            var requestUri = uriBuilder.Uri; //baseUrl;//

            var lazyTask = _cache.GetOrAdd(requestUri, _ => new Lazy<Task<SearchResponse>>(
                async () =>
                {
                    var attempt = 0;
                    while (true)
                    {
                        attempt++;
                        try
                        {
                            using (var request = new HttpRequestMessage(HttpMethod.Post, requestUri))
                            {
                                //request.Headers.Add("Content-Type", "application/json");
                                //request.Content = queryStr;// new StringContent(queryStr, Encoding.UTF8, "application/json"); ;
                                request.Content = new StringContent(queryStr);
                                //_httpClient.DefaultRequestHeaders.Add("Content-Type", "application/json; charset=utf-8");
                                request.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                                request.Content.Headers.ContentType.CharSet = "utf-8";

                                using (var response = await _httpClient.SendAsync(request))
                                {
                                    response.EnsureSuccessStatusCode();
                                    var json = await response.Content.ReadAsStringAsync();
                                    return JsonConvert.DeserializeObject<SearchResponse>(json);
                                }
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
