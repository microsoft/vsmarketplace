// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;

namespace SearchScorer.Common
{
    public class ExtensionStatistic
    {
        public String StatisticName { get; set; }

        public Double Value { get; set; }

        public ExtensionStatistic ShallowCopy()
        {
            return (ExtensionStatistic)this.MemberwiseClone();
        }
    }
}
