using System.Xml.Linq;
using Steamworks;
using Steamworks.Ugc;

namespace RibaPublish;

/// <summary>
/// Заливает собранную папку мода в Steam Workshop тем же путём, каким это делает
/// сама игра: Facepunch.Steamworks -> Ugc.Editor -> SubmitAsync.
///
/// Требует запущенного Steam-клиента под аккаунтом, которому принадлежит мод.
/// Логиниться сам не умеет и не должен - общается с уже работающим клиентом.
/// </summary>
internal static class Program
{
    private const uint AppId = 602960;

    /// <summary>Языки, на которых у мода есть страница. Ключи Steam, не наши.</summary>
    private static readonly string[] Languages = { "english", "russian", "ukrainian" };

    private static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        var opt = Options.Parse(args);
        if (opt is null) { Options.Usage(); return 2; }

        try
        {
            return opt.InitConfig ? await InitConfig(opt) : await Publish(opt);
        }
        catch (AppException ex)
        {
            Console.WriteLine();
            Err(ex.Message);
            return 1;
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Err("Неожиданная ошибка: " + ex);
            return 1;
        }
        // SteamClient.Shutdown() здесь намеренно не зовём: с asyncCallbacks он роняет
        // рантайм ("Fatal error") уже после того, как вся работа сделана. Процесс всё
        // равно завершается, Steam подчистит соединение сам.
    }

    // ------------------------------------------------------------- init-config --

    private static async Task<int> InitConfig(Options opt)
    {
        var itemId = opt.WorkshopId
                     ?? (Directory.Exists(opt.ContentDir) ? Manifest.Load(opt.ContentDir).WorkshopId : null)
                     ?? throw new AppException("Не знаю, какой мод читать. Передай --id <workshopid>.");

        InitSteam();
        var item = await FetchItem(itemId);

        if (File.Exists(opt.ConfigPath) && !opt.Yes)
        {
            throw new AppException($"{opt.ConfigPath} уже существует. Перезаписать: добавь --yes.");
        }

        // Steam хранит описание отдельно на каждый язык, и Item.GetAsync отдаёт только
        // основной. Тянем каждый язык своим запросом.
        var descriptions = new Dictionary<string, Config.Localized>();
        string? primaryBody = null;
        foreach (var lang in Languages)
        {
            var loc = await FetchLocalized(itemId, lang);
            if (loc is null) { Warn($"{lang}: Steam ничего не отдал"); continue; }

            // Если перевода нет, Steam молча отдаёт основной текст. Отличить можно
            // только сравнением - иначе запишем английский в русский и зальём его туда.
            primaryBody ??= loc.Body;
            var translated = descriptions.Count == 0 || loc.Body != primaryBody;

            descriptions[lang] = translated
                ? loc
                : new Config.Localized { Title = null, Body = null };

            if (translated) { Ok($"{lang}: \"{loc.Title}\", {(loc.Body ?? "").Length} символов"); }
            else { Warn($"{lang}: своего перевода нет, Steam вернул основной текст — оставляю пустым"); }
        }
        if (descriptions.Count == 0)
        {
            descriptions["english"] = new Config.Localized { Title = item.Title, Body = item.Description };
        }

        var cfg = new Config
        {
            WorkshopId = itemId,
            Visibility = item.Visibility switch
            {
                Steamworks.Ugc.Visibility.Public => "public",
                Steamworks.Ugc.Visibility.FriendsOnly => "friendsonly",
                Steamworks.Ugc.Visibility.Private => "private",
                _ => "unlisted",
            },
            Tags = (item.Tags ?? Array.Empty<string>()).ToList(),
            DefaultLanguage = "english",
            Descriptions = descriptions,
        };
        cfg.Save(opt.ConfigPath);

        Console.WriteLine();
        Ok($"записан {opt.ConfigPath}");
        Warn("Обложку Steam через API не отдаёт — пропиши previewImage сам, если хочешь ею управлять.");
        return 0;
    }

    // ----------------------------------------------------------------- publish --

    private static async Task<int> Publish(Options opt)
    {
        if (!Directory.Exists(opt.ContentDir))
        {
            throw new AppException($"Нет папки со сборкой: {opt.ContentDir}");
        }

        var manifest = Manifest.Load(opt.ContentDir);
        var cfg = Config.Load(opt.ConfigPath);
        var itemId = opt.WorkshopId ?? cfg.WorkshopId ?? manifest.WorkshopId
            ?? throw new AppException("Не понимаю, какой мод обновлять: нет ни --id, ни workshopId, ни steamworkshopid.");

        var defaultLoc = cfg.Descriptions.TryGetValue(cfg.DefaultLanguage, out var d) ? d : null;
        var title = defaultLoc?.Title ?? manifest.Name;

        Step("Собранный мод");
        Info($"  папка       {opt.ContentDir}");
        Info($"  название    {title}");
        Info($"  modversion  {manifest.ModVersion ?? "<нет>"}");
        Info($"  gameversion {manifest.GameVersion ?? "<нет>"}");
        Info($"  workshop id {itemId}");
        Info($"  файлов      {CountFiles(opt.ContentDir)}");
        Console.WriteLine();
        Step("Страница в Мастерской");
        Info($"  конфиг      {opt.ConfigPath}");
        Info($"  видимость   {cfg.ResolveVisibility()}");
        Info($"  теги        {(cfg.Tags.Count > 0 ? string.Join(", ", cfg.Tags) : "<нет>")}");
        Info($"  обложка     {cfg.PreviewImage ?? "<не трогаем>"}");
        Info($"  языки       {string.Join(", ", cfg.Descriptions.Keys)}");

        var problems = Preflight(manifest, opt.ContentDir);
        problems.AddRange(cfg.Validate(opt.RepoRoot));
        if (problems.Count > 0)
        {
            Console.WriteLine();
            Err("Предполётная проверка не пройдена:");
            foreach (var p in problems) { Err("  - " + p); }
            return 1;
        }
        Console.WriteLine();
        Ok("предполётная проверка пройдена");

        InitSteam();
        var item = await FetchItem(itemId);
        Console.WriteLine();
        Info($"в Мастерской сейчас: \"{item.Title}\"");
        Info($"  владелец   {item.Owner.Name} [{item.Owner.Id}]");
        Info($"  обновлён   {item.Updated:yyyy-MM-dd HH:mm}");
        Info($"  размер     {item.SizeOfFileInBytes / 1024.0 / 1024.0:N1} МБ");

        if (item.Owner.Id != SteamClient.SteamId)
        {
            throw new AppException(
                $"Мод принадлежит другому аккаунту ({item.Owner.Name}). " +
                "Steam должен быть запущен под владельцем мода.");
        }

        if (opt.DryRun)
        {
            Console.WriteLine();
            Warn("--dry-run: всё готово к заливке, SubmitAsync не вызываю");
            return 0;
        }
        if (!opt.Yes)
        {
            Console.WriteLine();
            Warn("Заливка перезапишет мод у всех подписчиков и не откатывается.");
            Warn("Добавь --yes, если действительно хочешь опубликовать.");
            return 1;
        }

        // --- основной сабмит: контент, теги, видимость, обложка, основной язык
        Console.WriteLine();
        Step($"Заливаю содержимое ({cfg.DefaultLanguage})");

        var editor = new Editor(itemId)
            .WithContent(opt.ContentDir)
            .ForAppId(AppId)
            .InLanguage(cfg.DefaultLanguage)
            .WithTitle(title)
            .WithTags(cfg.Tags)
            .WithMetaData($"gameversion={manifest.GameVersion};modversion={manifest.ModVersion}");
        editor.Visibility = cfg.ResolveVisibility();

        var body = defaultLoc is null ? null : cfg.ResolveBody(defaultLoc, opt.RepoRoot);
        if (!string.IsNullOrWhiteSpace(body)) { editor = editor.WithDescription(body); }
        if (!string.IsNullOrWhiteSpace(cfg.PreviewImage))
        {
            editor = editor.WithPreviewFile(Path.Combine(opt.RepoRoot, cfg.PreviewImage));
        }
        if (!string.IsNullOrWhiteSpace(opt.ChangeLog))
        {
            editor = editor.WithChangeLog(opt.ChangeLog);
        }

        await Submit(editor);

        // --- по одному сабмиту на каждый дополнительный язык: только название и описание
        foreach (var (lang, loc) in cfg.Descriptions)
        {
            if (string.Equals(lang, cfg.DefaultLanguage, StringComparison.OrdinalIgnoreCase)) { continue; }

            var locBody = cfg.ResolveBody(loc, opt.RepoRoot);
            if (string.IsNullOrWhiteSpace(loc.Title) && string.IsNullOrWhiteSpace(locBody))
            {
                Console.WriteLine();
                Warn($"{lang}: ни названия, ни описания — пропускаю");
                continue;
            }

            // Копию основного текста заливать нельзя: Steam запишет её как перевод, и
            // потом уже не отличить "переведено так же" от "не переведено вовсе".
            if (locBody == body && loc.Title == title)
            {
                Console.WriteLine();
                Warn($"{lang}: текст совпадает с {cfg.DefaultLanguage} — это ещё не перевод, пропускаю");
                continue;
            }

            Console.WriteLine();
            Step($"Перевод: {lang}");

            var tr = new Editor(itemId).ForAppId(AppId).InLanguage(lang);
            if (!string.IsNullOrWhiteSpace(loc.Title)) { tr = tr.WithTitle(loc.Title); }
            if (!string.IsNullOrWhiteSpace(locBody)) { tr = tr.WithDescription(locBody); }

            await Submit(tr);
        }

        Console.WriteLine();
        Ok($"готово: https://steamcommunity.com/sharedfiles/filedetails/?id={itemId}");
        return 0;
    }

    private static async Task Submit(Editor editor)
    {
        _lastPct = -1;
        var result = await editor.SubmitAsync(new Progress<float>(ReportProgress));
        if (_lastPct >= 0) { Console.WriteLine(); }

        if (!result.Success) { throw new AppException($"Steam вернул {result.Result}."); }
        if (result.NeedsWorkshopAgreement)
        {
            Warn("Steam ждёт принятия Workshop Legal Agreement, иначе мод не появится:");
            Warn("  https://steamcommunity.com/sharedfiles/workshoplegalagreement");
        }
        Ok("принято");
    }

    // ------------------------------------------------------------------ helpers --

    private static void InitSteam()
    {
        if (!SteamClient.IsValid) { SteamClient.Init(AppId, asyncCallbacks: true); }
        if (!SteamClient.IsValid) { throw new AppException("SteamClient.Init не удался. Steam запущен?"); }
        Ok($"Steam: {SteamClient.Name} [{SteamClient.SteamId}]");
    }

    private static async Task<Item> FetchItem(ulong itemId)
    {
        var published = await Item.GetAsync(itemId)
            ?? throw new AppException($"Мастерская не отдала предмет {itemId}. Проверь id и доступность мода.");
        return published;
    }

    private static async Task<Config.Localized?> FetchLocalized(ulong id, string lang)
    {
        var query = Query.All.WithFileId(id).InLanguage(lang).WithLongDescription(true);
        var page = await query.GetPageAsync(1);
        if (page is null) { return null; }

        using var result = page.Value;
        foreach (var entry in result.Entries)
        {
            return new Config.Localized { Title = entry.Title, Body = entry.Description };
        }
        return null;
    }

    private static int CountFiles(string dir) => Directory.GetFiles(dir, "*", SearchOption.AllDirectories).Length;

    private static List<string> Preflight(Manifest m, string dir)
    {
        var problems = new List<string>();

        // Чужой/протухший expectedhash - фатальная ошибка загрузки у подписчиков
        // (ContentPackage.HashMismatches). Пустой - безопасен, проверка не срабатывает.
        if (!string.IsNullOrWhiteSpace(m.ExpectedHash))
        {
            problems.Add(
                $"в filelist.xml прописан expectedhash=\"{m.ExpectedHash}\". " +
                "Он посчитан для другой сборки, и мод не загрузится. Убери атрибут.");
        }
        if (string.IsNullOrWhiteSpace(m.ModVersion))
        {
            problems.Add("в filelist.xml нет modversion — подписчики не увидят, что вышло обновление.");
        }
        if (CountFiles(dir) == 0) { problems.Add("папка пустая."); }

        foreach (var f in m.Files)
        {
            var p = Path.Combine(dir, f.Replace("%ModDir%/", "").Replace('/', Path.DirectorySeparatorChar));
            if (!File.Exists(p)) { problems.Add($"в манифесте есть {f}, а файла нет — сборка неполная."); }
        }
        return problems;
    }

    private static int _lastPct = -1;

    private static void ReportProgress(float value)
    {
        var pct = (int)Math.Round(value * 100);
        if (pct == _lastPct) { return; }
        _lastPct = pct;
        Console.Write($"\r    {pct,3}%");
    }

    private static void Step(string s) => Write("==> " + s, ConsoleColor.Cyan);
    private static void Ok(string s) => Write("    " + s, ConsoleColor.Green);
    private static void Warn(string s) => Write("    " + s, ConsoleColor.Yellow);
    private static void Err(string s) => Write("    " + s, ConsoleColor.Red);
    private static void Info(string s) => Console.WriteLine(s);

    private static void Write(string s, ConsoleColor c)
    {
        var prev = Console.ForegroundColor;
        Console.ForegroundColor = c;
        Console.WriteLine(s);
        Console.ForegroundColor = prev;
    }
}

