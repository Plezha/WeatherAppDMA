import Foundation

enum AppError: LocalizedError, Equatable {
    case emptyQuery
    case cityNotFound(String)
    case resourceNotFound(String)
    case decodingFailed(String)
    case notImplemented
    case networkUnavailable
    case httpStatus(Int)
    case invalidResponse
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case favoriteAlreadyExists(String)
    case favoriteNotFound
    case persistenceFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Введите название города."
        case .cityNotFound(let city):
            return "Нет данных о погоде для «\(city)»."
        case .resourceNotFound(let name):
            return "Ресурс «\(name)» отсутствует в бандле приложения."
        case .decodingFailed(let details):
            return "Не удалось декодировать данные о погоде: \(details)"
        case .notImplemented:
            return "Этот источник данных ещё не реализован."
        case .networkUnavailable:
            return "Не удалось подключиться к серверу. Проверьте интернет и попробуйте снова."
        case .httpStatus(let status):
            return "Сервер вернул ошибку \(status). Попробуйте позже."
        case .invalidResponse:
            return "Сервер вернул некорректные данные. Попробуйте позже."
        case .missingAPIKey:
            return "Не настроен API-ключ Visual Crossing. Добавьте его в локальную конфигурацию приложения."
        case .invalidAPIKey:
            return "Visual Crossing отклонил API-ключ. Проверьте ключ в локальной конфигурации."
        case .rateLimited:
            return "Достигнут лимит запросов Visual Crossing. Попробуйте позже."
        case .favoriteAlreadyExists(let city):
            return "«\(city)» уже в избранном."
        case .favoriteNotFound:
            return "Избранный город не найден."
        case .persistenceFailed(let details):
            return "Не удалось сохранить данные: \(details)"
        case .unknown:
            return "Что-то пошло не так."
        }
    }
}
