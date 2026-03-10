import Foundation

actor AeroSpaceConfigService {
    private let commandRunner: CommandRunning
    private let aerospaceExecutablePath: String?
    private let logger: AppLogger

    init(commandRunner: CommandRunning, aerospaceExecutablePath: String?, logger: AppLogger) {
        self.commandRunner = commandRunner
        self.aerospaceExecutablePath = aerospaceExecutablePath
        self.logger = logger
    }

    func integrationStatus(sidebarWidth: CGFloat) async -> AeroSpaceIntegrationStatus {
        do {
            let configURL = try await configPath()
            let configText = try String(contentsOf: configURL, encoding: .utf8)
            let reservedLeftGap = Self.parseReservedLeftGap(from: configText)

            guard let reservedLeftGap else {
                return AeroSpaceIntegrationStatus(
                    reservedLeftGap: nil,
                    presentation: .floatingOverlay,
                    message: "AeroSpace `outer.left` is not configured. Reserve at least \(Int(sidebarWidth)) px on the main monitor to avoid overlap."
                )
            }

            guard reservedLeftGap + 0.5 >= sidebarWidth else {
                return AeroSpaceIntegrationStatus(
                    reservedLeftGap: reservedLeftGap,
                    presentation: .floatingOverlay,
                    message: "AeroSpace reserves \(Int(reservedLeftGap)) px on the left, but the sidebar is \(Int(sidebarWidth)) px wide. Increase `outer.left` or shrink the sidebar."
                )
            }

            return AeroSpaceIntegrationStatus(
                reservedLeftGap: reservedLeftGap,
                presentation: .reservedColumn,
                message: nil
            )
        } catch {
            logger.error("aerospace.config.error \(error.localizedDescription)")
            return AeroSpaceIntegrationStatus(
                reservedLeftGap: nil,
                presentation: .floatingOverlay,
                message: "Unable to read AeroSpace config. The sidebar will stay floating until the left-gap reservation can be verified."
            )
        }
    }

    private func configPath() async throws -> URL {
        guard let aerospaceExecutablePath else {
            throw CommandError.launchFailure("AeroSpace CLI not found.")
        }

        let result = try await commandRunner.run(aerospaceExecutablePath, arguments: ["config", "--config-path"])
        guard result.exitCode == 0 else {
            throw CommandError.nonZeroExit(result.stderr.isEmpty ? "Unable to read AeroSpace config path." : result.stderr)
        }

        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw CommandError.nonZeroExit("AeroSpace returned an empty config path.")
        }

        return URL(fileURLWithPath: path)
    }

    static func parseReservedLeftGap(from configText: String) -> CGFloat? {
        if let mainGap = firstNumber(
            in: configText,
            pattern: #"outer\.left\s*=\s*\[\s*\{\s*monitor\.main\s*=\s*([0-9]+(?:\.[0-9]+)?)"#
        ) {
            return mainGap
        }

        if let scalarGap = firstNumber(
            in: configText,
            pattern: #"outer\.left\s*=\s*([0-9]+(?:\.[0-9]+)?)"#
        ) {
            return scalarGap
        }

        if let arrayDefault = firstNumber(
            in: configText,
            pattern: #"outer\.left\s*=\s*\[[^\]]*,\s*([0-9]+(?:\.[0-9]+)?)\s*\]"#
        ) {
            return arrayDefault
        }

        return nil
    }

    private static func firstNumber(in input: String, pattern: String) -> CGFloat? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: input) else {
            return nil
        }

        guard let number = Double(input[valueRange]) else {
            return nil
        }

        return CGFloat(number)
    }
}
