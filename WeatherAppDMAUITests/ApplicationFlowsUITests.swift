import XCTest

final class ApplicationFlowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMockedPOSTAndGETRespectTemperaturePreferenceAfterRelaunch() throws {
        let app = launchApp()
        defer { app.terminate() }

        let initialCity = element("city.row.Москва", in: app)
        XCTAssertTrue(initialCity.waitForExistence(timeout: 10))
        // The POST response is reversed; Moscow must still get its own 11 °C value.
        XCTAssertTrue(initialCity.staticTexts["11°"].exists)
        app.buttons["cities.settings"].tap()
        let picker = element("settings.temperatureUnit", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["°F"].tap()
        app.buttons["settings.done"].tap()

        // Reuse the test-specific UserDefaults suite across the second process.
        app.terminate()
        app.launch()
        let city = element("city.row.Москва", in: app)
        XCTAssertTrue(city.waitForExistence(timeout: 10))
        city.tap()
        // The GET fixture is 12.5 °C, distinct from both POST and local weather data.
        try assertForecast(in: app, temperature: 54.5, unit: "°F")
    }

    @MainActor
    func testMockedErrorsRecoverOnRetryAndFavoritesCanBeEdited() throws {
        let app = launchApp(networkScenario: "retry")
        defer { app.terminate() }

        let citiesError = app.staticTexts["cities.error"]
        XCTAssertTrue(citiesError.waitForExistence(timeout: 10))
        XCTAssertEqual(citiesError.label, "Сервер вернул ошибку 503. Попробуйте позже.")
        XCTAssertFalse(element("city.row.Москва", in: app).exists)
        app.buttons["cities.retry"].tap()

        let city = element("city.row.Москва", in: app)
        XCTAssertTrue(city.waitForExistence(timeout: 10))
        XCTAssertFalse(citiesError.exists)
        city.tap()
        let weatherError = app.staticTexts["weather.error"]
        XCTAssertTrue(weatherError.waitForExistence(timeout: 5))
        XCTAssertEqual(weatherError.label, "Не удалось подключиться к серверу. Проверьте интернет и попробуйте снова.")
        XCTAssertFalse(app.staticTexts["weather.temperature"].exists)
        app.buttons["weather.retry"].tap()
        try assertForecast(in: app, temperature: 12.5, unit: "°C")
        XCTAssertFalse(weatherError.exists)
        app.navigationBars.buttons["Города"].tap()

        let toggle = app.buttons["favorite.toggle.Москва"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "Не в избранном")
        toggle.tap()
        let added = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "В избранном"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [added], timeout: 5), .completed)
        app.buttons["cities.favorites"].tap()

        let row = element("favorite.row.Москва", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["favorite.editNote.Москва"].tap()
        let note = element("favorite.noteText", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Взять зонт")
        app.buttons["favorite.saveNote"].tap()
        XCTAssertTrue(app.staticTexts["Взять зонт"].waitForExistence(timeout: 5))

        row.swipeLeft()
        app.buttons["favorite.delete.Москва"].tap()
        XCTAssertTrue(app.staticTexts["Избранного нет"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
    }

    @MainActor
    private func launchApp(networkScenario: String = "success") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launchEnvironment["UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["UI_TEST_NETWORK_SCENARIO"] = networkScenario
        app.launch()
        XCTAssertTrue(app.buttons["cities.settings"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func assertForecast(in app: XCUIApplication, temperature: Double, unit: String) throws {
        let displayedUnit = app.staticTexts["weather.temperatureUnit"]
        XCTAssertTrue(displayedUnit.waitForExistence(timeout: 5))
        XCTAssertEqual(displayedUnit.label, unit)
        let value = app.staticTexts["weather.temperature"].label.replacingOccurrences(of: ",", with: ".")
        XCTAssertEqual(try XCTUnwrap(Double(value)), temperature, accuracy: 0.05)
        XCTAssertTrue(app.staticTexts["Почасовой прогноз"].exists)
        XCTAssertTrue(app.staticTexts["Прогноз по дням"].exists)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
