# RIBA Portable Items — заметки для агента

Мод для Barotrauma (Steam Workshop `2382545579`). Делает ванильные предметы
переносимыми/навешиваемыми, добавляет таланты и ограничения на установку.

## Главное: эта папка — исходники, а не мод

Игра грузит **не** эту папку. `RIBAXML.exe` компилирует её в соседнюю
`../RIBA Portable Items/` (имя берётся из атрибута `name` у `<contentpackage>`
в `RIBAfilelist.xml`).

## Сборка

```
build.cmd                 # собрать в LocalMods игры
build.cmd -Clean          # снести выход и staging, собрать заново
build.cmd -Launch         # собрать и запустить игру
```

В VS Code то же самое висит на Ctrl+Shift+B (`.vscode/tasks.json`).

`build.ps1` сам находит игру (реестр Steam → `libraryfolders.vdf` → appid
`602960`) и запоминает путь в `build.config.json` (в git не идёт). Переопределить
можно `-GameDir` или `BAROTRAUMA_DIR`.

Зачем скрипт вообще нужен: `RIBAXML.exe` резолвит **всё** от
`Directory.GetCurrentDirectory()` — и `../../Content/...`, и выход в `../<name>/`.
То есть запускаться он может только из каталога вида `<игра>/LocalMods/<что-то>`,
а репа лежит не там. Скрипт зеркалит рабочее дерево (robocopy `/MIR`) в
`<игра>/LocalMods/.riba-build-src` и запускает сборку оттуда. Игра этот каталог
не видит: `ContentPackageManager` пропускает подпапки `LocalMods` без
`filelist.xml` (`ContentPackageManager.cs:311`), а `filelist.xml` пишется только
в выходную папку.

Ещё две подлости RIBAXML, которые скрипт обходит:

- `CrateFolder` на отсутствующей папке спрашивает `y/n` через `Console.ReadKey`.
  Поэтому скрипт создаёт все выходные каталоги заранее.
- В конце `Main` безусловный `Console.ReadKey()` («тыкни»). Со сдвинутым stdin он
  падает `InvalidOperationException` — уже **после** записи всех файлов. Поэтому
  код возврата экзешника ничего не значит, и скрипт разбирает вывод: успех — это
  строка `<файл> - ОК` на каждую запись манифеста плюс `filelist.xml - ОК`.

`RIBAfilelist.xml` — это **манифест сборки**, а не просто метаданные:

| Тип записи | Что делает RIBAXML |
|---|---|
| `<Item file=...>` | обрабатывает — резолвит все аннотации |
| `Text`, `Talents`, `Other` | копирует байт-в-байт, **аннотации там не работают** |
| сам файл | копируется на выход под именем `filelist.xml` |

Файла нет в манифесте → он не обработан и не скопирован, в собранном моде его
просто нет. Это не косметика.

## Публикация в Мастерскую

```
build.cmd -Publish -Changelog "..."        # холостая проверка, ничего не льёт
build.cmd -Publish -Changelog "..." -Yes   # настоящая заливка
```

`Tools/RibaPublish` — консольная утилита на Facepunch.Steamworks, той же библиотеке и
том же вызове `Ugc.Editor.SubmitAsync`, которым публикует сама игра
(`PublishTab.cs:509`). Ссылается на `Facepunch.Steamworks.Win64.dll` прямо из папки
игры, путь ей передаёт `build.ps1` через `-p:BarotraumaDir`. Рядом с exe нужны
`steam_api64.dll` и `steam_appid.txt` с `602960` — их кладёт csproj. Нужен запущенный
Steam под владельцем мода: библиотека не логинится, она разговаривает с клиентом.

Вся страница мода описана в `workshop.json` в корне репы: `visibility`, `tags`,
`previewImage`, `descriptions` по языкам (`title` + `body`, где body — строка или
массив строк). Язык без title и без body пропускается. `--init-config` вычитывает
текущие настройки из Мастерской и записывает конфиг — так теги и видимость берутся
из факта, а не с экрана.

