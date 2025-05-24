import AWSLambdaRuntime
import Logging

public actor LogManager {
    private static var _shared: Logger?

    public static var shared: Logger {
        guard let logger = _shared else {
            fatalError("Logger is not initialized.")
        }
        return logger
    }
    
    public static func initialize(from context: LambdaInitializationContext) {
        _shared = context.logger
        self.shared.info("Initialized logger.")
    }
}