internal sealed class AppException(string message) : Exception(message);

internal sealed class Manifest
{
    public required string Name { get; init; }
    public string? ModVersion { get; init; }
    public string? GameVersion { get; init; }
    public string? ExpectedHash { get; init; }
    public ulong? WorkshopId { get; init; }
    public required List<string> Files { get; init; }

    public static Manifest Load(string dir)
    {
        var path = Path.Combine(dir, "filelist.xml");
        if (!File.Exists(path))
        {
            throw new AppException(
                $"В {dir} нет filelist.xml. Это не собранный мод — укажи выходную папку сборки, а не репозиторий.");
        }

        var root = XDocument.Load(path).Root ?? throw new AppException("filelist.xml пустой.");

        ulong? id = null;
        if (ulong.TryParse((string?)root.Attribute("steamworkshopid"), out var parsed) && parsed != 0) { id = parsed; }

        return new Manifest
        {
            Name = (string?)root.Attribute("name") ?? "<без имени>",
            ModVersion = (string?)root.Attribute("modversion"),
            GameVersion = (string?)root.Attribute("gameversion"),
            ExpectedHash = (string?)root.Attribute("expectedhash"),
            WorkshopId = id,
            Files = root.Elements()
                .Select(e => (string?)e.Attribute("file"))
                .Where(f => !string.IsNullOrWhiteSpace(f))
                .Select(f => f!)
                .ToList(),
        };
    }
}

