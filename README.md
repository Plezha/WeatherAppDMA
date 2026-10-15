# WeatherAppDMA

Учебное SwiftUI-приложение с погодой для 12 городов, почасовым прогнозом на
ближайшие 24 часа и сводкой до 7 дней. Избранное и заметки сохраняются в SwiftData,
единицы измерения — в UserDefaults.

## Сеть

### GET: прогноз погоды

Приложение использует [MET Norway Locationforecast 2.0](https://api.met.no/weatherapi/locationforecast/2.0/documentation)
через `URLSession.data(for:)` и Swift `async/await`. Аккаунт и API-ключ не нужны.

Пример запроса:

```sh
curl -H 'User-Agent: WeatherAppDMA/1.0 (https://github.com/v1lezz/WeatherAppDMA)' \
  'https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=55.7522&lon=37.6156'
```

- `RemoteWeatherDataSource` загружает по одному прогнозу на город, максимум
  3 запроса одновременно. Порядок списка сохраняется независимо от порядка ответов.
- Координаты и часовые пояса заданы в фиксированном каталоге из исходного приложения.
  Поиск фильтрует каталог, а не выполняет геокодирование.
- Запросы содержат идентифицирующий `User-Agent`. Стандартный HTTP-кэш `URLSession`
  учитывает `Expires` и `Last-Modified`, в том числе при переходе из списка в детали.
- Ответы проверяются на HTTP-ошибки и корректность JSON. При ошибке показана
  кнопка «Повторить»; список обновляется жестом pull-to-refresh.
- Температура приходит в °C, ветер — в м/с. Часы и даты показаны в часовом поясе города.
- Текущие значения берутся из ближайшей актуальной точки модельного прогноза.
  «Ощущается» показывается только при наличии `apparent_air_temperature`.
- Дневной диапазон вычисляется по доступным точкам: для сегодняшнего дня — по
  оставшемуся времени. Интервал между точками дальнего прогноза может быть 6 часов,
  поэтому диапазон отмечен как приблизительный. Иконка дня берётся из точки
  ближе всего к местному полудню.
- Отмена загрузки экрана передаётся сетевой задаче; старый отменённый запрос
  не перезаписывает состояние нового.

`LocalWeatherDataSource` и `weather_mock.json` сохранены для автономных примеров.
Чтобы использовать их, замените источник в `CompositionRoot` на
`LocalWeatherDataSource(loader: BundleJSONLoader())`.

Данные: [MET Norway, CC BY 4.0](https://api.met.no/doc/License).
Приложение преобразует символы погоды и агрегирует точки в дневные сводки.
[Правила использования API](https://api.met.no/doc/TermsOfService).

### POST: тестовое сообщение

В настройках откройте «Проверка связи» и нажмите «Отправить тестовое сообщение».
Приложение отправит JSON в [httpbin.org](https://httpbin.org/) и покажет сообщение,
извлечённое из JSON-ответа сервера. Это echo-сервис, а не отправка отзыва разработчикам.
Аккаунт и ключ не нужны. Тело содержит только фиксированное тестовое сообщение.

```sh
curl -X POST 'https://httpbin.org/post' \
  -H 'Content-Type: application/json' \
  -d '{"message":"WeatherAppDMA connectivity test"}'
```

`RemoteTestMessageRepository` сериализует тело через `JSONEncoder`, задаёт
`httpMethod = "POST"` и проверяет совпадение ответа `json.message` с отправленным
сообщением. Оба запроса используют `HTTPClient.decodedResponse`: проверка
HTTP-статуса, разбор через `JSONDecoder`, обработка ошибок сети и неверного JSON.
В интерфейсе есть состояния отправки, успеха и ошибки; после ошибки доступна
повторная отправка. Закрытие настроек отменяет запрос.

## Запуск и тесты

Откройте `WeatherAppDMA.xcodeproj` и запустите схему `WeatherAppDMA`.
В исходной конфигурации указан deployment target iOS 26.5. Для проверки на более
раннем iOS 26 simulator можно переопределить его без изменения файла проекта:

```sh
xcodebuild test -project WeatherAppDMA.xcodeproj -scheme WeatherAppDMA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeatherAppDMATests IPHONEOS_DEPLOYMENT_TARGET=26.0 CODE_SIGNING_ALLOWED=NO
```

Сетевые unit-тесты используют подставной `HTTPClient` и не зависят от интернета.
