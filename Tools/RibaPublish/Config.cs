using System.Text.Json;
using System.Text.Json.Serialization;

namespace RibaPublish;

/// <summary>
/// workshop.json - всё, что описывает страницу мода в Мастерской.
/// Лежит в корне репозитория, в собранный мод не попадает (его нет в манифесте).
/// </summary>
internal sealed class Config
{
    [JsonPropertyName("_help")]
    public string Help { get; set; } =
        "Настройки страницы мода в Мастерской. Заливает Tools/RibaPublish (build.cmd -Publish). " +
        "Поля с префиксом _ - справочные, читаются только глазами.";

    [JsonPropertyName("_availableTags")]
    public string[] AvailableTags { get; set; } = KnownTags;

    [JsonPropertyName("_visibilityValues")]
    public string[] VisibilityValues { get; set; } = { "public", "friendsonly", "private", "unlisted" };

    /// <summary>id предмета Мастерской. Если не задан - берётся из filelist.xml.</summary>
    public ulong? WorkshopId { get; set; }

    /// <summary>public | friendsonly | private | unlisted</summary>
    public string Visibility { get; set; } = "public";

    /// <summary>Обложка, путь относительно корня репы. Steam ограничивает картинку 1 МБ.</summary>
    public string? PreviewImage { get; set; }

    /// <summary>Теги. Допустимые значения - в <see cref="KnownTags"/>.</summary>
    public List<string> Tags { get; set; } = new();

    /// <summary>Язык, чьи название и описание считаются основными.</summary>
    public string DefaultLanguage { get; set; } = "english";

    /// <summary>Ключ - язык Steam (english, russian, ukrainian...).</summary>
    public Dictionary<string, Localized> Descriptions { get; set; } = new();

    internal sealed class Localized
    {
        public string? Title { get; set; }

        /// <summary>Строка или массив строк - массив склеивается переводами строк.</summary>
        [JsonConverter(typeof(StringOrArrayConverter))]
        public string? Body { get; set; }

        /// <summary>Альтернатива Body: путь к текстовому файлу относительно корня репы.</summary>
        public string? BodyFile { get; set; }
    }

    /// <summary>Список из Barotrauma, ClientSource/Steam/Workshop.cs:25. Steam чужие теги молча съест.</summary>
    public static readonly string[] KnownTags =
    {
        "submarine", "item", "monster", "mission", "outpost", "beacon station", "wreck",
        "ruin", "weapons", "medical", "equipment", "art", "event set", "total conversion",
        "game mode", "gameplay mechanics", "environment", "item assembly", "language",
        "qol", "client-side", "server-side", "outdated", "library",
    };

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public static Config Load(string path)
    {
        if (!File.Exists(path))
        {
            throw new AppException(
                $"Нет {path}.\n" +
                "    Сгенерировать из того, что уже опубликовано:  RibaPublish --init-config");
        }
        try
        {
            return JsonSerializer.Deserialize<Config>(File.ReadAllText(path), JsonOpts)
                   ?? throw new AppException($"{path} пустой.");
        }
        catch (JsonException ex)
        {
            throw new AppException($"{path} не разбирается: {ex.Message}");
        }
    }

    public void Save(string path) => File.WriteAllText(path, JsonSerializer.Serialize(this, JsonOpts));

    /// <summary>Текст описания для языка: Body или содержимое BodyFile.</summary>
    public string? ResolveBody(Localized loc, string repoRoot)
    {
        if (!string.IsNullOrWhiteSpace(loc.Body)) { return loc.Body; }
        if (string.IsNullOrWhiteSpace(loc.BodyFile)) { return null; }

        var p = Path.Combine(repoRoot, loc.BodyFile);
        if (!File.Exists(p)) { throw new AppException($"Не найден файл описания {p}"); }
        return File.ReadAllText(p);
    }

    public Steamworks.Ugc.Visibility ResolveVisibility() => Visibility.Trim().ToLowerInvariant() switch
    {
        "public" or "все" => Steamworks.Ugc.Visibility.Public,
        "friendsonly" or "friends" or "друзья" => Steamworks.Ugc.Visibility.FriendsOnly,
        "private" or "только я" => Steamworks.Ugc.Visibility.Private,
        "unlisted" => Steamworks.Ugc.Visibility.Unlisted,
        _ => throw new AppException(
            $"visibility=\"{Visibility}\" не понимаю. Допустимо: public, friendsonly, private, unlisted."),
    };

    public List<string> Validate(string repoRoot)
    {
        var problems = new List<string>();

        try { ResolveVisibility(); }
        catch (AppException ex) { problems.Add(ex.Message); }

        foreach (var t in Tags)
        {
            if (!KnownTags.Contains(t, StringComparer.OrdinalIgnoreCase))
            {
                problems.Add($"тег \"{t}\" не из списка Barotrauma — в фильтрах Мастерской он работать не будет.");
            }
        }

        if (!Descriptions.ContainsKey(DefaultLanguage))
        {
            problems.Add($"defaultLanguage=\"{DefaultLanguage}\", а описания для этого языка нет.");
        }

        if (!string.IsNullOrWhiteSpace(PreviewImage))
        {
            var p = Path.Combine(repoRoot, PreviewImage);
            if (!File.Exists(p))
            {
                problems.Add($"обложка не найдена: {p}");
            }
            else if (new FileInfo(p).Length > 1024 * 1024)
            {
                problems.Add($"обложка больше 1 МБ ({new FileInfo(p).Length / 1024.0 / 1024.0:N1} МБ) — Steam её отклонит.");
            }
        }

        return problems;
    }
}

/// <summary>Позволяет писать описание и одной строкой, и массивом строк.</summary>
internal sealed class StringOrArrayConverter : JsonConverter<string?>
{
    public override string? Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Null) { return null; }
        if (reader.TokenType == JsonTokenType.String) { return reader.GetString(); }
        if (reader.TokenType != JsonTokenType.StartArray)
        {
            throw new JsonException("Описание должно быть строкой или массивом строк.");
        }

        var lines = new List<string>();
        while (reader.Read() && reader.TokenType != JsonTokenType.EndArray)
        {
            lines.Add(reader.GetString() ?? "");
        }
        return string.Join("\n", lines);
    }

    public override void Write(Utf8JsonWriter writer, string? value, JsonSerializerOptions options)
    {
        if (value is null) { writer.WriteNullValue(); return; }

        // на запись раскладываем в массив строк - так конфиг остаётся читаемым
        writer.WriteStartArray();
        foreach (var line in value.Replace("\r\n", "\n").Split('\n')) { writer.WriteStringValue(line); }
        writer.WriteEndArray();
    }
}
