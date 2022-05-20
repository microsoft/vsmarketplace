// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using Microsoft.Azure.Search.Models;

namespace SearchScorer.Common
{
    public class SearchRequest
    {
        public string SearchText { get; set; }
        public SearchParameters SearchParams { get; set; }
    }
}
