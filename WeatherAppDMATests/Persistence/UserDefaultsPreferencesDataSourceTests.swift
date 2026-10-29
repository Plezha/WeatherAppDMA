import Testing
import Foundation
@testable import WeatherAppDMA

struct UserDefaultsPreferencesDataSourceTests {

    private func makeDataSource() throws -> (UserDefaultsPreferencesDataSource, UserDefaults) {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (UserDefaultsPreferencesDataSource(defaults: defaults), defaults)
    }

    @Test
    func load_returnsDefaults_whenEmpty() throws {
        let (ds, _) = try makeDataSource()
        let prefs = ds.load()
        #expect(prefs.temperatureUnit == .celsius)
        #expect(prefs.windUnit == .metersPerSecond)
        #expect(prefs.lastOpenedCity == nil)
    }

    @Test
    func setTemperatureUnit_persists() throws {
        let (ds, _) = try makeDataSource()
        ds.setTemperatureUnit(.fahrenheit)
        #expect(ds.load().temperatureUnit == .fahrenheit)
    }

    @Test
    func setWindUnit_persists() throws {
        let (ds, _) = try makeDataSource()
        ds.setWindUnit(.kilometersPerHour)
        #expect(ds.load().windUnit == .kilometersPerHour)
    }

    @Test
    func setLastOpenedCity_roundTrip() throws {
        let (ds, _) = try makeDataSource()
        ds.setLastOpenedCity("Москва")
        #expect(ds.load().lastOpenedCity == "Москва")
        ds.setLastOpenedCity(nil)
        #expect(ds.load().lastOpenedCity == nil)
    }

    @Test
    func save_writesWholePreferences() throws {
        let (ds, _) = try makeDataSource()
        let prefs = UserPreferences(
            temperatureUnit: .fahrenheit,
            windUnit: .kilometersPerHour,
            lastOpenedCity: "Санкт-Петербург"
        )
        ds.save(prefs)
        let loaded = ds.load()
        #expect(loaded == prefs)
    }

    @Test
    func reset_restoresDefaults() throws {
        let (ds, _) = try makeDataSource()
        ds.save(UserPreferences(temperatureUnit: .fahrenheit, windUnit: .kilometersPerHour, lastOpenedCity: "X"))
        ds.reset()
        let loaded = ds.load()
        #expect(loaded.temperatureUnit == .celsius)
        #expect(loaded.windUnit == .metersPerSecond)
        #expect(loaded.lastOpenedCity == nil)
    }
}
