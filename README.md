# WeatherAppDMA

Учебное SwiftUI-приложение с текущей погодой, почасовым прогнозом на ближайшие
24 часа и прогнозом на 7 дней. Избранные города и заметки сохраняются в SwiftData,
единицы измерения — в UserDefaults.

## Сеть

Приложение использует [Open-Meteo Forecast API](https://open-meteo.com/en/docs)
через `URLSession.data(for:)` и Swift `async/await`. API-ключ для бесплатного
некоммерческого использования не требуется.

- `RemoteWeatherDataSource.loadCities()` получает текущую погоду для всех
  12 городов одним запросом с несколькими координатами.
- `loadWeather(for:)` запрашивает подробный прогноз выбранного города.
- Каталог городов фиксирован и совпадает с исходным приложением; поиск фильтрует
  этот каталог, а не выполняет геокодирование.
- Ответы проверяются на HTTP-ошибки и корректность JSON. При ошибке показана
  кнопка «Повторить»; список обновляется жестом pull-to-refresh.
- Температура запрашивается в °C, ветер — в м/с. Часы и даты прогноза отображаются
  в часовом поясе города. Коды WMO преобразуются в существующие `WeatherCondition`.
- Отмена загрузки экрана передаётся сетевой задаче. Отменённые запросы не показывают
  ошибку и не перезаписывают результат следующего запроса.

`LocalWeatherDataSource` и `weather_mock.json` сохранены для автономных примеров.
Автоматической подмены реальной погоды моками при сетевой ошибке нет.
Чтобы использовать моки, замените источник в `CompositionRoot` на
`LocalWeatherDataSource(loader: BundleJSONLoader())`.

Данные предоставлены [Open-Meteo](https://open-meteo.com/) по
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Запуск и тесты

Откройте `WeatherAppDMA.xcodeproj` и запустите схему `WeatherAppDMA`.
В исходной конфигурации проекта указан deployment target iOS 26.5.
Для локальной проверки с более ранним iOS 26 simulator можно переопределить
`IPHONEOS_DEPLOYMENT_TARGET` в команде, не меняя файл проекта:

```sh
xcodebuild test -project WeatherAppDMA.xcodeproj -scheme WeatherAppDMA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3' \
  -only-testing:WeatherAppDMATests IPHONEOS_DEPLOYMENT_TARGET=26.0 CODE_SIGNING_ALLOWED=NO
```

Сетевые unit-тесты используют подставной `HTTPClient` и не зависят от интернета.
