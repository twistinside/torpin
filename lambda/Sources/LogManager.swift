import AWSLambdaRuntime
import Logging

public actor LogManager {
	private static var _shared: Logger?

	static var shared: Logger {
		guard let logger = _shared else {
			fatalError("Logger is not initialized.")
		}
		return logger
	}
	
	static func initialize(from context: LambdaContext) {
		_shared = context.logger
		self.shared.info("Initialized logger.")
	}
}