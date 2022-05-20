// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace SearchScorer.Common
{
    /// <summary>
    /// PagingDirection is used to define which set direction to move the returned
    /// result set based on a previous query.
    /// </summary>
    public enum PagingDirection
    {
        /// <summary>
        /// Backward will return results from earlier in the resultset.
        /// </summary>
        Backward = 1,

        /// <summary>
        /// Forward will return results from later in the resultset.
        /// </summary>
        Forward = 2,
    }

    /// <summary>
    /// One condition in a QueryFilter.
    /// </summary>
    public class FilterCriteria
    {
        /// The FilterType defines how the filters are to be applied to the
        /// extensions. See the documentation on the filter type to understand
        /// how the filters are matched.
        /// </summary>
        public Int32 FilterType { get; set; }

        /// <summary>
        /// The value used in the match based on the filter type.
        /// </summary>
        public String Value { get; set; }
    }

    /// <summary>
    /// A filter used to define a set of extensions to return during a query.
    /// </summary>
    public class QueryFilter
    {
        /// <summary>
        /// The filter values define the set of values in this query. They are 
        /// applied based on the QueryFilterType.
        /// </summary>
        public List<FilterCriteria> Criteria { get; set; }

        /// <summary>
        /// The page size defines the number of results the caller wants for this
        /// filter. The count can't exceed the overall query size limits.
        /// </summary>
        public Int32 PageSize { get; set; }

        /// <summary>
        /// The page number requested by the user. If not provided 1 is assumed by default.
        /// </summary>
        public Int32 PageNumber { get; set; }

        /// <summary>
        /// Defines the type of sorting to be applied on the results. 
        /// The page slice is cut of the sorted results only.
        /// </summary>
        public Int32 SortBy { get; set; }

        /// <summary>
        /// Defines the order of sorting, 1 for Ascending, 2 for Descending, else default ordering based on the SortBy value
        /// </summary>
        public Int32 SortOrder { get; set; }

        /// <summary>
        /// The paging token is a distinct type of filter and the other filter 
        /// fields are ignored. The paging token represents the continuation of
        /// a previously executed query. The information about where in the result
        /// and what fields are being filtered are embedded in the token.
        /// </summary>
        public String PagingToken { get; set; }

        /// <summary>
        /// The PagingDirection is applied to a paging token if one exists. If
        /// not the direction is ignored, and Forward from the start of the 
        /// resultset is used. Direction should be left out of the request unless 
        /// a paging token is used to help prevent future issues.
        /// </summary>
        public PagingDirection Direction { get; set; }

        /// <summary>
        /// This is an internal identifier used to correlate results back to the
        /// result from the SQL Query.
        /// </summary>
        // internal Int32 QueryIndex { get; set; }

        /// <summary>
        /// This is an internal parameter to not apply max page size restriction to the 
        /// query
        /// </summary>
        // internal bool ForcePageSize { get; set; }

        /// <summary>
        /// This is an internal parameter to specify that if true, cache should not be used to 
        /// provide the results of the query
        /// </summary>
        // internal bool DoNotUseCache { get; set; }
    }
}
