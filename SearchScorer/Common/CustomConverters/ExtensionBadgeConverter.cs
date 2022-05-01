// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using SearchScorer.Common;

namespace SearchScorer.Common
{
    public class ExtensionBadgeConverter : JsonConverter<ExtensionBadge>
    {
        public override ExtensionBadge Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException();
            }

            var extensionFile = new ExtensionBadge();

            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject)
                {
                    return extensionFile;
                }

                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string propertyName = reader.GetString().ToLowerInvariant();
                    reader.Read();
                    switch (propertyName)
                    {
                        case "link":
                            extensionFile.Link = reader.GetString();
                            break;
                        case "imguri":
                            extensionFile.ImgUri = reader.GetString();
                            break;
                        case "description":
                            extensionFile.Description = reader.GetString();
                            break;
                    }
                }
            }

            throw new JsonException();
        }

        public override void Write(Utf8JsonWriter writer,
            ExtensionBadge extensionFile,
            JsonSerializerOptions options)
        {
            writer.WriteStartObject();

            writer.WriteString("link", extensionFile.Link);
            writer.WriteString("imgUri", extensionFile.ImgUri);
            writer.WriteString("description", extensionFile.Description);

            writer.WriteEndObject();
        }
    }
}