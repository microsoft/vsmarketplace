// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;

namespace SearchScorer.Common
{
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static class ArgumentUtility
    {
        /// <summary>
        /// Throw an exception if the object is null.
        /// </summary>
        /// <param name="var">the object to check</param>
        /// <param name="varName">the variable or parameter name to display</param>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static void CheckForNull(object var, string varName)
        {
            if (var == null)
            {
                throw new ArgumentNullException(varName);
            }
        }

        /// <summary>
        /// Throw an exception if a string is null or empty.
        /// </summary>
        /// <param name="stringVar">string to check</param>
        /// <param name="stringVarName">the variable or parameter name to display</param>
        public static void CheckStringForNullOrEmpty(string stringVar, string stringVarName)
        {
            CheckForNull(stringVar, stringVarName);
            if (stringVar.Length == 0)
            {
                throw new ArgumentException("The string must have at least one character.", stringVarName);
            }
        }

        //********************************************************************************************
        /// <summary>
        /// Throw an exception if a string is null, empty, or consists only of white-space characters.
        /// </summary>
        /// <param name="stringVar">string to check</param>
        /// <param name="stringVarName">the variable or parameter name to display</param>
        //********************************************************************************************
        public static void CheckStringForNullOrWhiteSpace(string stringVar, string stringVarName)
        {
            CheckForNull(stringVar, stringVarName);
            if (string.IsNullOrWhiteSpace(stringVar) == true)
            {
                throw new ArgumentException("The string must have at least one non-white-space character.", stringVarName);
            }
        }

        /// <summary>
        /// Converts comma separated values to camelcase comma separated value
        /// Example: ConvertFlagsToString("Public, BuiltIn") to
        /// "public, builtIn"
        /// </summary>
        /// <param name="s"></param>
        /// <returns></returns>
        public static string ConvertFlagsToString(this string s)
        {
            List<string> response = new List<string>();
            var flags = s.Split(",")
                .Select(x => x.Trim());

            foreach (var flag in flags)
            {
                response.Add(flag[0].ToString().ToLowerInvariant() + flag.Substring(1));
            }

            return String.Join(", ", response.ToArray());
        }
    }
}