**Про многоязычность.** Steam хранит по одному title/description на язык, и одно
обновление несёт один язык (`SetItemUpdateLanguage`). Поэтому утилита делает N
сабмитов: первый — контент, теги, видимость, обложка и основной язык, дальше по
одному на каждый дополнительный, только с названием и описанием.
**На реальной заливке это ещё не проверялось**, дальше `--dry-run` дело не доходило.

**Теги.** Канон — 25 строк в `ClientSource/Steam/Workshop.cs:25`. Steam примет любую
чушь молча, поэтому утилита сверяет их со списком и ругается до заливки. Сейчас у мода
стоят `item, art, total conversion, environment, item assembly`.

**`expectedhash`.** Игра при публикации из UI дописывает его в `filelist.xml`
(`Workshop.cs:215`). Утилита не считает его вовсе, и это безопасно: `HashMismatches`
не срабатывает на пустом значении. А вот **чужой** хеш — фатальная ошибка загрузки у
подписчиков, поэтому предполётная проверка отказывается лить сборку, где он есть.
Наш `RIBAfilelist.xml` его не содержит, но установленная воркшоп-копия содержит —
из неё публиковать нельзя.

## Ссылочная надстройка над XML

Смысл: не копировать определения предметов у разработчиков, а **ссылаться** на них,
чтобы обновления игры подтягивались пересборкой. `<ImportItem
file="../../Content/Items/..." item="...">` читает живые файлы игры.

Элементы: `ImportItem`, `ImportElement` (тянет вложенный элемент по пути
`Name(0)/Name(1)`), `GetExistingElement` (зайти внутрь импортированного и править на
месте), `RemoveElements="Name(0), Name(all)"`, `RemoveAttributes`, `AddAttributes`,
`EditAttributes method="replace"`.

**Подвох:** `ImportItem` выбрасывает собственные атрибуты и целиком перенимает
ванильные. Менять что-либо, включая `identifier`, можно только через дочерний
`<EditAttributes method="replace" .../>`. Комментарии и пустые строки на выходе
вырезаются.

