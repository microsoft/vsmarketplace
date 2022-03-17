using System;
using System.Text.RegularExpressions;

namespace SearchScorer.Common
{
    public static class WildcardUtility
    {
        public static Regex GetPackageIdWildcareRegex(string packageIdPattern)
        {
            return new Regex(WildcardToRegular(packageIdPattern), RegexOptions.IgnoreCase);
        }

        public static bool IsWildcard(string value)
        {
            return value.Contains("?") || value.Contains("*");
        }

        /// <summary>
        /// Source: https://stackoverflow.com/a/30300521
        /// </summary>
        private static string WildcardToRegular(string value)
        {
            return "^" + Regex.Escape(value).Replace("\\?", ".").Replace("\\*", ".*") + "$";
        }

        public static bool Matches(string packageId, string packageIdPattern)
        {
            if (!IsWildcard(packageIdPattern))
            {
                return StringComparer.OrdinalIgnoreCase.Equals(packageId, packageIdPattern);
            }

            return GetPackageIdWildcareRegex(packageIdPattern).IsMatch(packageId);
        }
    }
}
