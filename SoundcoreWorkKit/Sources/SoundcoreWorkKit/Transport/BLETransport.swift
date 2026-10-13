import CoreBluetooth
import Foundation
import os

/// CoreBluetooth-Transport für den Soundcore Work – siehe `docs/d3200_protocol_spec.md` §1.
///
/// Das Gerät erlaubt nur **eine** aktive BLE-Verbindung: Vor dem Scan muss es
/// vom Handy getrennt sein. Gescannt wird nach der Service-UUID, weil die
/// BLE-Adresse zufällig ist.
///
/// Der interne Zustand liegt hinter einem Lock, weil die CoreBluetooth-Callbacks
/// auf einer eigenen seriellen Queue eintreffen.
public final class BLETransport: NSObject, DeviceTransport, @unchecked Sendable {
    // CBUUID ist nicht als Sendable deklariert, aber unveränderlich. Die Instanzen
    // werden nur gelesen, daher ist `nonisolated(unsafe)` hier korrekt – und
    // billiger als bei jedem Notification-Vergleich eine neue CBUUID zu bauen.
    nonisolated(unsafe) public static let serviceUUID =
        CBUUID(string: "020CF5DA-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) public static let writeCharacteristicUUID =
        CBUUID(string: "00007777-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) public static let notifyCharacteristicUUID =
        CBUUID(string: "00008888-0000-1000-8000-00805F9B34FB")

    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "BLETransport")
    private let queue = DispatchQueue(label: "de.gcng.sprechly.work.ble")
    private let lock = NSLock()

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private var connectContinuation: CheckedContinuation<Void, Error>?
    /// Warten auf freie Schreib-Warteschlange (siehe `send`).
    private var writeReadyWaiters: [CheckedContinuation<Void, Never>] = []
    private var sinks: [UUID: AsyncStream<Data>.Continuation] = [:]
    private var isScanning = false

    /// Wie lange auf Gerät, Verbindung und aktivierte Notifications gewartet wird.
    public let connectTimeout: Duration
    /// Obergrenze für das Warten auf eine freie Schreib-Warteschlange.
    public let writeReadyTimeout: Duration

    public init(connectTimeout: Duration = .seconds(20), writeReadyTimeout: Duration = .seconds(2)) {
        self.connectTimeout = connectTimeout
        self.writeReadyTimeout = writeReadyTimeout
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
    }

    // MARK: - DeviceTransport

    public func connect() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.waitForReadyConnection() }
            group.addTask {
                try await Task.sleep(for: self.connectTimeout)
                throw TransportError.timedOut
            }
            do {
                try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                await disconnect()
                throw error
            }
        }
    }

    private func waitForReadyConnection() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.withLock { connectContinuation = continuation }
            queue.async { [weak self] in self?.startScanIfPossible() }
        }
    }

    public func disconnect() async {
        let (peripheral, wasScanning) = lock.withLock {
            let snapshot = (self.peripheral, isScanning)
            self.peripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil
            isScanning = false
            return snapshot
        }

        if wasScanning { central.stopScan() }
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
    }

    public func send(_ frame: Data) async throws {
        let (peripheral, characteristic) = lock.withLock { (self.peripheral, writeCharacteristic) }

        guard let peripheral else { throw TransportError.notConnected }
        guard let characteristic else { throw TransportError.characteristicsMissing }

        // CoreBluetooth **verwirft** Writes ohne Response stillschweigend,
        // sobald seine Warteschlange voll ist. Ohne diese Prüfung gehen
        // Befehle verloren und Tastendrücke wirken, als käme nichts an.
        if !peripheral.canSendWriteWithoutResponse {
            await waitUntilReadyToWrite()
        }
        peripheral.writeValue(frame, for: characteristic, type: .withoutResponse)
    }

    /// Wartet, bis CoreBluetooth wieder senden kann – höchstens `writeReadyTimeout`,
    /// damit ein ausbleibendes Bereitschaftssignal nicht alles blockiert.
    private func waitUntilReadyToWrite() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    self.lock.withLock { self.writeReadyWaiters.append(continuation) }
                }
            }
            group.addTask { [writeReadyTimeout] in
                try? await Task.sleep(for: writeReadyTimeout)
                self.resumeWriteWaiters()
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func resumeWriteWaiters() {
        let waiters = lock.withLock {
            let pending = writeReadyWaiters
            writeReadyWaiters.removeAll()
            return pending
        }
        for waiter in waiters { waiter.resume() }
    }

    public func notifications() -> AsyncStream<Data> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            lock.withLock { sinks[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.sinks[id] = nil }
            }
        }
    }

    // MARK: - Interne Helfer

    private func startScanIfPossible() {
        guard central.state == .poweredOn else { return }
        let alreadyScanning = lock.withLock {
            let wasScanning = isScanning
            isScanning = true
            return wasScanning
        }
        guard !alreadyScanning else { return }

        logger.info("Scan nach Service \(Self.serviceUUID.uuidString, privacy: .public) gestartet")
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }

    /// Nimmt die Connect-Continuation unter dem Lock heraus, damit sie genau einmal resümiert wird.
    private func takeConnectContinuation() -> CheckedContinuation<Void, Error>? {
        lock.withLock {
            let continuation = connectContinuation
            connectContinuation = nil
            return continuation
        }
    }

    private func finishConnect(with result: Result<Void, Error>) {
        guard let continuation = takeConnectContinuation() else { return }
        continuation.resume(with: result)
    }

    private func emit(_ data: Data) {
        let sinks = lock.withLock { Array(self.sinks.values) }
        for sink in sinks { sink.yield(data) }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLETransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanIfPossible()
        case .unauthorized:
            finishConnect(with: .failure(TransportError.bluetoothUnavailable("keine Berechtigung")))
        case .unsupported:
            finishConnect(with: .failure(TransportError.bluetoothUnavailable("nicht unterstützt")))
        case .poweredOff:
            finishConnect(with: .failure(TransportError.bluetoothUnavailable("ausgeschaltet")))
        default:
            break
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let alreadyHavePeripheral = lock.withLock {
            let existing = self.peripheral != nil
            if !existing {
                self.peripheral = peripheral
                isScanning = false
            }
            return existing
        }
        guard !alreadyHavePeripheral else { return }

        logger.info("Gerät gefunden, RSSI \(RSSI.intValue)")
        central.stopScan()
        peripheral.delegate = self
        central.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Verbunden, suche Service")
        peripheral.discoverServices([Self.serviceUUID])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let reason = error?.localizedDescription ?? "unbekannt"
        logger.error("Verbindung fehlgeschlagen: \(reason, privacy: .public)")
        finishConnect(with: .failure(TransportError.connectionFailed(reason)))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        logger.info("Verbindung getrennt")
        let sinks = lock.withLock {
            self.peripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil
            let snapshot = Array(self.sinks.values)
            self.sinks.removeAll()
            return snapshot
        }

        for sink in sinks { sink.finish() }
        resumeWriteWaiters()
        finishConnect(with: .failure(TransportError.connectionFailed(
            error?.localizedDescription ?? "Gerät hat die Verbindung beendet"
        )))
    }
}