Исходник тула — отдельная репа (C#), `RibaXML.cs` это актуальный движок,
`Program.cs` — мёртвый прототип со старыми именами атрибутов (`Rfile`/`Ritem`), как
спеку его читать нельзя.

## Lua

`Lua/Autorun/init.lua` объявляет глобальный `RibaPI` и грузит пять файлов:

- `RibaStuff.lua` — утилиты + `data.json` (переводы и таблица `Bibs`)
- `RibaBigMessage.lua` — экранные сообщения с кулдаунами по категориям, включая
  серверный вызов клиентского сообщения через `Networking.Start("BigMessage")`
- `RibaLevels.lua` — уровни знаний экипажа в `CampaignMetadata`
- `RequiredItems.lua` — **сами хуки**
- `RibaLuaCheck.lua` — предупреждение, что Lua нет на одном из концов

### Предупреждение об отсутствии Lua

Вся логика мода в Lua, поэтому без неё половина мода молча не работает.
`RibaLuaCheck.lua` ловит это пинг-понгом раз в раунд: клиент шлёт `RIBALuaPing`,
сервер отвечает `RIBALuaPong`.

- понг не пришёл за 30 с → на сервере нет Lua, клиент сам открывает
  `GUI.MessageBox` (это конструктор `Barotrauma.GUIMessageBox`, кнопка ОК
  в двухаргументном конструкторе есть);
- пинг не пришёл за 30 с → у клиента нет Lua, просим ваниль показать окно ему:
  `Game.SendDirectChatMessage` с `ChatMessageType.MessageBox` — доходит и без
  Lua. Текст на языке клиента: `RibaPI.Text(key, tostring(client.Language.Value))`.

**Тип сообщения важен.** `Error`/`Server`/`ServerLog` клиент прогоняет через
`ServerMsgLString`: тот режет строку по `/`, пробует перевести каждый кусок как
ключ локализации и склеивает обратно **без разделителей**. В сообщении есть
ссылка на мастерскую — на `Error` она развалилась бы, стоило любому моду
завести ключ `workshop` или `filedetails`. `MessageBox` (7) идёт мимо перевода.

Всплывашка `GUI.AddMessage` для этого не годится: живёт максимум 10 секунд
(`clamp(len/5, 3, 10)` в ванили) и не переносит строки. Осталась как запасной
вариант под `pcall`.

Молчунов ищем по живому `Client.ClientList` и только среди `client.InGame` —
качающий моды ещё не молчун. Ванильную связку целиком (Lua нет нигде) не
поймать: выполнять проверку там некому; XML такого механизма не даёт.

Тот же приём в воркшоп-моде LuaCsClientSideEnforced (`3088784724`), только там
клиента без Lua кикают.

Хукинг — Harmony-патчи LuaCs:

```lua
Hook.Patch(id, "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", fn, Hook.HookMethodType.Before)
Hook.Patch(id, "Barotrauma.Items.Components.Holdable",      "Use",              fn, Hook.HookMethodType.Before)
```

Параметры игрового метода берутся по имени: `ptable["character"]`. Это значит, что
хук завязан не только на имя метода, но и на **имя параметра** в C#-исходнике —
переименование параметра тихо ломает хук.

`Bibs` в `data.json` — таблица «псевдонимов»: много разных RIBA-предметов
маппятся в одну группу (`RIBAControlMonitor` → `BIBAControlMonitor`), чтобы лимит на
установку был общим на всю группу, а не на каждый префаб.

## Исходники игры

Лежат рядом: `../LuaCsForBarotrauma` — форк с Lua API и полным C# игры.
Разреженный клон, только исходники (~1360 `.cs`, 63 МБ), без ассетов. Грепать там,
а не лезть в сеть.

Установлено сейчас: **игра v1.13.4.0**, **LuaCs 1.0.103**. Игра лежит в
`F:\SteamLibrary\steamapps\common\Barotrauma`.

Мод объявляет `gameversion="1.13.4.0"`, `modversion="6.0"`. До этого в git лежало
`1.0.9.0`/`5.0`, хотя опубликованная в воркшопе сборка была `1.7.7.0`/`5.9` — эти
два поля правили руками прямо в собранной папке и в исходники не возвращали.
Больше так не делать: `build.cmd` копирует `RIBAfilelist.xml` в выход как есть.

## Что уже сверено с ванилью 1.13.4

Диф «собранное из текущих исходников против опубликованного в феврале 2025»
показывает только изменения самой ванили — то есть ссылочная схема отработала,
все 158 `ImportItem`/`ImportElement` резолвятся, ни один `RemoveElements(индекс)`
не вышел за границы. Приезжает при пересборке бесплатно:

- **деконструктор получил `Controller`** (`spawnitemonselected`, limbposition'ы,
  `pressureprotection="6500"`) — в него теперь залезают персонажем. У переносного
  это стоит проверить глазами.
- батарея: контейнер показывает вставленные ячейки (`hideitems` true→false)
- research terminal: capacity 1→3, containable расширен на `smallitem,mediumitem`
- `subcategory` у ламп/перископов/мебели, `itemsuseinventoryplacement` +
  `slotsperrow` у полок, новые размеры `GuiFrame` у фабрикаторов
- `tags="onfire"` → `statuseffecttags="onfire"`, duration 1→10 у кислородной полки

## Переработка книг и лимитов

Согласована и делается: [Docs/books-and-limits.md](Docs/books-and-limits.md).
Знание переезжает с персонажа на кампанию (`CampaignMetadata`), книги становятся
одноразовыми с двумя уровнями, `<Override>` ванильных талантов убирается целиком.
Пункты 2 и 3 «Открытых задач» ниже закрываются этой переработкой — читать её
раньше, чем их.

## Открытые задачи

1. **RIBAXML: стартовая директория аргументом запуска.** Пути резолвятся от
   `Directory.GetCurrentDirectory()`, из-за чего сборка обязана происходить в
   `Barotrauma\LocalMods\` (76 ссылок на `../../Content` в `Xml/`). Сейчас это
   обходит `build.ps1` через staging-каталог, но обход стоит копирования дерева и
   двух костылей вокруг `Console.ReadKey`. Правильно — аргументы `--root`,
   `--game`, `--out` и `--no-pause` в самом туле. Заодно перетаргетить
   `RIBAXML.csproj` с `net7.0` (в системе SDK 9.0.308, net7 targeting pack нет).
2. **Ваниль догнала мод.** `Holdable.Use` в 1.13.4 сам реализует лимит установки
   (`LimitedAttachable` + `StatTypes.MaxAttachableCount`, `Holdable.cs:904-937`),
   считая **по лодке** (`Structure.GetAttachTarget(attachPos)?.Submarine`) и **по
   точному префабу**, и берёт `GetSavedStatValueWithBotsInMp`. Мод считает
   глобально по всему `Item.ItemList`, **по группе** из `Bibs`, и через
   `GetSavedStatValue`. Хук при этом ещё и переключает `instance.LimitedAttachable`,
   то есть кормит ванильную проверку. Это надо развести осознанно.

   **Решение отложено до теста в игре** — сначала смотрим, как этот дубль ведёт
   себя вживую на 1.13.4. До решения `data.json` не трогаем: там 6 записей `Bibs`
   на закомментированные предметы (`RIBAsonarmonitor`, `RIBAsonartransducer`,
   `RIBAshuttlenavterminal` + `Buyable`-варианты) — они безвредны (`RibaPI.Biba`
   вернёт nil), но фиксируют намерение. При этом `BIBAsonartransducer` и
   `BIBAshuttlenavterminal` не выдаются ни одним талантом: раскомментируешь
   предметы — получишь `maxBItems=0` и «читай книжки».

   Ещё 5 attachable-предметов вообще вне `Bibs`, то есть без лимита:
   `RIBATerminal`, `RIBABuyableTerminal`, `RIBATextdisplay`,
   `RIBABuyableTextdisplay`, `RIBALRwifiComponent`.

   **Подсчёт идёт по всей карте, а не по лодке.** `RequiredItems.lua:68` обходит
   `Item.ItemList` целиком, без фильтра по `Submarine`:

   ```lua
   for _, i in ipairs(Item.ItemList) do
       local holdableComponent = i.GetComponent(Components.Holdable)
       if holdableComponent ~= nil and holdableComponent.Attached then
   ```

   То есть в лимит попадают предметы на аутпостах, на чужих и союзных лодках, на
   шаттлах — всё, что сейчас есть в уровне. Ваниль с 1.13.4 в такой же ситуации
   считает по лодке, к которой крепишь (`Structure.GetAttachTarget(attachPos)?.Submarine`).
   В `Lua/todo` это уже записано строкой «что там по другим режимам? (один кап
   предметов на все лодки на всей карте)» — то есть задача известная, но не закрытая.
   Описание мода в Мастерской при этом обещает лимит «on the boat».
3. **Проверка доступа по профессии больше не нужна в Lua.** `RelatedItem.MatchesItem`
   матчит по тегам (`item.HasTag`), а `IdCard.cs:115` вешает на айдишку тег
   `jobid:<job>`. Атрибут принимает список: `items` / `identifiers` / `tags`.
   То есть весь `idcardSearch` с захардкоженной таблицей синонимов заменяется на
   ванильный XML:
   ```xml
   <RequiredItem items="jobid:captain,id_captain,cap" type="Picked" msg="ключ_локализации" />
   ```
   Бонусом бесплатно приезжает `CheckIdCardAccess` — запрет чужих айдишек на
   вражеской лодке и sub-specific ID, чего Lua-версия не делает вообще.
4. **Блокировка использования откреплённых шкафов — механика «предмет-пустышка».**
   `Xml/СommonСomponents.xml` — не сборочный файл, а библиотека сниппетов: он не в
   манифесте, его тянут через `ImportElement ... item="RIBAdummy"
   element="lulalua(0)/..."` (87 мест: 38 в `Items.xml`, 43 в `Items2.xml`,
   6 в `Items3.xml`). Сниппет такой:
   ```xml
   <RequiredItem items="riba_biba" type="Picked" msg="RIBAdeattachedBlockMessage"
                 ignoreineditor="true" RIBA_blockUseWhenDeattached="true"/>
   ```
   Предмета `riba_biba` не существует, поэтому ванильный `HasRequiredItems` всегда
   отвечает «нельзя», а Lua-хук **переворачивает** вердикт: ставит
   `PreventExecution = true` в обеих ветках и возвращает `Holdable.Attached`.
   Отсюда и `return true` в ветке «прикреплён» — иначе ванильный отказ не обойти.

   Следствие: на предмете с этим сниппетом любой **настоящий** ванильный
   `<RequiredItem>` будет проигнорирован. Сейчас пересечений нет (0 элементов несут
   оба RIBA-атрибута), но при переносе проверки профессий на ванильный XML (п. 3)
   совмещать их на одном предмете нельзя.

   Тот же файл раздаёт ещё два сниппета: `lulalua(0)/StatusEffect(0)` — сброс
   содержимого при откреплении (`DropContainedItems`), и `lulalua(0)/ItemContainer(0)`
   — совместимость с модом донорских карт для 6 ID-карт в `Items3.xml`. Второй
   раньше тянулся `ImportElement`'ом прямо из воркшоп-мода `2776270649`; если тот
   не установлен, RIBAXML печатал «нет таких файлов» и делал `return`, то есть
   `Items3.xml` не пересобирался **вообще** и в выходе тихо оставалась прошлогодняя
   версия. Инлайнено в `СommonСomponents.xml`. Внешних зависимостей у сборки
   больше нет — проверять при добавлении новых `ImportElement`.

   Ванильная альтернатива существует и проверена по исходнику: `Holdable.Attached` —
   `[Serialize]`-свойство, `PropertyConditional` умеет `targetitemcomponent`,
   `ItemComponent.CanBeSelected` — тоже `[Serialize]`, а StatusEffect пишет любые
   сериализуемые свойства (`propertyAttributes` → `ApplyToProperty`). То есть:
   ```xml
   <StatusEffect type="Always" targetitemcomponent="ItemContainer" CanBeSelected="false">
     <Conditional targetitemcomponent="Holdable" Attached="false" />
   </StatusEffect>
   ```
   **Не проверено в игре:** `type="Always"` требует, чтобы компонент обновлялся.
   Открепленный шкаф на полу может быть неактивен — тогда эффект не сработает.
   Проверять до того, как выпиливать Lua-ветку.
5. `character.AddMessage` в `RibaBigMessage.lua` вызывается с несовпадающей
   сигнатурой (см. ниже).

## Графика: незакрытый долг

**`RIBApowerdistributor` / `RIBABuyablepowerdistributor` пока на ванильной графике.**
Все остальные переносные предметы носят свою: `RemoveElements` выкидывает ванильные
`Sprite`/`BrokenSprite`/`InfectedSprite`, вместо них подставляются куски
`%ModDir%/Media/portable*.png`, а спрайты обоих `LightComponent` переопределяются
через `GetExistingElement`. У распределителя ничего этого нет — он выглядит ровно как
ванильный, и в списке предметов его от стационарного не отличить.

Доделать по образцу `RIBAJunctionBox` (`Items.xml`) и `RIBABuyableJunctionBox`
(`Items2.xml`): нарезать кадры в `portable.png` (DIY) и `portable2.png` (покупной),
затем добавить `BrokenSprite(all)`, `InfectedSprite(0)`, `DamagedInfectedSprite(0)` в
`RemoveElements` и два блока `GetExistingElement element="LightComponent(N)"` с
`RemoveElements elements="sprite(all)"` внутри. Исходный размер кадра — 112×128 при
`scale="0.5"`; у джанкшн-бокса для сравнения 113×176.

**Почему `Sprite(0)` там переопределён уже сейчас — это не про графику.** У ванильного
`powerdistributor` главный спрайт прописан **относительным** путём:

```xml
<Sprite texture="PowerDistributor.png" sourcerect="0,0,112,128" .../>
```

Правило в `ItemPrefab.GetTexturePath` (`ItemPrefab.cs:1032`):

```csharp
subElement.DoesAttributeReferenceFileNameAlone("texture")
    ? Path.GetDirectoryName(variantOf?.ContentFile.Path ?? ContentFile.Path)
    : ""
```

То есть **голое имя файла** без папки дополняется каталогом того XML, который объявляет
префаб. У ванили это `Content/Items/Electricity/`, и всё сходится. После `ImportItem`
префаб объявлен уже в `<мод>/Xml/Items.xml`, поэтому игра ищет
`<мод>/Xml/PowerDistributor.png` и не находит — предмет остаётся без спрайта, **молча**,
без единой ошибки в консоли. Поэтому в блоке стоит `RemoveElements elements="Sprite(0)"`
и своя строка с полным путём `Content/Items/Electricity/PowerDistributor.png`.

Если в `texture` есть хоть одна папка, префикс не добавляется вообще и путь считается от
корня игры. Поэтому остальные спрайты того же предмета трогать не пришлось:
`BrokenSprite`, `InfectedSprite`, `DamagedInfectedSprite` и спрайты внутри обоих
`LightComponent` у ванили уже записаны как `Content/...`. `surveillancecenter` в
`Items6.xml` весь на таких путях — потому там `Sprite` и не переопределяется.

**Проверять при каждом новом `ImportItem`:** если у ванильного предмета в `texture`
стоит голое имя файла без папки, спрайт надо переопределить с полным путём, даже когда
своей графики ещё нет. Иначе предмет соберётся без ошибок и будет невидимым.

## Грабли

- **`HasRequiredItems` — это предикат, а не событие.** Его зовут из отрисовки
  инвентаря (`Inventory.cs:1268,1565`), из `Item.cs`, из ИИ ботов
  (`AIObjectiveGetItem`, `AIObjectiveRepairItem`, `AIController`) и из серверной
  авторизации. Почти все вызовы идут с `addMessage: false` — ваниль сама считает
  его беззвучным. Поэтому любые побочки внутри хука (экранные сообщения,
  `Networking.Send`) срабатывают на наведение мыши, на перерисовку и **за ботов**.
  Вся машинерия кулдаунов в `RibaBigMessage.lua` — это компенсация за это.
  Блокировать тут можно, показывать что-либо — нет.
- **`HasRequiredItems` виртуальный и переопределён** в `Door`, `ItemContainer`,
  `Controller`, `Planter`. Harmony патчит тело базового метода, поэтому хук ловит
  наследника только когда тот зовёт `base.`. `ItemContainer.HasRequiredItems`
  зовёт, но короткозамыкает: `IsAccessible() && base.HasRequiredItems(...)` —
  при `IsAccessible() == false` база не вызывается и хук не срабатывает вовсе.
- **`targetitemcomponentname` — не существует.** В `PropertyConditional.IsValid`
  отфильтровываются только `targetitemcomponent`, `targetself`, `targetcontainer`,
  `targetgrandparent`, `targetcontaineditem`, `skillrequirement`, `targetslot`.
  Всё остальное становится **отдельным условием** «свойство X == значение», то
  есть опечатка в имени атрибута молча добавляет всегда-ложный кондишен, а не
  игнорируется. В `СommonСomponents.xml` так и было; спасал только дефолтный
  `conditionalcomparison="Or"`. Поставили бы `comparison="and"` — сброс содержимого
  умер бы разом на всех 26 предметах, которые несут этот сниппет. Исправлено на
  `targetitemcomponent`.
- При пустом `targetitemcomponent` условие проверяется по **всем**
  property-объектам цели (`AnyTargetMatches`), включая все компоненты предмета.
  Отсюда и работал `attached="false"` без указания компонента.
- `ItemComponent.Name` — это имя XML-элемента как написано (`element.Name.ToString()`),
  и сравнение в `AnyTargetMatches` регистрозависимое. В моде везде `<Holdable`
  (83 из 83), но при копипасте из чужих модов это ловушка.
- Хук `Holdable.Use` целиком завёрнут в `pcall` без обработки ошибки — любое
  падение внутри проглатывается молча. При отладке снимать pcall первым делом.
- `RibaPI.ScreenMessage.Small` зовёт
  `character.AddMessage(msg, clr, playSound, value, lifetime)`, а в C# сигнатура
  `AddMessage(string, Color, bool, Identifier = default, int? value = null, float lifetime = 3.0f)`.
  Четвёртым позиционным идёт `Identifier`, поэтому предполагаемый `lifetime`
  попадает в `value`, а реальный `lifetime` остаётся дефолтным.
- `Hook.Patch` в обоих местах зовётся с одинаковым id `"ololo"`.

## Git

Пуш делает только пользователь. **Самому не пушить.**
