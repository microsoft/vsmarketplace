using System;
using System.Security.Cryptography;
using System.Text;

namespace SearchScorer.Common
{
    public class Hasher
    {
        private class FipsHMACSHA256 : HMAC
        {
            public FipsHMACSHA256(byte[] key)
            {
                HashName = typeof(SHA256CryptoServiceProvider).AssemblyQualifiedName;
                HashSizeValue = 256;
                Key = key;
            }
        }

        private readonly HashAlgorithm _encrypter;

        public Hasher(string key)
        {
            _encrypter = new FipsHMACSHA256(Encoding.UTF8.GetBytes(key));
        }

        public string Hash(string value)
        {
            return BitConverter.ToString(_encrypter.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-", string.Empty);
        }
    }
}
