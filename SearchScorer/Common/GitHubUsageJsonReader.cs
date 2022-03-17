using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;

namespace SearchScorer.Common
{
    public static class GitHubUsageJsonReader
    {
        public static IReadOnlyList<GitHubRepository> Read(string path)
        {
            using (var fileStream = File.OpenRead(path))
            using (var streamReader = new StreamReader(fileStream))
            using (var jsonReader = new JsonTextReader(streamReader))
            {
                return new JsonSerializer().Deserialize<List<GitHubRepository>>(jsonReader);
            }
        }
    }
}
