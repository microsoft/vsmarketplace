// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;

namespace SearchScorer.Common
{
    [Flags]
    public enum PublisherFlags
    {
        /// <summary>
        /// This should never be returned, it is used to represent a publisher
        /// who's flags haven't changed during update calls.
        /// </summary>
        UnChanged = 0x40000000,

        /// <summary>
        /// No flags exist for this publisher.
        /// </summary>
        None = 0x0000,

        /// <summary>
        /// The Disabled flag for a publisher means the publisher can't be changed
        /// and won't be used by consumers, this extends to extensions owned by
        /// the publisher as well. The disabled flag is managed by the service and 
        /// can't be supplied by the Extension Developers.
        /// </summary>
        Disabled = 0x0001,

        /// <summary>
        /// A verified publisher is one that Microsoft has done some review of 
        /// and ensured the publisher meets a set of requirements. The 
        /// requirements to become a verified publisher are not listed here.
        /// 
        /// They can be found in public documentation (TBD).
        /// </summary>
        Verified = 0x0002,

        /// <summary>
        /// A Certified publisher is one that is Microsoft verified and in addition
        /// meets a set of requirements for its published extensions. The 
        /// requirements to become a certified publisher are not listed here.
        /// 
        /// They can be found in public documentation (TBD).
        /// </summary>
        Certified = 0x0004,

        /// <summary>
        /// This is the set of flags that can't be supplied by the developer and
        /// is managed by the service itself.
        /// </summary>
        ServiceFlags = (Disabled | Verified | Certified)
    }
}