// MARK: - CBPeripheralDelegate

extension BLETransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finishConnect(with: .failure(TransportError.connectionFailed(error.localizedDescription)))
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            finishConnect(with: .failure(TransportError.characteristicsMissing))
            return
        }
        peripheral.discoverCharacteristics(
            [Self.writeCharacteristicUUID, Self.notifyCharacteristicUUID],
            for: service
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            finishConnect(with: .failure(TransportError.connectionFailed(error.localizedDescription)))
            return
        }
        let characteristics = service.characteristics ?? []
        let write = characteristics.first { $0.uuid == Self.writeCharacteristicUUID }
        let notify = characteristics.first { $0.uuid == Self.notifyCharacteristicUUID }
        guard let write, let notify else {
            finishConnect(with: .failure(TransportError.characteristicsMissing))
            return
        }

        lock.withLock {
            writeCharacteristic = write
            notifyCharacteristic = notify
        }

        logger.info("""
        MTU für write-without-response: \
        \(peripheral.maximumWriteValueLength(for: .withoutResponse))
        """)
        // Der Connect gilt erst als fertig, wenn das Gerät Notifications liefern kann.
        peripheral.setNotifyValue(true, for: notify)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.notifyCharacteristicUUID else { return }
        if let error {
            finishConnect(with: .failure(TransportError.connectionFailed(error.localizedDescription)))
            return
        }
        guard characteristic.isNotifying else { return }
        logger.info("Notifications aktiv – Transport bereit")
        finishConnect(with: .success(()))
    }

    /// CoreBluetooth meldet, dass wieder gesendet werden darf.
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        resumeWriteWaiters()
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.notifyCharacteristicUUID,
              let value = characteristic.value, !value.isEmpty
        else { return }
        emit(value)
    }
}
