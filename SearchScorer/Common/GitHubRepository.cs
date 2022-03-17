using System.Collections.Generic;
using Newtonsoft.Json;

namespace SearchScorer.Common
{
    public class GitHubRepository
    {
        [JsonConstructor]
        public GitHubRepository(string url, int stars, string id, string description, IReadOnlyList<string> dependencies)
        {
            Url = url;
            Stars = stars;
            Id = id;
            Description = description;
            Dependencies = dependencies;
        }

        public string Url { get; }
        public int Stars { get; }
        public string Id { get; }
        public string Description { get; }
        public IReadOnlyList<string> Dependencies { get; }
    }
}
