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
В исходной конфигурации указан deployment target iOS 26.5. Для проверки на более
раннем iOS 26 simulator можно переопределить его без изменения файла проекта:

```sh
xcodebuild test -project WeatherAppDMA.xcodeproj -scheme WeatherAppDMA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeatherAppDMATests IPHONEOS_DEPLOYMENT_TARGET=26.0 CODE_SIGNING_ALLOWED=NO
```

Unit-тесты подставляют `HTTPClient` и тестовый ключ. Они проверяют оба метода,
кодирование формы, разбор ответа, единицы/даты, перестановку и дубли batch-ответов,
ошибки сети/HTTP/JSON, отмену и сохранённый локальный источник.