internal sealed class Options
{
    public required string RepoRoot { get; init; }
    public required string ContentDir { get; init; }
    public required string ConfigPath { get; init; }
    public ulong? WorkshopId { get; init; }
    public string? ChangeLog { get; init; }
    public bool DryRun { get; init; }
    public bool Yes { get; init; }
    public bool InitConfig { get; init; }

    public static Options? Parse(string[] args)
    {
        string? content = null, cfg = null, repo = null, log = null;
        ulong? id = null;
        bool dry = false, yes = false, init = false;

        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i].ToLowerInvariant())
            {
                case "--content" when i + 1 < args.Length: content = args[++i]; break;
                case "--config" when i + 1 < args.Length: cfg = args[++i]; break;
                case "--repo" when i + 1 < args.Length: repo = args[++i]; break;
                case "--changelog" when i + 1 < args.Length: log = args[++i]; break;
                case "--id" when i + 1 < args.Length:
                    if (!ulong.TryParse(args[++i], out var v)) { return null; }
                    id = v; break;
                case "--dry-run": dry = true; break;
                case "--yes": yes = true; break;
                case "--init-config": init = true; break;
                default: return null;
            }
        }

        repo ??= Directory.GetCurrentDirectory();
        if (!Directory.Exists(repo)) { return null; }
        repo = Path.GetFullPath(repo);

        if (!init && content is null) { return null; }

        return new Options
        {
            RepoRoot = repo,
            ContentDir = content is null ? "" : Path.GetFullPath(content),
            ConfigPath = Path.GetFullPath(cfg ?? Path.Combine(repo, "workshop.json")),
            WorkshopId = id,
            ChangeLog = log,
            DryRun = dry,
            Yes = yes,
            InitConfig = init,
        };
    }

    public static void Usage()
    {
        Console.WriteLine("""
            RibaPublish — заливка собранного мода в Steam Workshop.

              RibaPublish --content <папка сборки> [--changelog "текст"] [--dry-run] [--yes]
              RibaPublish --init-config [--id <workshopid>] [--yes]

              --content      папка собранного мода (та, где лежит filelist.xml)
              --config       путь к workshop.json (по умолчанию <repo>/workshop.json)
              --repo         корень репозитория, от него считаются пути в конфиге
              --changelog    примечание к этой версии
              --id           id предмета Мастерской; иначе из конфига или filelist.xml
              --dry-run      проверить всё и остановиться перед заливкой
              --yes          подтвердить заливку; без него ничего не публикуется
              --init-config  прочитать текущие настройки из Мастерской и записать конфиг

            Нужен запущенный Steam под аккаунтом, которому принадлежит мод.
            """);
    }
}
