//
//  UIUpdateThrottler.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/14/25.
//

import Foundation
import Combine

// MARK: - UI Update Throttler

class UIUpdateThrottler: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let throttleInterval: TimeInterval

    init(throttleInterval: TimeInterval = 1.0) {
        self.throttleInterval = throttleInterval
    }

    func throttle<T>(_ publisher: AnyPublisher<T, Never>, action: @escaping (T) -> Void) {
        publisher
            .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: action)
            .store(in: &cancellables)
    }

    func debounce<T>(_ publisher: AnyPublisher<T, Never>, delay: TimeInterval = 0.5, action: @escaping (T) -> Void) {
        publisher
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink(receiveValue: action)
            .store(in: &cancellables)
    }
}

// MARK: - Timer Update Manager

class TimerUpdateManager: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var startTime: Date?
    private let updateInterval: TimeInterval

    init(updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
    }

    func start() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }

    func pause() {
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        guard let startTime = startTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
}

// MARK: - Map Region Throttler

class MapRegionThrottler: ObservableObject {
    @Published var shouldUpdateRegion = false
    private var lastUpdateTime: Date = Date()
    private let minUpdateInterval: TimeInterval = 2.0 // Minimum 2 seconds between updates

    func requestRegionUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= minUpdateInterval {
            lastUpdateTime = now
            shouldUpdateRegion = true
        }
    }

    func resetUpdateFlag() {
        shouldUpdateRegion = false
    }
}