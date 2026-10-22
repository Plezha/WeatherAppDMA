# WeatherAppDMA

Учебное SwiftUI-приложение с текущей погодой для 12 городов, почасовым прогнозом
на ближайшие 24 часа и прогнозом на 7 дней. Избранное и заметки сохраняются
в SwiftData, единицы измерения — в UserDefaults.

## Настройка API-ключа

Создайте аккаунт на [Visual Crossing](https://www.visualcrossing.com/sign-up/)
и получите ключ. Затем скопируйте пример локальной конфигурации:

```sh
cp WeatherAppDMA/Data/Resources/WeatherAPIConfig.example.json \
   WeatherAppDMA/Data/Resources/WeatherAPIConfig.local.json
```

Вставьте ключ в поле `apiKey` локального JSON. Файл исключён из Git вложенным
`.gitignore`; настоящий ключ не должен попадать в коммиты, тесты или описание PR.
Xcode копирует локальный файл в ресурсы приложения при сборке. Это конфигурация
для учебного локального запуска, а не способ скрыть ключ в распространяемом приложении.

Альтернатива — переменная окружения `VISUAL_CROSSING_API_KEY` в настройках Run
схемы Xcode. Она имеет приоритет над файлом. При отсутствии ключа приложение
показывает понятную ошибку и не отправляет запрос.

## GET: подробный прогноз города

`RemoteWeatherDataSource.loadWeather(for:)` вызывает:

```text
GET https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/{latitude},{longitude}/next7days
```

Параметры query: `key`, `unitGroup=metric`, `contentType=json`, `iconSet=icons2`,
`include=days,hours,current`. Ответ JSON декодируется в `VisualCrossingForecast`.
Текущая погода берётся из `currentConditions`, почасовой и дневной прогноз — из `days`.
Из диапазона `next7days` берутся первые 7 дней; часы фильтруются на ближайшие 24 часа.

## POST: погода для списка городов

`RemoteWeatherDataSource.loadCities()` вызывает:

```text
POST https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timelinemulti
Content-Type: application/x-www-form-urlencoded; charset=utf-8
```

Тело содержит `locations` (12 координат через `|`), `key`, `include=current`,
`unitGroup=metric`, `contentType=json`, `iconSet=icons2`. Параметры кодируются
по правилам URL form encoding — такой формат требует Visual Crossing для POST.
JSON-ответ содержит массив `locations`. Элементы сопоставляются по исходному
`address`, поэтому порядок ответа сервера не меняет порядок городов в интерфейсе.

POST выполняет полезную работу при открытии списка и pull-to-refresh.
GET выполняется при открытии конкретного города. Оба запроса используют один
погодный сервис; отдельной кнопки с тестовым echo-сообщением нет.

## Парсинг, ошибки и многопоточность

- Общий `HTTPClient.decodedResponse` использует `URLSession.data(for:)`, проверяет
  HTTP-ответ и декодирует JSON через `JSONDecoder`/`Decodable`.
- Обработаны отсутствие/неверный ключ (401), лимит запросов (429), остальные
  HTTP-ошибки, отсутствие сети, тайм-аут, некорректный JSON и неполный batch-ответ.
- В состояниях ошибки есть кнопка «Повторить». Отмена запроса не показывается
  как ошибка и не позволяет старой загрузке перезаписать новый результат.
- ViewModel изолированы `MainActor`; DTO и сетевые типы явно `nonisolated`/`Sendable`.
- В metric-ответе скорость ветра приходит в км/ч и переводится в м/с для доменной
  модели. Эпохи `datetimeEpoch` преобразуются в `Date`, отображение учитывает
  часовой пояс `timezone` из ответа. Дневные min/max берутся непосредственно у API.

`LocalWeatherDataSource` и `weather_mock.json` сохранены. Для автономного примера
замените источник в `CompositionRoot` на `LocalWeatherDataSource(loader: BundleJSONLoader())`.

Данные: [Visual Crossing Weather](https://www.visualcrossing.com/weather-api/).
Документация: [Timeline GET](https://www.visualcrossing.com/resources/documentation/weather-api/timeline-weather-api/),
[POST и несколько городов](https://www.visualcrossing.com/resources/documentation/weather-api/using-the-timeline-weather-api-with-multiple-locations-in-the-same-request/).

## Запуск и тесты

Откройте `WeatherAppDMA.xcodeproj` и запустите схему `WeatherAppDMA`.
В исходной конфигурации указан deployment target iOS 26.5 — нужен совместимый
симулятор. Для локальной проверки на iOS 26.3/26.4 временно снизьте deployment
target приложения и тестов до 26.0 в локальной копии проекта. Одного параметра
командной строки может быть недостаточно для выбора destination в Xcode.

Новые проверки поведения приложения:

- `ApplicationBehaviorTests` — поиск без учёта регистра/пробелов и восстановление
  сохранённого порядка избранного после ошибки перестановки (2 unit-теста).
- `ApplicationFlowsUITests` (2 UI-теста):
  - Успешные POST списка городов и GET прогноза, сопоставление городов в
    переставленном ответе и сохранение °F после перезапуска (12,5 °C → 54,5 °F).
  - Ошибка HTTP 503 для POST и тайм-аут GET, восстановление после «Повторить»,
    затем добавление избранного, сохранение заметки и удаление города.

```sh
xcodebuild test -project WeatherAppDMA.xcodeproj -scheme WeatherAppDMA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeatherAppDMATests/ApplicationBehaviorTests \
  -only-testing:WeatherAppDMAUITests/ApplicationFlowsUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

UI-тесты запускают Debug-сборку с `--ui-testing`. Используется настоящий
`RemoteWeatherDataSource`: он строит GET/POST-запросы, проверяет HTTP-статусы,
декодирует API JSON и преобразует его в модели приложения. Только транспорт
заменён на `UITestHTTPClient`, возвращающий фиксированные ответы без URLSession
и внешних запросов. Неизвестные URL и HTTP-методы отклоняются. Время источника
зафиксировано, чтобы почасовой прогноз не устаревал между запусками.

Сценарий задаётся через `UI_TEST_NETWORK_SCENARIO`: `success` сразу возвращает
JSON с HTTP 200, а `retry` сначала возвращает 503 для POST и бросает
`URLError.timedOut` для GET, затем отвечает успешно на повторные запросы.
Каждый запуск приложения создаёт новый транспорт со своим состоянием.

SwiftData хранится в памяти, а UserDefaults использует отдельный suite с
уникальным `UI_TEST_RUN_ID`. Этот ID сохраняется при перезапуске внутри одного
теста. Используется фиктивный ключ `ui-test-key`; настоящий ключ и интернет
не нужны, данные обычного запуска не меняются. В Release тестовый транспорт
не компилируется и аргумент тестового режима игнорируется.

Остальные unit-тесты подставляют `HTTPClient` и тестовый ключ. Они проверяют
оба HTTP-метода, кодирование формы, разбор ответа, единицы/даты, перестановку
и дубли batch-ответов, ошибки сети/HTTP/JSON и отмену.
